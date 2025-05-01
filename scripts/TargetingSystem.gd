extends Node

@export var detection_radius: float = 20.0
@export var cone_angle: float = 45.0
@export var detectable_groups: PackedStringArray = ["aimables", "enemies"]

var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()

func get_detected_target() -> Node3D:
	var fwd = -player.global_transform.basis.z.normalized()
	var best_dist = detection_radius
	var nearest: Node3D = null
	for grp in detectable_groups:
		var nodes = get_tree().get_nodes_in_group(grp)
		for ent in nodes:
			if not (ent is Node3D) or not is_instance_valid(ent):
				continue
			if _is_invalid_enemy(ent):
				continue
			var dist = player.global_position.distance_to(ent.global_position)
			var dir_to_ent = (ent.global_position - player.global_position).normalized()
			var dot_product = fwd.dot(dir_to_ent)
			var angle_cos = cos(deg_to_rad(cone_angle))
			if dist < best_dist and dot_product >= angle_cos:
				best_dist = dist
				nearest = ent
	return nearest

func _is_invalid_enemy(ent: Node3D) -> bool:
	if ent.has_method("is_stunned") and ent.is_stunned():
		return true
	if ent.has_method("is_dead") and ent.is_dead():
		return true
	return false
