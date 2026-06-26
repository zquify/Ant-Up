extends Node

var peers := {}
var carryables := {}

func register_peer(steam_id: int):
	peers[steam_id] = true

func unregister_peer(steam_id: int):
	peers.erase(steam_id)

func send_to_all(data: Dictionary):
	var bytes = var_to_bytes(data)
	for id in peers.keys():
		if id == Globals.STEAM_ID:
			continue
		
		var _result = Steam.sendP2PPacket(
			id,
			bytes,
			Steam.P2P_SEND_UNRELIABLE
		)

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
	
	# Handle carryable pickup
	if data.get("type") == "carryable_pickup":
		var body = carryables.get(data["id"])
		if body:
			var steam_id = data["steam_id"]
			var network_owner_id = data.get("network_owner_id", 0)
			
			# Update local state
			body.carriers[steam_id] = true
			body.network_owner_id = network_owner_id
			body.update_collision_layers_for_local_player()  # ← ADD THIS
			body.update_label_color()
			
			# Only carriers create joints for other carriers
			if body.is_carrier() and steam_id != Globals.STEAM_ID:

				var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
				if player:
					body.create_carrier_joint(steam_id, player)
			
			print_debug("Carryable pickup: steam_id=", steam_id, " owner=", network_owner_id)
		return

	# Handle carryable drop
	if data.get("type") == "carryable_drop":
		var body = carryables.get(data["id"])
		if body:
			var steam_id = data["steam_id"]
			var network_owner_id = data.get("network_owner_id", 0)
			
			# Remove the carrier and their joint
			body.carriers.erase(steam_id)
			
			body.remove_carrier_joint(steam_id)
			body.network_owner_id = network_owner_id
			body.update_collision_layers_for_local_player()  # ← ADD THIS
			body.update_label_color()
			
			print_debug("Carryable drop: steam_id=", steam_id, " owner=", network_owner_id)
		return
	
	# Handle carryable state (network owner sending updates to non-carriers)
	if data.get("type") == "carryable_state":
		var body = carryables.get(data["id"])
		if body == null:
			return
		
		# Only non-carriers receive state updates
		# Carriers simulate locally and ignore these
		if body.is_carrier():
			return
		
		body.network_target_position = data["pos"]
		body.network_target_rotation = data["rot"]
		body.linear_velocity = data["lin_vel"]
		body.angular_velocity = data["ang_vel"]
		
		# Sync carriers list (non-carriers don't create joints)
		var new_carriers = data.get("carriers", [])

		# Convert incoming list into a set for fast lookup
		var new_set := {}
		for id in new_carriers:
			new_set[id] = true

		# REMOVE carriers that no longer exist
		for existing_id in body.carriers.keys():
			if not new_set.has(existing_id):
				body.carriers.erase(existing_id)
				body.remove_carrier_joint(existing_id)

		# ADD only new carriers
		for id in new_carriers:
			if not body.carriers.has(id):
				body.carriers[id] = true

				var player = get_tree().get_first_node_in_group("players_" + str(id))
				if player:
					body.create_carrier_joint(id, player)
		
		return
	
	if data.get("type", "") == "test":
		return
	
	# Player movement packets
	var steam_id = data.get("steam_id")
	if steam_id:
		var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
		if player:
			player.apply_network_state(data)

func register_carryable(body):
	carryables[body.network_id] = body
