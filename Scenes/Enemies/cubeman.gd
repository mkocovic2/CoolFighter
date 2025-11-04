extends CharacterBody2D

@export var move_speed = 50.0
@export var punch_range = 40.0
@export var punch_damage = 10
@export var detection_range = 300.0
@export var health = 100

@onready var animated_sprite = $AnimatedSprite2D
@onready var punch_timer = $PunchTimer
@onready var hit_area = $HitArea

enum State {
	IDLE,
	WALKING,
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

func _ready():
	ground_y = global_position.y
	punch_timer.timeout.connect(_on_punch_timer_timeout)
	punch_timer.wait_time = 2.0
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	change_state(State.IDLE)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_handle_idle()
		State.WALKING:
			_handle_walking(delta)
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
	
	# Flip sprite based on direction
	if direction.x > 0:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
	
	if distance < punch_range:
		change_state(State.PUNCHING)
	else:
		velocity = direction * move_speed

func _handle_punching():
	velocity = Vector2.ZERO

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
	current_state = new_state
	
	match current_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.WALKING:
			animated_sprite.play("walk")
		State.PUNCHING:
			animated_sprite.play("punch")
			punch_timer.start()
			# Deal damage to player if in range
			_check_punch_hit()
		State.HIT:
			animated_sprite.play("hit")
			velocity = Vector2.ZERO
			await get_tree().create_timer(0.2).timeout
			if current_state == State.HIT:  # Make sure we weren't interrupted
				change_state(State.FLYING)
		State.FLYING:
			animated_sprite.play("flying")
			is_airborne = true
		State.LANDING:
			animated_sprite.play("land")
			is_airborne = false
			is_invulnerable = true
			# Wait 2 seconds on the ground before getting up
			await get_tree().create_timer(2.0).timeout
			if health > 0 and current_state == State.LANDING:
				is_invulnerable = false
				change_state(State.IDLE)
			elif health <= 0:
				change_state(State.DEAD)
		State.DEAD:
			animated_sprite.play("dead")
			set_physics_process(false)
			# Flicker effect
			await _flicker_and_despawn()

func _check_punch_hit():
	if player == null:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < punch_range:
		# Call damage function on player
		if player.has_method("take_damage"):
			player.take_damage(punch_damage)

func _on_punch_timer_timeout():
	if current_state == State.PUNCHING:
		change_state(State.WALKING)

func take_damage(damage: int, knockback_velocity: Vector2 = Vector2.ZERO):
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
