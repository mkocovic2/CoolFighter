extends CharacterBody2D

@export var move_speed = 50.0
@export var punch_range = 250.0
@export var punch_damage = 10
@export var detection_range = 300.0
@export var health = 100
@export var attack_scene: PackedScene
@export var attack_speed: float = 250.0
@export var attack_distance: float = 100.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var punch_timer = $PunchTimer
@onready var hit_area = $HitArea
@onready var collision_shape = $CollisionShape2D
@onready var attack_spawn_point = $AttackSpawnPoint

enum State {
	IDLE,
	WALKING,
	PUNCH_WINDUP,
	PUNCHING,
	HIT,
	FLYING,
	LANDING,
	DEAD
}

var current_state = State.IDLE
var player: CharacterBody2D = null
var hit_velocity = Vector2.ZERO
var gravity = 980.0
var is_airborne = false
var ground_y = 0.0
var is_invulnerable = false
var facing_right = false 

# Invulnerability timers
var invulnerability_timer: Timer
var blink_timer: Timer

# Windup timer reference for cancellation
var windup_timer: SceneTreeTimer = null

func _ready():
	ground_y = global_position.y
	punch_timer.timeout.connect(_on_punch_timer_timeout)
	punch_timer.wait_time = 3.0
	
	invulnerability_timer = Timer.new()
	invulnerability_timer.one_shot = true
	add_child(invulnerability_timer)
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	
	# Create blink timer
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.1  # Blink every 0.1 seconds
	add_child(blink_timer)
	blink_timer.timeout.connect(_on_blink_timeout)
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	change_state(State.IDLE)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_handle_idle()
		State.WALKING:
			_handle_walking(delta)
		State.PUNCH_WINDUP:
			_handle_punch_windup()
		State.PUNCHING:
			_handle_punching()
		State.HIT:
			_handle_hit(delta)
		State.FLYING:
			_handle_flying(delta)
		State.LANDING:
			_handle_landing()
	
	move_and_slide()

func _handle_idle():
	if player == null:
		return
	
	# Always chase the player
	change_state(State.WALKING)

func _handle_walking(delta):
	if player == null:
		change_state(State.IDLE)
		return
	
	var direction = (player.global_position - global_position).normalized()
	var distance = global_position.distance_to(player.global_position)
	
	# Update facing direction and flip sprite
	if direction.x > 0:
		facing_right = true
		animated_sprite.flip_h = true
		# Flip attack spawn point to the right
		if attack_spawn_point:
			attack_spawn_point.position.x = abs(attack_spawn_point.position.x)
	else:
		facing_right = false
		animated_sprite.flip_h = false
		# Flip attack spawn point to the left
		if attack_spawn_point:
			attack_spawn_point.position.x = -abs(attack_spawn_point.position.x)
	
	if distance < punch_range:
		change_state(State.PUNCH_WINDUP)  # Changed to windup state
	else:
		velocity = direction * move_speed

func _handle_punch_windup():
	# Stop moving and play idle animation for 1 second
	velocity = Vector2.ZERO
	
	# Store the timer reference so we can check if it's still valid
	windup_timer = get_tree().create_timer(1.0)
	await windup_timer.timeout
	
	# Also check if the timer we're waiting for is still the current one
	if (current_state == State.PUNCH_WINDUP and health > 0 and 
		not is_invulnerable and windup_timer != null):
		change_state(State.PUNCHING)

func _handle_punching():
	velocity = Vector2.ZERO
	# The attack animation and projectile spawn happen in change_state

func _handle_hit(delta):
	# Brief stun before flying
	pass

func _handle_flying(delta):
	# Apply gravity and horizontal velocity
	hit_velocity.y += gravity * delta
	velocity = hit_velocity
	
	# Check if we've hit the ground
	if global_position.y >= ground_y:
		global_position.y = ground_y
		change_state(State.LANDING)

func _handle_landing():
	velocity = Vector2.ZERO

