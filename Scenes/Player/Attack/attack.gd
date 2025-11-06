extends Area2D

@onready var sprite = $Sprite2D

# Movement properties
var direction: Vector2
var speed: float
var max_distance: float
var traveled_distance: float = 0.0

# Attack properties
var projectile_type: String = ""
var hit_enemies = []  # Track which enemies have been hit

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
		var texture_path = "res://Assets/Player/Attacks/" + proj_type + ".png"
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			# Flip sprite based on direction
			if dir.x > 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		else:
			push_error("Could not load texture: " + texture_path)

func _physics_process(delta):
	# Move projectile in direction
	var movement = direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	# Remove projectile if max distance reached
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body):
	# Prevent hitting same enemy multiple times
	if body in hit_enemies:
		return
	
	# Check if enemy has new get_hit method
	if body.has_method("get_hit"):
		# Add to hit list
		hit_enemies.append(body) 
		
		# Get attack properties
		var attack_type = _get_attack_type()
		var damage = _get_damage(attack_type)
		var knockback_force = _get_knockback_force(attack_type)
		var send_flying = attack_type in ["kick", "shove", "fire"]
		
		# Apply damage, knockback to enemy
		body.get_hit(damage, global_position, knockback_force, send_flying)
		
		# Allow combo hits after short delay
		await get_tree().create_timer(0.1).timeout
		if body in hit_enemies:
			hit_enemies.erase(body)
			
	# Fallback for old enemies with take_damage method
	elif body.has_method("take_damage"):
		# Add to hit list
		hit_enemies.append(body) 
		body.take_damage(10)
		
		# Allow combo hits after short delay
		await get_tree().create_timer(0.1).timeout
		if body in hit_enemies:
			hit_enemies.erase(body)

func _get_attack_type() -> String:
	# Determine attack type from projectile name
	var type = projectile_type.to_lower()
	
	if "kick" in type:
		return "kick"
	elif "shove" in type:
		return "shove"
	elif "fire" in type:
		return "fire"
	else:
		return "normal"

func _get_damage(attack_type: String) -> int:
	# Return damage based on attack type
	match attack_type:
		"kick":
			return 20
		"shove":
			return 20
		"fire":
			return 20
		_:
			return 10

func _get_knockback_force(attack_type: String) -> float:
	# Return knockback force based on attack type
	match attack_type:
		"kick":
			return 350.0 
		"shove":
			return 500.0
		"fire":
			return 300.0
		_:
			return 80.0
