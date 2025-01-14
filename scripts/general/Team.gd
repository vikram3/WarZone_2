extends Node

var team_id : int      = 0
var team_name : String = ""

# a player has { name, id, score, kills, deaths }
var players = {}

signal scoreboard_updated

func _ready():
	add_to_group("Teams")
	Signals.connect("player_disconnected", self, "_on_player_disconnected")
	Signals.connect("entity_killed", self, "on_player_killed") 


func addPlayer(player_ref):
	player_ref.team_id = team_id
	players[player_ref.name] = {
			name   = player_ref.name,
			nick   = player_ref.nick,
			score  = 0,
			kills  = 0,
			deaths = 0,
			ping   = 0,
			ref    = player_ref
		}


func _on_player_disconnected(id : int):
	removePlayer(String(id))


func removePlayer(id : String):
	if players.has(id):
		players.erase(id)
		print("Team::Removing Player %s from Team %s" % [id, team_name])
		emit_signal("scoreboard_updated")


func on_player_killed(victim_name, killer_name, _weapon_name):
	var victim = findPlayer(victim_name)
	var killer = findPlayer(killer_name)
	# Error check
	if victim:
		# Increment Death count
		victim.deaths += 1
	else:
		print("Team::Fatal_Error unable to find victim " + victim_name)
	# Error check
	if killer:
		# Increment Death count
		killer.kills += 1
	else:
		print("Team::Fatal_Error unable to find killer " + killer_name)
	emit_signal("scoreboard_updated")


func findPlayer(player_name):
	if player_name == "":
		return null
	var player = players.get(player_name)
	if player:
		return player
	# print("player::Failed to find player " + player_name)
	return null


func syncData():
	rpc_id(1, "S_syncData", get_tree().get_network_unique_id())

# ........................Networking......................

remote func S_syncData(client_id : int):
	rpc_id(client_id, players)


remote func C_syncData(data : Dictionary):
	players = data
	emit_signal("scoreboard_updated")
