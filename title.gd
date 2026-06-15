extends Control

@export var game_scene: PackedScene

@onready var high_score: Label = $CenterContainer/VBoxContainer/HighScore
@onready var play: Button = $CenterContainer/VBoxContainer/Play

func _ready():
	high_score.text = ("High Score: " + str(GameManager.load_high_score()))
	play.grab_focus()

func _on_play_pressed():
	get_tree().change_scene_to_packed(game_scene)

func _on_settings_pressed():
	pass

func _on_quit_pressed():
	get_tree().quit()

func _on_config_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))
