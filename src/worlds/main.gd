extends Node3D

@export var player_scene: PackedScene
@onready var end_game_menu: Control = $EndGameMenu

@onready var max_fps = Engine.max_fps


func _ready() -> void:
	GameManager.reset()
	respawn()
	calculate_total_score()


func calculate_total_score() -> void:
	var total := 0

	for body in get_tree().get_nodes_in_group("carryable"):
		total += body.score

	GameManager.target_score = total


func respawn() -> void:
	var spawn_pos = pick_spawn()
	var player = player_scene.instantiate()
	player.global_transform = spawn_pos
	$Players.add_child(player)


func pick_spawn() -> Transform3D:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_transform
	return global_transform


func count_total_food() -> void:
	GameManager.total_food = get_tree().get_nodes_in_group("carryable").size()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.TITLE)
