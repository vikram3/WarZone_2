# Network
extends Node2D

# Server advertiser for lan
var serverAvertiser = null
# List of connected players
var players = {}
var ping_timer = null
var ping_time_stamp = 0

var sysAdmin_online = false
var sysAdmin_id = 0

# Signals
signal server_created                          # when server is successfully created
signal join_success                            # When the peer successfully joins a server
signal join_fail                               # Failed to join a server
signal player_list_changed                     # List of players has been changed
signal player_removed(pinfo)				   # Called when player is removed
signal disconnected
signal server_stopped



func _ready():
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_disconnected_from_server")
	connect("server_stopped", self, "on_server_stopped")
	

func _on_player_connected(_id):
	pass

# Called when player disconnects
func _on_player_disconnected(id):
	if players.has(id):
		print("Player ", players[id].name, " disconnected from server")
		if get_tree().is_network_server():
			rpc("unregister_player", id)


# Called when connected to server
func _on_connected_to_server():
	Logger.Log("Connected to server")
	game_states.player_info.net_id = get_tree().get_network_unique_id()
	rpc("register_player", game_states.player_info)
	emit_signal("join_success")


func _on_connection_failed():
	emit_signal("join_fail")
	get_tree().set_network_peer(null)


func _on_disconnected_from_server():
	print("Disconnected from server")
	# Clear the network object
	get_tree().set_network_peer(null)
	# Allow outside code to know about the disconnection
	emit_signal("disconnected")
	# Clear the internal player list
	players.clear()
	# Reset the player info network ID
	game_states.player_info.net_id = 1


# Create server
func create_server(server_name, port, max_players):
	players.clear()
	var net = NetworkedMultiplayerENet.new()
	Logger.Log("Creating server %s on port %d" % [server_name,port])
	
	if net.create_server(port,max_players) != OK:
		Logger.Log("Failed to create server on port %d" % [port])	
		return
		
	get_tree().set_network_peer(net)
	emit_signal("server_created")
	Logger.Log("Loading Server Avertiser")
	serverAvertiser = preload("res://Objects/Global/ServerAdvertiser.gd").new()
	# Register self
	rpc("register_player", game_states.player_info)
	# Set server info
	game_server.serverInfo.port = String(port)
	game_server.serverInfo.max_players = String(max_players)
	game_server.serverInfo.name = server_name
	game_server.serverInfo.plrs = String(1)
	
	ping_timer = Timer.new()
	ping_timer.wait_time = 1.0
	add_child(ping_timer)
	ping_timer.connect("timeout", self, "on_ping_timer_timeout")
	ping_timer.start()


# Ping Update timer
func on_ping_timer_timeout():
	# Send prev ping data
	var prev_ping_data = {}
	for i in players:
		prev_ping_data[i] = players[i].ping
	rpc("P_getPingValues", prev_ping_data)
	
	# Get timestamp
	ping_time_stamp = OS.get_ticks_msec()
	# Send ping msg
	rpc("P_sendPing_msg")


# Sent ping msg to server
remote func P_sendPing_msg():
	rpc_id(1, "S_replyPing_msg", game_states.player_info.net_id)
	
# Calculate ping for client
remotesync func S_replyPing_msg(id):
	players[id].ping = (OS.get_ticks_msec() - ping_time_stamp)


# Get ping values for clients
remote func P_getPingValues(data):
	for i in players:
		if data.has(i):
			players[i].ping = data[i]


# Join server
func join_server(ip, port):
	Logger.Log("Connecting to server %s:%d" % [ip,port])
	players.clear()
	var net = NetworkedMultiplayerENet.new()
	if net.create_client(ip, port) != OK:
		Logger.Log("Failed to connect to %s:%s" % [ip, port])
		emit_signal("join_fail")
		return
	Logger.Log("Connection successful")
	Logger.Log("Connected to %s:%s" % [ip, port])
	get_tree().set_network_peer(net)


# Register Player
remotesync func register_player(pinfo):
	# Server side
	if get_tree().is_network_server():
		if serverAvertiser:
			serverAvertiser.serverInfo.plrs = String(players.size() + 1)

	Logger.Log("Regestering player %s with id %d" % [pinfo.name, pinfo.net_id])
	players[pinfo.net_id] = pinfo          # Create the player entry in the dictionary
	emit_signal("player_list_changed")     # And notify that the player list has been changed


remotesync func unregister_player(id):
	Logger.Log("Un-regestering player %s with id %d" % [players[id].name, players[id].net_id])
	emit_signal("player_removed", players[id])
	
	if sysAdmin_online and sysAdmin_id == id:
		sysAdmin_online = false
		sysAdmin_id = ""
		Logger.Log("SysAdmin Left")
	
	players.erase(id)
	emit_signal("player_list_changed")
	

remote func kick_player(net_id, reason):
	if get_tree().is_network_server():
		if net_id == 1:
			Logger.Log("Kicking server player, Server will be closed")
			_close_server()
		else:
			Logger.Log("Kicking player %d for %s" % [net_id,reason])
			rpc_id(net_id,"kicked", reason)
			get_tree().network_peer.disconnect_peer(net_id)


remote func kicked(reason):
	#get_tree().network_peer.disconnect_peer(game_states.player_info.net_id)
	#get_tree().network_peer.disconnect_peer(game_states.player_info.net_id)
	print("You have been kicked from the server, reason: ", reason)


func _close_server():
	#kick players
	for i in players:
		if i != 1:
			print(i)
			rpc_id(i,"kicked", "Server Closed")
			get_tree().network_peer.disconnect_peer(i)
	players.clear()
	#Terminate server
	get_tree().set_network_peer(null)
	emit_signal("server_stopped")
	serverAvertiser.queue_free()
	serverAvertiser = null
	get_tree().get_nodes_in_group("Level")[0].queue_free()
	MenuManager.changeScene("summary")
	

func stopServer():
	Logger.Log("Closing server")
	#kick players
	for i in players:
		if i != 1:
			print(i)
			rpc_id(i,"kicked", "Server Closed")
			get_tree().network_peer.disconnect_peer(i)
	players.clear()
	#Terminate server
	get_tree().set_network_peer(null)
	emit_signal("server_stopped")
	serverAvertiser.queue_free()


remote func S_register_sysAdmin(admin_id):
	if get_tree().is_network_server():
		sysAdmin_online = true
		sysAdmin_id = admin_id
	else:
		Logger.Log("Error: Unable to register sysAdmin, This is not server")


func on_server_stopped():
	if ping_timer:
		ping_timer.queue_free()
		ping_timer = null
