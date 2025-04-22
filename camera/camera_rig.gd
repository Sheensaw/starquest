# CameraRig.gd
# Attaché à un Node3D (pivot) contenant un SpringArm3D + Camera3D
extends Node3D

@export var height_offset: float = 2.0         # Hauteur de la caméra au‑dessus de la cible
@export var smoothing_speed: float = 5.0       # Vitesse de lissage (plus haut = moins de lag)

@onready var spring_arm: SpringArm3D = $SpringArm3D
var follow_target: Node3D

func _ready() -> void:
	add_to_group("camera_rig")
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_error("CameraRig : aucun nœud dans le groupe 'player' trouvé.")
		return
	follow_target = players[0]
	# Position initiale sans lag (poids = 1)
	_update_position(1)

func set_follow_target(new_target: Node3D) -> void:
	follow_target = new_target

func _process(delta: float) -> void:
	if follow_target:
		_update_position(delta)

func _update_position(delta: float) -> void:
	# Calcul de la position cible (au‑dessus de l'entité) :contentReference[oaicite:0]{index=0}
	var target_pos: Vector3 = follow_target.global_position + Vector3(0, height_offset, 0)
	# Lissage (lag) avec interpolation linéaire Vector3.lerp() :contentReference[oaicite:1]{index=1}
	global_position = global_position.lerp(target_pos, smoothing_speed * delta)
