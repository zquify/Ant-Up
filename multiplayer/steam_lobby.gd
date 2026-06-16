extends Node2D

@export var game_scene: PackedScene

@onready var name_label: Label = $SteamName
@onready var chat_label: Label = $Chat/ChatLabel
@onready var lobby_output: RichTextLabel = $Chat/ChatLog
@onready var lobby_popup: Panel = $Lobbies
@onready var lobby_list: VBoxContainer = $Lobbies/Scroll/VBox
@onready var player_count: Label = $Players/PlayersLabel
@onready var player_entries: VBoxContainer = $Players/ScrollContainer/PlayerEntries
@onready var chat_input: TextEdit = $Message/MessageEdit
@onready var start_button: Button = $Start

@export var player_entry_scene: PackedScene

func _ready():
	# Set steam name on screen
	name_label.text = Globals.STEAM_NAME
	
	# Steamwork Connections
	Steam.lobby_created.connect(_on_Lobby_Created)
	Steam.lobby_match_list.connect(_on_Lobby_Match_List)
	Steam.lobby_joined.connect(_on_Lobby_Joined)
	Steam.lobby_chat_update.connect(_on_Lobby_Chat_Update)
	Steam.lobby_message.connect(_on_Lobby_Message)
	
	
	
	
	# Initial button state
	update_Start_Button()

var timer := 0.0

func _process(delta):
	if Globals.LOBBY_ID == 0:
		return

	timer += delta

	if timer >= 1.0:
		timer = 0.0

		Network.send_to_all({
			"steam_id": Globals.STEAM_ID,
			"type": "test"
		})


func create_Lobby():
	# Check no other Lobby is running
	if Globals.LOBBY_ID == 0:
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 8)



func join_Lobby(lobbyID):
	lobby_popup.hide()
	var lobby_name = Steam.getLobbyData(lobbyID, "name")
	display_Message("Joining lobby: " + str(lobby_name) + "...")
	
	# Clear previous lobby members lists
	Globals.LOBBY_MEMBERS.clear()
	
	# Steam join request
	Steam.joinLobby(lobbyID)



func get_Lobby_Members():
	# Clear previous lobby members lists
	Globals.LOBBY_MEMBERS.clear()
	
	# Get number of members in lobby
	var MEMBERCOUNT = Steam.getNumLobbyMembers(Globals.LOBBY_ID)
	# Update player list count
	player_count.set_text("Players (" + str(MEMBERCOUNT) + ")")
	
	# Get members data
	for MEMBER in range(0, MEMBERCOUNT):
		# Member's Steam ID
		var MEMBER_STEAM_ID = Steam.getLobbyMemberByIndex(Globals.LOBBY_ID, MEMBER)
		# Member's Steam Name
		var MEMBER_STEAM_NAME = Steam.getFriendPersonaName(MEMBER_STEAM_ID)
		# Add members to list
		add_Player_List(MEMBER_STEAM_ID, MEMBER_STEAM_NAME)
	
	for member in Globals.LOBBY_MEMBERS:
		if member["steam_id"] == Globals.STEAM_ID:
			continue

		Network.register_peer(member["steam_id"])
	
	# Update button state
	update_Start_Button()



func add_Player_List(steam_id, steam_name):
	# Add players to list
	Globals.LOBBY_MEMBERS.append({"steam_id":steam_id, "steam_name":steam_name})
	# Refresh the list with colors
	refresh_Player_List()



func refresh_Player_List():

	for child in player_entries.get_children():
		child.queue_free()

	for member in Globals.LOBBY_MEMBERS:

		var entry : LobbyPlayerEntry = player_entry_scene.instantiate()

		player_entries.add_child(entry)

		var avatar_texture = Globals.get_avatar_texture(
			member["steam_id"]
		)

		entry.setup(
			member["steam_name"],
			avatar_texture
		)



func send_Chat_Message():
	# Get chat input
	var MESSAGE = chat_input.text
	# Pass message to Steam
	var SENT = Steam.sendLobbyChatMsg(Globals.LOBBY_ID, MESSAGE)
	# Check message sent
	if not SENT:
		display_Message("ERROR: Chat message failed to send")
	# Clear chat input
	chat_input.text = ""



