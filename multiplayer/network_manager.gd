extends Node

var peers := {}
var carryables := {}

func register_peer(steam_id: int):
	print("Registering peer ", steam_id)
	peers[steam_id] = true

func unregister_peer(steam_id: int):
	peers.erase(steam_id)

func send_to_all(data: Dictionary):
	var bytes = var_to_bytes(data)

	for id in peers.keys():
		if id == Globals.STEAM_ID:
			continue
		
		var result = Steam.sendP2PPacket(
			id,
			bytes,
			Steam.P2P_SEND_UNRELIABLE
		)
		
		if !result:
			print("Failed sending to ", id)

func read_packets():
	var size = Steam.getAvailableP2PPacketSize()
	
	if size > 0:
		print("Packets available")
	
	while size > 0:
		var packet = Steam.readP2PPacket(size)
		if packet.is_empty():
			return

		var data = bytes_to_var(packet["data"])
		handle_packet(data)

		size = Steam.getAvailableP2PPacketSize()

var seen_first_packet := false

func handle_packet(data: Dictionary):
	if data.get("type") == "ai_state":
		
		var ai = get_tree().get_first_node_in_group("ai_" + str(data["id"]))
		if ai == null:
			return
		
		if ai.is_authority:
			return
		
		ai.network_target_position = data["pos"]
		ai.network_velocity = data["vel"]
		ai.rotation.y = data["rot_y"]
		ai.state = data["state"]
		
		return

	if data.get("type","") == "carryable_claim":

		var body = carryables.get(data["id"])

		if body:
			body.authority_id = data["owner"]

		return

	if data.get("type","") == "carryable_state":

		var body = carryables.get(data["id"])

		if body == null:
			return

		if body.authority_id == Globals.STEAM_ID:
			return

		body.network_target_position = data["pos"]
		body.network_target_rotation = data["rot"]
		body.linear_velocity = data["lin_vel"]
		body.angular_velocity = data["ang_vel"]

		return

	if data.get("type", "") == "test":
		print("Received test packet from ", data["steam_id"])
		return

	# Player movement packets fall through to here
	var steam_id = data["steam_id"]

	var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
	if player:
		player.apply_network_state(data)


func register_carryable(body):
	carryables[body.network_id] = body
