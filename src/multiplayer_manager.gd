extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene

func _on_host_pressed() -> void:
	peer.create_server(1027)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# Spawn the host's own player
	_spawn_player(multiplayer.get_unique_id(), _pick_spawn())
	$MultiplayerHUD.hide()

func _on_join_pressed() -> void:
	peer.create_client("127.0.0.1", 1027)
	multiplayer.multiplayer_peer = peer
	# 'connected_to_server' is the correct signal for clients
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	$MultiplayerHUD.hide()

# ---- Server-side: a new client connected ----
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	# Tell the new client about every player that already exists
	for child in $Players.get_children():
		rpc_id(id, "_spawn_player", int(child.name), child.position)
	# Pick a spawn for the new player and tell everyone
	_spawn_player.rpc(id, _pick_spawn())

# ---- Client-side: successfully joined the server ----
func _on_connected_to_server() -> void:
	# Nothing needed here; the server will call _spawn_player on us via RPC
	pass

func _on_peer_disconnected(id: int) -> void:
	_del_player.rpc(id)

# ---- Helpers ----
func _pick_spawn() -> Vector3:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_position
	return Vector3.ZERO

# ---- RPC: runs on EVERY peer, spawns one player ----
@rpc("authority", "call_local", "reliable")
func _spawn_player(id: int, spawn_pos: Vector3) -> void:
	if get_node_or_null(str(id)) != null:
		return  # Already exists (guard against duplicates)
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = spawn_pos
	# Give each player authority over their own node so input works correctly
	player.set_multiplayer_authority(id)
	$Players.add_child(player)

@rpc("authority", "call_local", "reliable")
func _del_player(id: int) -> void:
	var node = $Players._node_or_null(str(id))
	if node:
		node.queue_free()
