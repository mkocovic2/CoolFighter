extends Area2D

@onready var sprite = $Sprite2D

# Movement properties
var direction: Vector2
var speed: float
var max_distance: float
var traveled_distance: float = 0.0

# Attack properties
var projectile_type: String = ""
var has_hit_player = false  # Prevent multiple hits on same player

func _ready():
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func initialize(proj_type: String, dir: Vector2, spd: float, dist: float):
	# Set projectile properties
	projectile_type = proj_type
	direction = dir
	speed = spd
	max_distance = dist
	
	# Load and set sprite texture
	if sprite:
		var texture_path = "res://Assets/Enemy/Cube Man/" + proj_type + ".png"
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			# Flip sprite based on direction
			if dir.x > 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		else:
			push_error("Could not load enemy attack texture: " + texture_path)

func _physics_process(delta):
	# Move projectile in direction
	var movement = direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	# Remove projectile if max distance reached
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body):
	# Prevent hitting player multiple times
	if has_hit_player:
		return
	
	# Check if hit player
	if body.is_in_group("player"):
		has_hit_player = true
		
		# Set damage, knockback values
		var damage = 10
		var knockback_force = 300.0
		
		# Apply damage, knockback to player
		if body.has_method("get_hit"):
			body.get_hit(damage, global_position, knockback_force)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Remove projectile after hitting player
		queue_free()
