extends Node
# Steam Variables
var OWNED = false
var ONLINE = false
var STEAM_ID = 0
var STEAM_NAME = ""
# Lobby Variables
var DATA
var LOBBY_ID = 0
var LOBBY_MEMBERS = []
var LOBBY_INVITE_ARG = false
var IS_HOST = false
var PLAYER_READY = false
var PLAYERS_READY_STATUS = {}
const STEAM_LOBBY = preload("res://multiplayer/steam_lobby.tscn")
var AVATAR_CACHE := {}

func _ready():
	var INIT = Steam.steamInit()
	if not INIT:
		print("Failed to initialize Steam. Shutting down...")
		get_tree().quit()
	
	ONLINE = Steam.loggedOn()
	STEAM_ID = Steam.getSteamID()
	STEAM_NAME = Steam.getPersonaName()
	OWNED = Steam.isSubscribed()
	
	if OWNED == false:
		print("User does not own this game")
		get_tree().quit()
	
	Steam.join_requested.connect(_on_join_requested)
	check_command_line()


func _process(_delta: float) -> void:
	Steam.run_callbacks()


func _on_join_requested(lobby_id, _friend_id):
	print("Steam invite received")
	get_tree().change_scene_to_packed(STEAM_LOBBY)
	Steam.joinLobby(lobby_id)


func check_command_line():
	var arguments = OS.get_cmdline_args()
	
	for i in range(arguments.size()):
		if arguments[i] == "+connect_lobby":
			if i + 1 < arguments.size():
				
				var lobby_id = int(arguments[i + 1])
				
				print("Joining lobby from command line")
				
				Steam.joinLobby(lobby_id)
				get_tree().change_scene_to_packed(STEAM_LOBBY)
				
				break


func get_avatar_texture(steam_id: int) -> Texture2D:

	if AVATAR_CACHE.has(steam_id):
		return AVATAR_CACHE[steam_id]

	var avatar_id = Steam.getMediumFriendAvatar(steam_id)

	if avatar_id <= 0:
		return null

	var size = Steam.getImageSize(avatar_id)

	if !size["success"]:
		return null

	var width = size["width"]
	var height = size["height"]

	var rgba_data = Steam.getImageRGBA(avatar_id)

	if !rgba_data["success"]:
		return null

	var image = Image.create_from_data(
		width,
		height,
		false,
		Image.FORMAT_RGBA8,
		rgba_data["buffer"]
	)

	var texture = ImageTexture.create_from_image(image)

	AVATAR_CACHE[steam_id] = texture

	return texture