func change_state(new_state: State):
	# Clear windup timer reference when changing states (except to PUNCH_WINDUP)
	if new_state != State.PUNCH_WINDUP:
		windup_timer = null
	
	current_state = new_state
	
	match current_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.WALKING:
			animated_sprite.play("walk")
		State.PUNCH_WINDUP:
			animated_sprite.play("idle") 
		State.PUNCHING:
			animated_sprite.play("attack")
			punch_timer.start()
			# Spawn attack projectile
			_spawn_attack()
		State.HIT:
			animated_sprite.play("hit")
			velocity = Vector2.ZERO
			# Disable hitbox
			collision_shape.set_deferred("disabled", true)
			await get_tree().create_timer(0.2).timeout
			if current_state == State.HIT:
				change_state(State.FLYING)
		State.FLYING:
			animated_sprite.play("flying")
			is_airborne = true
			# Hitbox remains disabled
		State.LANDING:
			animated_sprite.play("land")
			is_airborne = false
			_start_invulnerability(2.0)
			# Hitbox remains disabled while on ground
			await get_tree().create_timer(2.0).timeout
			if health > 0 and current_state == State.LANDING:
				collision_shape.set_deferred("disabled", false)  # Re-enable hitbox
				change_state(State.IDLE)
			elif health <= 0:
				change_state(State.DEAD)
		State.DEAD:
			animated_sprite.play("dead")
			set_physics_process(false)
			# Stop all timers
			blink_timer.stop()
			invulnerability_timer.stop()
			# Flicker effect
			await _flicker_and_despawn()

# Start invulnerability for a duration
func _start_invulnerability(duration: float):
	is_invulnerable = true
	
	# Start blinking
	blink_timer.start()
	
	# Set timer to end invulnerability
	invulnerability_timer.wait_time = duration
	invulnerability_timer.start()

# End invulnerability
func _on_invulnerability_timeout():
	is_invulnerable = false
	blink_timer.stop()
	
	# Make sure sprite is visible when invulnerability ends
	if animated_sprite:
		animated_sprite.visible = true

# Handle blinking effect
func _on_blink_timeout():
	if animated_sprite:
		animated_sprite.visible = !animated_sprite.visible

func _spawn_attack():
	if not attack_scene:
		push_error("Enemy attack scene not assigned!")
		return
	
	var attack = attack_scene.instantiate()
	get_parent().add_child(attack)
	
	# Position at spawn point or at enemy position
	if attack_spawn_point:
		attack.global_position = attack_spawn_point.global_position
	else:
		attack.global_position = global_position
	
	# Direction based on facing direction
	var direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	
	# Initialize the attack projectile with "punch" type
	if attack.has_method("initialize"):
		attack.initialize("punch", direction, attack_speed, attack_distance)
	
	# Store the owner on the attack so it can't hurt itself
	if attack.has_method("set_owner_enemy"):
		attack.set_owner_enemy(self)
	
	# Flip the attack sprite if facing right
	if attack.has_node("AnimatedSprite2D"):
		var attack_sprite = attack.get_node("AnimatedSprite2D")
		attack_sprite.flip_h = facing_right

func _on_punch_timer_timeout():
	if current_state == State.PUNCHING:
		change_state(State.WALKING)

func take_damage(damage: int, knockback_velocity: Vector2 = Vector2.ZERO):
	# Ignore damage if invulnerable
	if is_invulnerable:
		return
	
	# If we're in windup or punching state, interrupt the attack
	if current_state == State.PUNCH_WINDUP or current_state == State.PUNCHING:
		punch_timer.stop()
		# Clear the windup timer reference to prevent the attack from triggering
		windup_timer = null
	
	health -= damage
	
	if health <= 0:
		change_state(State.DEAD)
	else:
		# Apply the knockback velocity
		hit_velocity = knockback_velocity
		# Only go flying if there's upward velocity
		if knockback_velocity.y < 0:
			change_state(State.HIT)
		else:
			# Just get pushed back without flying
			velocity = knockback_velocity
			# Brief hit stun
			var original_state = current_state
			animated_sprite.play("hit")
			await get_tree().create_timer(0.3).timeout
			if current_state != State.DEAD:
				change_state(State.WALKING)

# Call this from external sources (like player attacks)
func get_hit(damage: int, attacker_position: Vector2, knockback_force: float = 200.0, send_flying: bool = false):
	# Ignore if invulnerable
	if is_invulnerable:
		return
	
	# If we're in windup state, interrupt the attack
	if current_state == State.PUNCH_WINDUP:
		punch_timer.stop()
		# Clear the windup timer reference to prevent the attack from triggering
		windup_timer = null
	
	var knockback_direction = (global_position - attacker_position).normalized()
	
	if send_flying:
		# Strong attacks send enemy flying
		hit_velocity = knockback_direction * knockback_force
		hit_velocity.y = -400  # Upward launch
	else:
		# Weak attacks just push back slightly (no flying)
		hit_velocity = knockback_direction * knockback_force
		hit_velocity.y = 0  # Stay on ground
	
	take_damage(damage, hit_velocity)

func _flicker_and_despawn():
	# Wait a moment before flickering
	await get_tree().create_timer(0.5).timeout
	
	# Flicker 6 times
	for i in range(6):
		animated_sprite.visible = false
		await get_tree().create_timer(0.1).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(0.1).timeout
	
	# Despawn
	queue_free()
