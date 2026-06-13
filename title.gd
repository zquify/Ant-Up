extends Control

@export var game_scene: PackedScene

@onready var high_score: Label = $CenterContainer/VBoxContainer/HighScore
@onready var play_button: Button = $CenterContainer/VBoxContainer/Play
@onready var settings_button: Button = $CenterContainer/VBoxContainer/Settings
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Quit

func _ready():
	high_score.text = ("High Score: " + str(GameManager.load_high_score()))

func _on_play_pressed():
	get_tree().change_scene_to_packed(game_scene)

func _on_settings_pressed():
	pass

func _on_quit_pressed():
	get_tree().quit()
