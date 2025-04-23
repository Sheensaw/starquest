# CameraRig.gd
# Pivot contenant un SpringArm3D + Camera3D, suit le joueur
extends Node3D

@export var height_offset: float = 2.0         # Hauteur de la caméra
@export var smoothing_speed: float = 5.0       # Vitesse de lissage

@onready var spring_arm: SpringArm3D = $SpringArm3D
var follow_target: Node3D = null

func _ready() -> void:
	add_to_group("camera_rig")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_error("CameraRig.gd : aucun nœud dans le groupe 'player' trouvé.")
		return
	follow_target = players[0]
	# Placement initial sans lag
	_update_position(1.0)

func set_follow_target(new_target: Node3D) -> void:
	follow_target = new_target

func _process(delta: float) -> void:
	if follow_target:
		_update_position(delta)

func _update_position(delta: float) -> void:
	# Position cible au-dessus du joueur
	var target_pos = follow_target.global_position + Vector3(0, height_offset, 0)
	# Lissage
	global_position = global_position.lerp(target_pos, smoothing_speed * delta)
