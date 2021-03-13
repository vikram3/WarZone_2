# Script to chk and report Limits
extends Node

onready var game_mode = get_parent()

signal timelimit_over
signal scorelimit_over

func _ready():
	loadTimer()
	connectToTeams()


func loadTimer():
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = game_mode.mode_settings.time_limit * 60
	timer.connect("timeout", self, "_on_timer_timeout") 
	add_child(timer)
	timer.start()

func connectToTeams():
	var teams = get_tree().get_nodes_in_group("Teams")
	for i in teams:
		i.connect("scoreboard_updated", self, "_on_scoreboard_updated") 

func _on_timer_timeout():
	emit_signal("timelimit_over")


func _on_scoreboard_updated():
	var teams = get_tree().get_nodes_in_group("Teams")
	for t in teams:
		var arr = t.players.values()
		for i in arr:
			if i.kills >= game_mode.mode_settings.frag_limit:
				emit_signal("scorelimit_over")
				return