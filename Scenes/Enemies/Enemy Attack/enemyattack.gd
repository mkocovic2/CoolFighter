extends Area2D

@onready var sprite = $Sprite2D

var direction: Vector2
var speed: float
var max_distance: float
var traveled_distance: float = 0.0
var projectile_type: String = ""
var has_hit_player = false

func _ready():
	body_entered.connect(_on_body_entered)

func initialize(proj_type: String, dir: Vector2, spd: float, dist: float):
	projectile_type = proj_type
	direction = dir
	speed = spd
	max_distance = dist
	"res://Assets/Enemy/Cube Man/punch.png"
	
	if sprite:
		var texture_path = "res://Assets/Enemy/Cube Man/" + proj_type + ".png"
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			if dir.x > 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		else:
			push_error("Could not load enemy attack texture: " + texture_path)

func _physics_process(delta):
	var movement = direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body):
	# Only hit player once
	if has_hit_player:
		return
	
	if body.is_in_group("player"):
		has_hit_player = true
		
		var damage = 10
		var knockback_force = 300.0
		
		if body.has_method("get_hit"):
			body.get_hit(damage, global_position, knockback_force)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		
		queue_free()
