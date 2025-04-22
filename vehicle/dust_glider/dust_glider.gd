extends RigidBody3D

signal request_control(glider)
signal request_release_control(glider)

@export var hover_height: float = 2.0
@export var hover_k: float = 1000.0
@export var hover_c: float = -1.0

@export var move_force: float = 900.0
@export var max_speed: float = 18.0
@export var rotation_align_speed: float = 6.0

@export var orient_k: float = 150.0
@export var orient_c: float = 50.0

var is_controlled: bool = false
var raycasts: Array[RayCast3D] = []
var damping_coeff: float = 0.0

func _ready() -> void:
	add_to_group("vehicles")
	var names = ["RayCastFL", "RayCastFR", "RayCastBL", "RayCastBR"]
	for name in names:
		var rc = get_node_or_null(name)
		if rc and rc is RayCast3D:
			rc.enabled = true
			raycasts.append(rc)
		else:
			push_warning("DustGlider: RayCast3D introuvable ou invalide : %s" % name)
	if raycasts.is_empty():
		push_error("DustGlider: aucun RayCast3D valide trouvé !")

	if hover_c <= 0:
		damping_coeff = 2.0 * sqrt(hover_k * mass)
	else:
		damping_coeff = hover_c

	linear_damp = 0.2
	angular_damp = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if is_controlled and event.is_action_pressed("Interact"):
		print("🔄 Demande de sortie du véhicule :", name)
		emit_signal("request_release_control", self)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var total_contacts = 0
	var avg_normal = Vector3.ZERO

	for rc in raycasts:
		rc.force_raycast_update()
		if rc.is_colliding():
			total_contacts += 1
			var hit_point = rc.get_collision_point()
			var hit_normal = rc.get_collision_normal()
			avg_normal += hit_normal

			var current_pos = rc.global_transform.origin
			var dist = current_pos.distance_to(hit_point)
			var dir = hit_normal

			var offset = current_pos - global_transform.origin
			var vel = linear_velocity + angular_velocity.cross(offset)
			var v_rel = vel.dot(dir)

			var spring_force = hover_k * (hover_height - dist)
			var damper_force = -damping_coeff * v_rel
			state.apply_force(dir * (spring_force + damper_force), offset)

	if total_contacts == 0:
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		state.apply_central_force(Vector3.DOWN * mass * gravity)

	if total_contacts > 0:
		avg_normal = (avg_normal / total_contacts).normalized()
		var current_up = global_transform.basis.y
		var torque_axis = current_up.cross(avg_normal)
		if torque_axis.length_squared() > 0.001:
			var angle_error = acos(clamp(current_up.dot(avg_normal), -1.0, 1.0))
			var torque_p = orient_k * angle_error * torque_axis.normalized()
			var torque_d = -orient_c * angular_velocity
			state.apply_torque(torque_p + torque_d)

	# CONTRÔLE DU VÉHICULE AVEC JOYSTICK
	if is_controlled:
		# Récupère le vecteur d'entrée du joystick
		var input_vector = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward", 0.2)
		if input_vector.length() > 0.1:
			var local_dir = Vector3(input_vector.x, 0, input_vector.y).normalized()
			var desired_dir = global_transform.basis * local_dir
			# Projection manuelle sur le plan du sol
			desired_dir = desired_dir - avg_normal * desired_dir.dot(avg_normal)
			desired_dir = desired_dir.normalized()

			var horizontal_velocity = linear_velocity - avg_normal * linear_velocity.dot(avg_normal)
			if horizontal_velocity.length() < max_speed:
				state.apply_central_force(desired_dir * move_force)

			# Orientation immédiate vers la direction de l'entrée
			var current_forward = -global_transform.basis.z
			current_forward = current_forward - avg_normal * current_forward.dot(avg_normal)
			current_forward = current_forward.normalized()

			var angle = current_forward.angle_to(desired_dir)
			var rotation_axis = current_forward.cross(desired_dir).normalized()

			if angle > 0.01 and rotation_axis.length_squared() > 0.001:
				state.apply_torque(rotation_axis * angle * rotation_align_speed * mass)
