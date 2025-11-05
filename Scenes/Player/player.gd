extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var combo_timer = $ComboTimer
@onready var attack_spawn_point = $AttackSpawnPoint
@onready var collision_shape = $CollisionShape2D

@export var speed: float = 200.0
@export var combo_window: float = 1.0
@export var attack_scene: PackedScene
@export var attack_speed: float = 300.0
@export var attack_distance: float = 100.0
@export var health: int = 100

var current_animation: String = ""
var combo_count = 0
var is_attacking = false
var attack_queued = false
var spawn_point_offset: float = 0.0

# Hit state variables
var is_hit = false
var is_flying = false
var is_grounded_from_hit = false
var hit_velocity = Vector2.ZERO
var gravity = 980.0
var ground_y = 0.0

# Invulnerability variables
var is_invulnerable = false
var invulnerability_timer: Timer
var blink_timer: Timer

func _ready():
	combo_timer.wait_time = combo_window
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	
	# Store initial position and spawn point offset
	ground_y = global_position.y
	if attack_spawn_point:
		spawn_point_offset = attack_spawn_point.position.x
	
	# Create invulnerability timer
	invulnerability_timer = Timer.new()
	invulnerability_timer.one_shot = true
	add_child(invulnerability_timer)
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	
	# Create blink timer
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.1 
	add_child(blink_timer)
	blink_timer.timeout.connect(_on_blink_timeout)

func _physics_process(delta):
	# Handle hit states
	if is_flying:
		_handle_flying(delta)
		return
	
	if is_grounded_from_hit:
		# Can't move while on ground after being hit
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if is_hit:
		# Brief stun before any other state
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Normal gameplay
	if Input.is_action_just_pressed("ui_accept"):
		if is_attacking:
			attack_queued = true
		else:
			_perform_attack()
		return
	
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()
	update_appearance()

func _handle_flying(delta):
	# Apply gravity and horizontal velocity
	hit_velocity.y += gravity * delta
	velocity = hit_velocity
	move_and_slide()
	
	# Check if we've hit the ground
	if global_position.y >= ground_y:
		global_position.y = ground_y
		is_flying = false
		is_grounded_from_hit = true
		animated_sprite.play("land")
		
		# Start invulnerability when landing
		_start_invulnerability(2.0)
		
		await get_tree().create_timer(1.0).timeout
		_get_up()

func _get_up():
	is_grounded_from_hit = false
	is_hit = false
	current_animation = "idle"
	animated_sprite.play("idle")
	
	# Add 2 seconds of invulnerability after getting up
	_start_invulnerability(2.0)

func _perform_attack():
	if is_attacking or is_hit:
		return
	
	combo_count += 1
	
	if combo_count > 3:
		combo_count = 1
	
	combo_timer.start()
	
	match combo_count:
		1:
			_spawn_attack("punch")
		2:
			_spawn_attack("punch_right")
		3:
			_spawn_attack("kick")

func _on_attack_finished():
	is_attacking = false
	
	if combo_count == 3:
		combo_count = 0
	
	if attack_queued:
		attack_queued = false
		_perform_attack()

func _spawn_attack(attack_type: String):
	is_attacking = true
	
	current_animation = attack_type
	animated_sprite.animation = attack_type
	animated_sprite.play()
	
	if not attack_scene:
		push_error("Attack scene not assigned!")
		is_attacking = false
		return
	
	var attack = attack_scene.instantiate()
	get_parent().add_child(attack)
	
	if attack_spawn_point:
		attack.global_position = attack_spawn_point.global_position
	else:
		push_error("AttackSpawnPoint marker not found!")
		attack.global_position = global_position
	
	var direction = Vector2.RIGHT if animated_sprite.flip_h else Vector2.LEFT
	
	var projectile_type = attack_type
	
	if attack.has_method("initialize"):
		attack.initialize(projectile_type, direction, attack_speed, attack_distance)
	
	attack.tree_exited.connect(_on_attack_finished)

func _on_combo_timeout():
	if not is_attacking:
		combo_count = 0

func update_appearance():
	if not animated_sprite:
		return
	
	var is_moving = velocity.length() > 10.0 
	var desired_animation: String = ""
	# Should probably fix this
	if velocity.y < -10.0:
		desired_animation = "walk"
	elif velocity.y > 10.0:
		desired_animation = "walk"
	elif is_moving:
		desired_animation = "walk"
	else:
		desired_animation = "idle"
	
	if desired_animation != current_animation:
		current_animation = desired_animation
		animated_sprite.animation = desired_animation
		animated_sprite.play()
	
	# Flip sprite and attack spawn point based on movement direction
	if velocity.x < 0:
		animated_sprite.flip_h = false
		if attack_spawn_point:
			attack_spawn_point.position.x = -abs(spawn_point_offset)
	elif velocity.x > 0:
		animated_sprite.flip_h = true
		if attack_spawn_point:
			attack_spawn_point.position.x = abs(spawn_point_offset)

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

# Called by enemies to damage the player
func take_damage(damage: int):
	if is_hit or is_invulnerable:
		return  # Already hit or invulnerable, ignore
	
	health -= damage
	print("Player took ", damage, " damage. Health: ", health)
	
	if health <= 0:
		_die()

# Called by enemies to knock back the player
func get_hit(damage: int, attacker_position: Vector2, knockback_force: float = 300.0):
	if is_hit or is_invulnerable:
		return  # Already hit or invulnerable, ignore
	
	health -= damage
	
	if health <= 0:
		_die()
		return
	
	# Calculate knockback direction
	var knockback_direction = (global_position - attacker_position).normalized()
	
	# Set hit state
	is_hit = true
	is_flying = true
	hit_velocity = knockback_direction * knockback_force
	hit_velocity.y = -400  # Upward launch
	
	# Play hit animation
	animated_sprite.play("hit")
	
	# Cancel any ongoing attack
	is_attacking = false
	attack_queued = false

@onready var scene_audio = $"../AudioStreamPlayer2D"

func _die():
	print("Player died!")
	is_hit = true
	velocity = Vector2.ZERO
	animated_sprite.play("land")
	
	# Slow down time
	var slow_factor = 0.3
	Engine.time_scale = slow_factor
	
	# Slow down the audio
	if scene_audio:
		scene_audio.pitch_scale = slow_factor
		scene_audio.play()

	await get_tree().create_timer(2.0, true).timeout
	
	# Reset time and audio
	Engine.time_scale = 1.0
	if scene_audio:
		scene_audio.pitch_scale = 1.0
	
	# Switch to title screen
	get_tree().change_scene_to_file("res://Scenes/Levels/TitleScreen.tscn")
