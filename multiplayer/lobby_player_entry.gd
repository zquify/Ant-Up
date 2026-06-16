extends HBoxContainer
class_name LobbyPlayerEntry

@onready var avatar: TextureRect = $Avatar
@onready var player_name: Label = $Name


func setup(name_text: String, avatar_texture: Texture2D) -> void:
	player_name.text = name_text

	if avatar_texture:
		avatar.texture = avatar_texture
