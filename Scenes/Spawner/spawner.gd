extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 6.0

var target: Node2D
var timer := 0.0

func _ready():
	# Find the player in the "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
	else:
		push_warning("No player found in 'player' group!")

func _process(delta):
	if target:
		position.x = target.position.x

	# Spawn enemies every interval
	timer += delta
	if timer >= spawn_interval:
		spawn_enemies()
		timer = 0.0

func spawn_enemies():
	for spawn_point in get_children():
		if spawn_point is Node2D:
			var enemy = enemy_scene.instantiate()
			enemy.global_position = spawn_point.global_position
			get_parent().add_child(enemy)
