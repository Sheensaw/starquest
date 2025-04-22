# GameManager.gd
extends Node

var player: CharacterBody3D
var camera_rig: Node3D
var current_controlled: Node3D

func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_error("GameManager : aucun joueur trouvé")
		return
	player = players[0] as CharacterBody3D

	var rigs = get_tree().get_nodes_in_group("camera_rig")
	if rigs.is_empty():
		push_error("GameManager : aucun CameraRig trouvé")
		return
	camera_rig = rigs[0] as Node3D

	current_controlled = player
	_update_camera_target()

	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		vehicle.connect("request_control", Callable(self, "_on_vehicle_request_control"))
		vehicle.connect("request_release_control", Callable(self, "_on_vehicle_request_release_control"))

func _on_vehicle_request_control(vehicle: Node3D) -> void:
	if current_controlled == player:
		print("✅ Contrôle transféré au véhicule :", vehicle.name)
		player.is_active = false
		player.visible = false
		vehicle.is_controlled = true
		current_controlled = vehicle
		_update_camera_target()

func _on_vehicle_request_release_control(vehicle: Node3D) -> void:
	if current_controlled == vehicle:
		print("↩️ Sortie du véhicule :", vehicle.name)
		var space_state = vehicle.get_world_3d().direct_space_state
		var vehicle_pos = vehicle.global_transform.origin
		var found = false

		for i in range(15):
			var angle = randf() * TAU
			var distance = randf_range(1.0, 2.5)
			var offset = Vector3(cos(angle), 0, sin(angle)) * distance
			var ray_origin = vehicle_pos + offset + Vector3.UP * 5.0
			var ray_target = ray_origin + Vector3.DOWN * 30.0

			var ray_params = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
			ray_params.collision_mask = 1
			ray_params.exclude = [vehicle, player]

			var result = space_state.intersect_ray(ray_params)
			print("🔍 Tentative raycast depuis", ray_origin)
			if result:
				print("✅ Sol trouvé :", result.position)
				player.global_transform.origin = result.position
				found = true
				break

		if not found:
			print("⚠️ Sol introuvable. Repositionnement par défaut")
			player.global_transform.origin = vehicle_pos + Vector3(0, 2, 0)

		player.visible = true
		player.is_active = true
		vehicle.is_controlled = false
		current_controlled = player
		_update_camera_target()

func _update_camera_target() -> void:
	if camera_rig:
		camera_rig.call("set_follow_target", current_controlled)
