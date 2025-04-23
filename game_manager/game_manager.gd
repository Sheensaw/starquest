# GameManager.gd
# Gère la caméra (root node de Main.tscn)
extends Node

@onready var player: CharacterBody3D = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
@onready var camera_rig: Node3D = get_tree().get_nodes_in_group("camera_rig")[0] if get_tree().has_group("camera_rig") else null

func _ready() -> void:
	if not player:
		push_error("GameManager.gd : aucun joueur trouvé dans le groupe 'player'.")
	if not camera_rig:
		push_error("GameManager.gd : aucun camera_rig trouvé dans le groupe 'camera_rig'.")
	if player and camera_rig:
		camera_rig.set_follow_target(player)
