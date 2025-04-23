# ControlStateMachine.gd
# Node enfant de GameManager.tscn
extends Node
class_name controlStateMachine

enum State { PLAYER_CONTROL, VEHICLE_CONTROL }

var state = State.PLAYER_CONTROL
var player: CharacterBody3D
var vehicle: Node

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	for v in get_tree().get_nodes_in_group("vehicles"):
		# Connexion via Callable pour Godot 4
		v.connect("request_control", Callable(self, "_on_request_control"))
		v.connect("request_release_control", Callable(self, "_on_request_release"))

func _on_request_control(v: Node):
	if state == State.PLAYER_CONTROL:
		_switch_to_vehicle(v)

func _on_request_release(v: Node):
	if state == State.VEHICLE_CONTROL and v == vehicle:
		_switch_to_player()

func _switch_to_vehicle(v: Node):
	vehicle = v
	player.is_active = false
	player.visible = false
	vehicle.is_controlled = true
	state = State.VEHICLE_CONTROL
	_update_camera()

func _switch_to_player():
	player.global_transform.origin = vehicle.global_transform.origin + Vector3(0, 2, 0)
	player.visible = true
	player.is_active = true
	vehicle.is_controlled = false
	state = State.PLAYER_CONTROL
	_update_camera()

func _update_camera():
	var rigs = get_tree().get_nodes_in_group("camera_rig")
	if rigs.size() == 0:
		return
	var rig = rigs[0]
	var target = player if state == State.PLAYER_CONTROL else vehicle
	rig.call("set_follow_target", target)
