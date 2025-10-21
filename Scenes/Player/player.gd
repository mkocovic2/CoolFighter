extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var combo_timer = $ComboTimer
@onready var attack_spawn_point = $AttackSpawnPoint

@export var speed: float = 200.0
@export var combo_window: float = 1.0
@export var attack_scene: PackedScene
@export var attack_speed: float = 300.0
@export var attack_distance: float = 100.0

var current_animation: String = ""
var combo_count = 0
var is_attacking = false
var attack_queued = false

func _ready():
	combo_timer.wait_time = combo_window
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)

func _physics_process(delta):
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

func _perform_attack():
	if is_attacking:
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
	
	if velocity.y < -10.0:
		desired_animation = "idle"
	elif velocity.y > 10.0:
		desired_animation = "idle"
	elif is_moving:
		desired_animation = "idle"
	else:
		desired_animation = "idle"
	
	if desired_animation != current_animation:
		current_animation = desired_animation
		animated_sprite.animation = desired_animation
		animated_sprite.play()
	
	if velocity.x < 0:
		animated_sprite.flip_h = false
	elif velocity.x > 0:
		animated_sprite.flip_h = true