func leave_Lobby():
	if not is_instance_valid(player_entries):
		return
	
	if Globals.LOBBY_ID != 0:
		display_Message("Leaving lobby...")

		Steam.leaveLobby(Globals.LOBBY_ID)
		Globals.LOBBY_ID = 0

		chat_label.text = "Lobby Name"
		player_count.text = "Players (0)"

		for MEMBERS in Globals.LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(MEMBERS['steam_id'])

		Globals.LOBBY_MEMBERS.clear()

		Globals.IS_HOST = false
		Globals.PLAYER_READY = false

		update_Start_Button()

		refresh_Player_List()



func display_Message(message):
	lobby_output.add_text("\n" + str(message))



func update_Start_Button():
	# If not in a lobby, disable button
	if Globals.LOBBY_ID == 0:
		start_button.disabled = true
		start_button.text = "START GAME"
		return
	
	# Check if player is host
	var lobby_owner = Steam.getLobbyOwner(Globals.LOBBY_ID)
	Globals.IS_HOST = (lobby_owner == Globals.STEAM_ID)
	
	# Enable button if in lobby
	start_button.disabled = false
	
	if Globals.IS_HOST:
		# Host sees "START GAME"
		start_button.text = "START GAME"
		start_button.self_modulate = Color.WHITE
	else:
		# Non-host sees ready status (FLIPPED)
		if Globals.PLAYER_READY:
			start_button.text = "UNREADY"
			start_button.self_modulate = Color.RED
		else:
			start_button.text = "READY"
			start_button.self_modulate = Color.GREEN



#region Steam Callbacks


func _on_Lobby_Created(result, lobbyID):
	if result == 1:
		# Set Lobby ID
		Globals.LOBBY_ID = lobbyID
		
		# Set Lobby Data - use host's Steam name
		Steam.setLobbyData(lobbyID, "name", Globals.STEAM_NAME)
		var lobby_name = Steam.getLobbyData(lobbyID, "name")
		chat_label.text = str(lobby_name)
		
		display_Message("Created lobby: " + str(lobby_name))
		
		# Update button state
		update_Start_Button()



func broadcast_Ready_Status():
	# Get current ready statuses
	var ready_data = ""
	for member in Globals.LOBBY_MEMBERS:
		if ready_data != "":
			ready_data += ";"
		var is_ready = "true" if Globals.PLAYER_READY and member['steam_id'] == Globals.STEAM_ID else "false"
		ready_data += str(member['steam_id']) + ":" + is_ready
	
	# Set lobby data so host can see it
	Steam.setLobbyData(Globals.LOBBY_ID, "ready_status", ready_data)



func _on_Lobby_Joined(lobbyID, _permissions, _locked, _response):
	# Set lobby ID
	Globals.LOBBY_ID = lobbyID
	
	# Get the lobby name (host's name)
	var lobby_name = Steam.getLobbyData(lobbyID, "name")
	chat_label.text = str(lobby_name)
	
	# Listen for lobby data updates
	Steam.lobby_data_update.connect(_on_Lobby_Data_Update)
	
	# Get lobby members
	get_Lobby_Members()



func _on_Lobby_Chat_Update(_lobbyID, _changedID, makingChangeID, chatState):
	# User who made lobby change
	var CHANGER = Steam.getFriendPersonaName(makingChangeID)
	
	# chatState change mode
	if chatState == 1:
		display_Message(str(CHANGER) + " has joined the lobby.")
	elif chatState == 2:
		display_Message(str(CHANGER) + " has left the lobby.")
	elif chatState == 8:
		display_Message(str(CHANGER) + " has been kicked from the lobby.")
	elif chatState == 16:
		display_Message(str(CHANGER) + " has banned from the lobby.")
	else:
		display_Message(str(CHANGER) + " did... something.")
	
	# Update lobby
	get_Lobby_Members()



