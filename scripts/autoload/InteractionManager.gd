# InteractionManager.gd
# Autoload singleton (Project > Project Settings > Autoload, name: InteractionManager)
extends Node

signal interaction_started(by, target)
signal interaction_ended(by, target)

var current_target: Node = null

func _ready():
	pass

func register_enter(target: Node):
	current_target = target
	var player = get_tree().get_nodes_in_group("player")[0]
	emit_signal("interaction_started", player, target)

func register_exit(target: Node):
	if current_target == target:
		var player = get_tree().get_nodes_in_group("player")[0]
		emit_signal("interaction_ended", player, target)
		current_target = null

func interact():
	if not current_target:
		return
	if current_target.is_in_group("vehicles"):
		current_target.emit_signal("request_control", current_target)
	elif current_target.has_method("interact"):
		current_target.call("interact", get_tree().get_nodes_in_group("player")[0])
