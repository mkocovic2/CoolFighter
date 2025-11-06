extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var combo_timer = $ComboTimer
@onready var attack_spawn_point = $AttackSpawnPoint
@onready var collision_shape = $CollisionShape2D

# Movement settings
@export var speed: float = 200.0

# Combat settings
@export var combo_window: float = 1.0
@export var attack_scene: PackedScene
@export var attack_speed: float = 300.0
@export var attack_distance: float = 100.0
@export var health: int = 100

# Dash settings
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

# Dash state
var is_dashing = false
var dash_direction = Vector2.ZERO
var dash_timer: Timer
var dash_cooldown_timer: Timer
var can_dash = true

# Animation state
var current_animation: String = ""

# Combo tracking
var combo_count = 0
var combo_sequence = []  # Tracks sequence of attacks for special moves

# Attack state
var is_attacking = false
var attack_queued = false
var queued_attack_type = ""  # Which button was queued (z or x)
var spawn_point_offset: float = 0.0  # Distance from player to spawn attacks

# Hit state
var is_hit = false
var is_flying = false
var is_grounded_from_hit = false
var hit_velocity = Vector2.ZERO
var gravity = 980.0
var ground_y = 0.0  # Y position of ground for landing

# Invulnerability state
var is_invulnerable = false
var invulnerability_timer: Timer
var blink_timer: Timer

func _ready():
	combo_timer.wait_time = combo_window
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	
	# Store initial position, spawn point offset
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
	
	# Create dash timer, cooldown timer
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	add_child(dash_timer)
	dash_timer.timeout.connect(_on_dash_timeout)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)

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
	
	# Handle dash
	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()
		return
	
	# Check for dash input
	if (Input.is_key_pressed(KEY_C)) and can_dash and not is_attacking:
		_start_dash()
		return
	
	if Input.is_action_just_pressed("ui_text_backspace") or Input.is_key_pressed(KEY_Z):
		if is_attacking:
			attack_queued = true
			queued_attack_type = "z"
		else:
			_perform_attack("z")
		return
	
	if Input.is_key_pressed(KEY_X):
		if is_attacking:
			attack_queued = true
			queued_attack_type = "x"
		else:
			_perform_attack("x")
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

func _start_dash():
	# Get dash direction from input or current facing direction
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	if input_vector.length() > 0:
		dash_direction = input_vector.normalized()
	else:
		# Dash in the direction sprite is facing
		dash_direction = Vector2.RIGHT if animated_sprite.flip_h else Vector2.LEFT
	
	is_dashing = true
	can_dash = false
	
	# Brief invulnerability during dash
	_start_invulnerability(dash_duration)
	
	# Play dash animation if available, otherwise use walk
	if animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
	else:
		animated_sprite.play("walk")
	
	# Start dash timer, cooldown timer
	dash_timer.wait_time = dash_duration
	dash_timer.start()
	
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.start()

func _on_dash_timeout():
	is_dashing = false
	velocity = Vector2.ZERO

func _on_dash_cooldown_timeout():
	can_dash = true

func _handle_flying(delta):
	# Apply gravity, horizontal velocity
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
	
	# Add invulnerability after getting up
	_start_invulnerability(2.0)

func _perform_attack(attack_type: String):
	if is_attacking or is_hit:
		return
	
	combo_count += 1
	combo_sequence.append(attack_type)
	
	# Keep only last 3 attacks in sequence
	if combo_sequence.size() > 3:
		combo_sequence.pop_front()
	
	if combo_count > 3:
		combo_count = 1
		combo_sequence = [attack_type]
	
	combo_timer.start()
	
	# Check for special combos
	if combo_sequence.size() == 3:
		# Z, Z, X = fire
		if combo_sequence[0] == "z" and combo_sequence[1] == "z" and combo_sequence[2] == "x":
			_spawn_attack("fire")
			combo_count = 0
			combo_sequence.clear()
			return
		# X, X, Z = shove
		elif combo_sequence[0] == "x" and combo_sequence[1] == "x" and combo_sequence[2] == "z":
			_spawn_attack("shove")
			combo_count = 0
			combo_sequence.clear()
			return
	
	# Normal combo attacks
	match combo_count:
		1:
			_spawn_attack("punch")
		2:
			_spawn_attack("punch_right")
		3:
			_spawn_attack("kick")
			combo_sequence.clear()

func _on_attack_finished():
	is_attacking = false
	
	if combo_count == 3:
		combo_count = 0
	
	if attack_queued:
		attack_queued = false
		_perform_attack(queued_attack_type)
		queued_attack_type = ""

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
		combo_sequence.clear()

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
	
	# Flip sprite, attack spawn point based on movement direction
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
	
	# Cancel any ongoing attack, dash
	is_attacking = false
	attack_queued = false
	is_dashing = false

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
	
	# Reset time, audio
	Engine.time_scale = 1.0
	if scene_audio:
		scene_audio.pitch_scale = 1.0
	
	# Switch to title screen
	get_tree().change_scene_to_file("res://Scenes/Levels/TitleScreen.tscn")
