extends RigidBody3D

signal request_control(vehicle)
signal request_release_control(vehicle)

@export var hover_height: float = 2.5
@export var hover_force: float = 80000.0
@export var hover_damp: float = 4000.0
@export var ray_length: float = 10.0
@export var base_linear_damp: float = 20.0
@export var base_angular_damp: float = 15000.0
@export var move_force: float = 12000.0
@export var thrust_acceleration: float = 5000.0
@export var rotation_speed: float = 8.0
@export var max_tilt_angle: float = 15.0
@export var seat_socket_path: NodePath = "SeatSocket"

var raycasts: Array[RayCast3D] = []
var is_controlled: bool = false
var seat_socket: Node3D
var current_thrust: float = 0.0
var target_thrust: float = 0.0

func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("interactive")

	linear_damp = base_linear_damp
	angular_damp = base_angular_damp
	center_of_mass = Vector3(0, -2.0, 0)
	mass = 1000.0
	continuous_cd = true

	seat_socket = get_node_or_null(seat_socket_path)
	if not seat_socket:
		push_error("Vehicle.gd: Seat socket introuvable au chemin " + str(seat_socket_path))

	_collect_raycasts(self)
	for rc in raycasts:
		rc.enabled = true
		rc.target_position = Vector3(0, -ray_length, 0)
		rc.exclude_parent = true
		rc.collide_with_bodies = true
		rc.collide_with_areas = false

func _collect_raycasts(node: Node) -> void:
	for child in node.get_children():
		if child is RayCast3D:
			raycasts.append(child)
		_collect_raycasts(child)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_controlled:
		return

	for rc in raycasts:
		rc.force_raycast_update()
		if rc.is_colliding():
			var A = rc.global_transform.origin
			var B = rc.get_collision_point()
			var d = A - B
			var D = d.length()
			var u = d.normalized()
			var CM = state.transform.origin
			var offset = A - CM
			var velocity_at_A = state.linear_velocity + state.angular_velocity.cross(offset)
			var v_rel = velocity_at_A.dot(u)

			var force = (hover_force * (hover_height - D) - hover_damp * v_rel) * u
			state.apply_force(force, offset)

	var up_dir = global_transform.basis.y.normalized()
	var correction = Vector3.UP.cross(up_dir).normalized()
	var correction_magnitude = acos(clamp(up_dir.dot(Vector3.UP), -1.0, 1.0))
	if correction_magnitude > deg_to_rad(max_tilt_angle):
		state.apply_torque(correction * correction_magnitude * 50000.0)

	var forward_input = Input.get_action_strength("MoveForward") - Input.get_action_strength("MoveBackward")
	var steer_input = Input.get_action_strength("MoveRight") - Input.get_action_strength("MoveLeft")

	target_thrust = abs(forward_input) * move_force
	current_thrust = move_toward(current_thrust, target_thrust, thrust_acceleration * state.step)

	if steer_input != 0.0:
		state.apply_torque(Vector3.UP * steer_input * rotation_speed * mass)

	if current_thrust > 0.1:
		var forward_dir = -global_transform.basis.z * sign(forward_input)
		state.apply_central_force(forward_dir * current_thrust)

	linear_damp = base_linear_damp + state.linear_velocity.length() * 0.5
	angular_damp = base_angular_damp + state.angular_velocity.length()

func interact(player: Node) -> void:
	if is_controlled or not seat_socket or not player.has_method("set_active"):
		return
	emit_signal("request_control", self)

func _unhandled_input(event: InputEvent) -> void:
	if is_controlled and event.is_action_pressed("Interact"):
		emit_signal("request_release_control", self)
