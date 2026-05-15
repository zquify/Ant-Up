extends Node2D


@onready var steam_name: Label = $SteamName
@onready var lobby_set_name: TextEdit = $Create/LobbyEdit
@onready var lobby_get_name: Label = $Create/LobbyLabel
@onready var lobby_output: RichTextLabel = $Chat/ChatLog
@onready var lobby_popup: Panel = $Lobbies
@onready var lobby_list: VBoxContainer = $Lobbies/Scroll/VBox
@onready var players_count: Label = $Players/PlayersLabel
@onready var players_list: RichTextLabel = $Players/PlayersList
@onready var chat_input: TextEdit = $Message/MessageEdit


func _ready():
	# Set steam name on screen
	steam_name.text = Globals.STEAM_NAME
	# Steamwork Connections
	Steam.lobby_created.connect(_on_Lobby_Created)
	#Steam.lobby_match_list.connect(_on_Lobby_Match_List)
	#Steam.lobby_joined.connect(_on_Lobby_Joined)
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
