extends Node

var peers := {}

func register_peer(steam_id: int):
	peers[steam_id] = true

func unregister_peer(steam_id: int):
	peers.erase(steam_id)

func send_to_all(data: Dictionary):
	var bytes = var_to_bytes(data)

	for id in peers.keys():
		if id == Globals.STEAM_ID:
			continue
		Steam.sendP2PPacket(id, bytes, Steam.P2P_SEND_UNRELIABLE)

func read_packets():
	var size = Steam.getAvailableP2PPacketSize()

	while size > 0:
		var packet = Steam.readP2PPacket(size)
		if packet.is_empty():
			return

		var data = bytes_to_var(packet["data"])
		handle_packet(data)

		size = Steam.getAvailableP2PPacketSize()

func handle_packet(data: Dictionary):
	var steam_id = data["steam_id"]

	var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
	if player:
		player.apply_network_state(data)
	
	print("Received packet from ", steam_id)