func _on_Lobby_Data_Update(_success, lobbyID, _memberID, key):
	# When ready status changes, update host's view
	if key == "ready_status":
		var ready_data = Steam.getLobbyData(lobbyID, "ready_status")
		print("Ready status data: " + ready_data)
		
		# Parse and store ready statuses
		var ready_states = {}
		for line in ready_data.split(";"):
			if line.is_empty():
				continue
			var parts = line.split(":")
			if parts.size() == 2:
				ready_states[int(parts[0])] = (parts[1] == "true")
		
		Globals.PLAYERS_READY_STATUS = ready_states
		
		# If host, display updated ready statuses
		if Globals.IS_HOST:
			display_Message("Ready status updated")



func _on_Lobby_Match_List(lobbies):
	for LOBBY in lobbies:
		# Grab desired lobby data
		var LOBBY_NAME = Steam.getLobbyData(LOBBY, "name")
		
		# Get the current number of members
		var LOBBY_MEMBERS = Steam.getNumLobbyMembers(LOBBY)
		
		# Create button for each lobby
		var LOBBY_BUTTON = Button.new()
		LOBBY_BUTTON.set_text("Lobby " + str(LOBBY) + ": " + str(LOBBY_NAME) + " - [" + str(LOBBY_MEMBERS) + "] Players(s)")
		LOBBY_BUTTON.set_size(Vector2(800, 50))
		LOBBY_BUTTON.set_name("lobby_" + str(LOBBY))
		LOBBY_BUTTON.pressed.connect(func():
			join_Lobby(LOBBY)
		)
		
		# Add lobby to the list
		lobby_list.add_child(LOBBY_BUTTON)



func _on_Lobby_Message(_result, user, message, _type):
	# Sender and their message
	var SENDER = Steam.getFriendPersonaName(user)
	
	# Check if this is a game start command from host
	if message == "HOST_START_GAME":
		var lobby_owner = Steam.getLobbyOwner(Globals.LOBBY_ID)
		if user == lobby_owner:  # Only accept from actual host
			display_Message("Host is starting the game...")
			if game_scene == null:
				display_Message("ERROR: Game scene not set in inspector!")
				return
			get_tree().change_scene_to_packed(game_scene)
			return
	
	# Check if this is a ready status update
	if message.begins_with("PLAYER_READY:"):
		var parts = message.split(":")
		if parts.size() == 3:
			var player_id = int(parts[1])
			var ready_status = parts[2]
			Globals.PLAYERS_READY_STATUS[player_id] = (ready_status == "READY")
			display_Message(str(SENDER) + " is " + ready_status)
			# Refresh the player list to update colors
			refresh_Player_List()
			return
	
	# Regular chat message
	display_Message(str(SENDER) + " : " + str(message))


#endregion

#region Button Signal Functions


func _on_create_pressed() -> void:
	create_Lobby()



func _on_join_pressed() -> void:
	lobby_popup.show()
	# Set server search distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LobbyDistanceFilter.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	display_Message("Searching for lobbies...")
	
	Steam.requestLobbyList()



func _on_start_pressed() -> void:
	if Globals.LOBBY_ID == 0:
		return
	
	if Globals.IS_HOST:
		# Host starts the game
		if game_scene == null:
			display_Message("ERROR: Game scene not set in inspector!")
			return
		
		display_Message("Starting game...")
		# Send message to all clients to start
		Steam.sendLobbyChatMsg(Globals.LOBBY_ID, "HOST_START_GAME")
		
		# Host also transitions
		get_tree().change_scene_to_packed(game_scene)
	else:
		# Non-host toggles ready status
		Globals.PLAYER_READY = !Globals.PLAYER_READY
		display_Message("Ready status: " + ("READY" if Globals.PLAYER_READY else "NOT READY"))
		
		# Broadcast ready status to all players
		var status = "READY" if Globals.PLAYER_READY else "NOT READY"
		Steam.sendLobbyChatMsg(Globals.LOBBY_ID, "PLAYER_READY:" + str(Globals.STEAM_ID) + ":" + status)
		
		update_Start_Button()


func _on_leave_pressed() -> void:
	leave_Lobby()



func _on_message_pressed() -> void:
	send_Chat_Message()



func _on_close_pressed() -> void:
	lobby_popup.hide()


#endregion
