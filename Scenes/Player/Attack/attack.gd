extends Area2D

@onready var sprite = $Sprite2D

var direction: Vector2
var speed: float
var max_distance: float
var traveled_distance: float = 0.0

func initialize(projectile_type: String, dir: Vector2, spd: float, dist: float):
	direction = dir
	speed = spd
	max_distance = dist
	
	if sprite:
		var texture_path = "res://Assets/Player/Attacks/" + projectile_type + ".png"
		sprite.texture = load(texture_path)
		if dir.x > 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false

func _physics_process(delta):
	var movement = direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	if traveled_distance >= max_distance:
		queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(10)
	queue_free()
