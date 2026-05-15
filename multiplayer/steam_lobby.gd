extends Node2D


@onready var name_label: Label = $SteamName
@onready var lobby_set_name: TextEdit = $Create/LobbyEdit
@onready var lobby_get_name: Label = $Create/LobbyLabel
@onready var lobby_output: RichTextLabel = $Chat/ChatLog
@onready var lobby_popup: Panel = $Lobbies
@onready var lobby_list: VBoxContainer = $Lobbies/Scroll/VBox
@onready var player_count: Label = $Players/PlayersLabel
@onready var player_list: RichTextLabel = $Players/PlayersList
@onready var chat_input: TextEdit = $Message/MessageEdit


func _ready():
	# Set steam name on screen
	name_label.text = Globals.STEAM_NAME
	# Steamwork Connections
	Steam.lobby_created.connect(_on_Lobby_Created)
	#Steam.lobby_match_list.connect(_on_Lobby_Match_List)
	Steam.lobby_joined.connect(_on_Lobby_Joined)
	#Steam.lobby_chat_update.connect(_on_Lobby_Chat_Update)
	#Steam.lobby_message.connect(_on_Lobby_Message)
	#Steam.lobby_data_update.connect(_on_Lobby_Date_Update)
	#Steam.join_requested.connect(_on_Join_Requested)
	# Check for command line arguments
	check_Command_Line()


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


func add_Player_List(steam_id, steam_name):
	# Add players to list
	Globals.LOBBY_MEMBERS.append({"steam_id":steam_id, "steam_name":steam_name})
	# Ensure list is cleared
	player_list.clear()
	# Populate player list
	for MEMBER in Globals.LOBBY_MEMBERS:
		player_list.add_text(str(MEMBER['steam_name']) + "\n")


func display_Message(message):
	lobby_output.add_text("\n" + str(message))


#region Steam Callbacks

func _on_Lobby_Created(result, lobbyID):
	if result == 1:
		# Set Lobby ID
		Globals.LOBBY_ID = lobbyID
		display_Message("Created lobby: " + lobby_set_name.text)
		
		# Set Lobby Data
		Steam.setLobbyData(lobbyID, "name", lobby_set_name.text)
		var lobby_name = Steam.getLobbyData(lobbyID, "name")
		lobby_get_name.text = str(lobby_name)

func _on_Lobby_Joined(lobbyID, _permissions, _locked, _response):
	# Set lobby ID
	Globals.LOBBY_ID = lobbyID
	
	# Get the lobby name
	var lobby_name = Steam.getLobbyData(lobbyID, "name")
	lobby_get_name.text = str(lobby_name)
	
	# Get lobby members
	get_Lobby_Members()

func _on_Lobby_Join_Requested(lobbyID, friendID):
	# Get lobby owner's name
	var OWNER_NAME = Steam.getFriendPersonaName(friendID)
	display_Message("Joining " + str(OWNER_NAME) + "'s lobby...")
	
	# Join lobby
	join_Lobby(lobbyID)


# When lobby metadata has changed
func _on_Lobby_DATA_Update(success, lobbyID, memberID, key):
	print("Success: " + str(success) + ", Lobby ID: " + str(lobbyID) + ", Member ID: " + str(memberID) + ", Key: " + str(key))


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



#endregion




#region Button Signal Functions

func _on_create_pressed() -> void:
	create_Lobby()


func _on_join_pressed() -> void:
	pass # Replace with function body.


func _on_start_pressed() -> void:
	pass # Replace with function body.


func _on_leave_pressed() -> void:
	pass # Replace with function body.


func _on_message_pressed() -> void:
	pass # Replace with function body.


func _on_close_pressed() -> void:
	pass # Replace with function body.




#endregion

#region Command Line Arguments

func check_Command_Line():
	var ARGUMENTS = OS.get_cmdline_args()
	
	# Check if detected arguments
	if ARGUMENTS.size() > 0:
		for argument in ARGUMENTS:
			# Invite argument passed
			#if Globals.LOBBY_INVITE_ARG:
				#join_lobby(int(argument))
				
			# Steam connection argument
			if argument == "+connect_lobby":
				Globals.LOBBY_INVITE_ARG = true



#endregion
