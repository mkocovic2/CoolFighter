extends Area2D

@onready var sprite = $Sprite2D

var direction: Vector2
var speed: float
var max_distance: float
var traveled_distance: float = 0.0
var projectile_type: String = ""
var hit_enemies = []

func _ready():
	body_entered.connect(_on_body_entered)

func initialize(proj_type: String, dir: Vector2, spd: float, dist: float):
	projectile_type = proj_type
	direction = dir
	speed = spd
	max_distance = dist
	
	if sprite:
		var texture_path = "res://Assets/Player/Attacks/" + proj_type + ".png"
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			if dir.x > 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		else:
			push_error("Could not load texture: " + texture_path)

func _physics_process(delta):
	var movement = direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body):
	if body in hit_enemies:
		return
	
	# Check if it's an enemy with the new get_hit method
	if body.has_method("get_hit"):
		hit_enemies.append(body) 
		
		var attack_type = _get_attack_type()
		var damage = _get_damage(attack_type)
		var knockback_force = _get_knockback_force(attack_type)
		var send_flying = attack_type in ["kick", "shove", "explosion"]
		
		body.get_hit(damage, global_position, knockback_force, send_flying)
		
		# Remove the enemy from hit_enemies after a short delay
		# This allows combo hits but prevents multiple hits from the same attack
		await get_tree().create_timer(0.1).timeout
		if body in hit_enemies:
			hit_enemies.erase(body)
			
	# Fallback for old enemies with take_damage
	elif body.has_method("take_damage"):
		hit_enemies.append(body) 
		body.take_damage(10)
		
		# Remove the enemy from hit_enemies after a short delay
		await get_tree().create_timer(0.1).timeout
		if body in hit_enemies:
			hit_enemies.erase(body)

func _get_attack_type() -> String:
	var type = projectile_type.to_lower()
	
	if "kick" in type:
		return "kick"
	elif "shove" in type or "push" in type:
		return "shove"
	elif "explosion" in type or "explode" in type or "bomb" in type:
		return "explosion"
	else:
		return "normal"

func _get_damage(attack_type: String) -> int:
	match attack_type:
		"kick":
			return 25
		"shove":
			return 15
		"explosion":
			return 40
		_:
			return 10

func _get_knockback_force(attack_type: String) -> float:
	match attack_type:
		"kick":
			return 350.0 
		"shove":
			return 300.0
		"explosion":
			return 500.0
		_:
			return 80.0
