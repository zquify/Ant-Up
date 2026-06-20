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
			var authority_id = data.get("authority_id", 0)
			
			# Update local state
			body.carriers[steam_id] = true
			body.authority_id = authority_id
			
			# Create a joint for this carrier if it's not us
			# (Authority needs joints for all other carriers, clients need joints for all carriers)
			if steam_id != Globals.STEAM_ID:
				var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
				if player:
					body.create_carrier_joint(steam_id, player)
			
			print_debug("Carryable pickup: steam_id=", steam_id, " authority=", authority_id)
		return
	
	# Handle carryable drop
	if data.get("type") == "carryable_drop":
		var body = carryables.get(data["id"])
		if body:
			var steam_id = data["steam_id"]
			var authority_id = data.get("authority_id", 0)
			
			# Remove the carrier and their joint
			body.carriers.erase(steam_id)
			body.remove_carrier_joint(steam_id)
			body.authority_id = authority_id
			
			# Reset collision if no more carriers
			if body.carriers.size() == 0:
				body.axis_lock_angular_x = false
				body.collision_layer = 4
			
			print_debug("Carryable drop: steam_id=", steam_id, " authority=", authority_id)
		return
	
	# Handle carryable state (physics authority sending updates)
	if data.get("type") == "carryable_state":
		var body = carryables.get(data["id"])
		if body == null:
			return
		
		# Only non-authority players receive state updates
		if body.authority_id == Globals.STEAM_ID:
			return
		
		body.network_target_position = data["pos"]
		body.network_target_rotation = data["rot"]
		body.linear_velocity = data["lin_vel"]
		body.angular_velocity = data["ang_vel"]
		
		# Sync carriers list and create joints for any new carriers
		var new_carriers = data.get("carriers", [])
		for steam_id in new_carriers:
			if steam_id not in body.carriers:
				# New carrier we don't know about yet
				body.carriers[steam_id] = true
				# Create a joint for them if we're not the authority
				if body.authority_id != Globals.STEAM_ID:
					var player = get_tree().get_first_node_in_group("players_" + str(steam_id))
					if player:
						body.create_carrier_joint(steam_id, player)
		
		# Remove any carriers that are no longer listed
		var to_remove = []
		for steam_id in body.carriers.keys():
			if steam_id not in new_carriers:
				to_remove.append(steam_id)
		for steam_id in to_remove:
			body.carriers.erase(steam_id)
			body.remove_carrier_joint(steam_id)
		
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
