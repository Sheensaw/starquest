# Player.gd
extends CharacterBody3D

@export var speed: float = 5.0
@export var rotation_speed: float = 10.0
@export var gravity: float = 20.0  # Force gravitationnelle appliquée

var is_active: bool = true
var is_strafing: bool = false
var strafe_timer: Timer
var nearby_interactable: Node3D = null
var vertical_velocity: float = 0.0

func _ready() -> void:
	add_to_group("player")

	# Timer de strafing
	strafe_timer = Timer.new()
	strafe_timer.one_shot = true
	strafe_timer.wait_time = 0.2
	strafe_timer.timeout.connect(_on_strafe_timer_timeout)
	add_child(strafe_timer)

	# Connexion à la zone d'interaction
	var interaction_area = $InteractionArea
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	else:
		push_error("Player.gd : InteractionArea introuvable")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("vehicles"):
		nearby_interactable = body
	elif body.has_method("interact"):
		nearby_interactable = body

func _on_body_exited(body: Node) -> void:
	if body == nearby_interactable:
		nearby_interactable = null

func _unhandled_input(event: InputEvent) -> void:
	# Interaction / possession
	if event.is_action_pressed("Interact") and is_active and nearby_interactable:
		if nearby_interactable.is_in_group("vehicles"):
			nearby_interactable.emit_signal("request_control", nearby_interactable)
		elif nearby_interactable.has_method("interact"):
			nearby_interactable.call("interact")

func _input(event: InputEvent) -> void:
	# Gestion du strafe via le bouton Shoot
	if event.is_action_pressed("Shoot") and is_active:
		is_strafing = true
		strafe_timer.stop()
	elif event.is_action_released("Shoot") and is_active:
		strafe_timer.start()

func _physics_process(delta: float) -> void:
	if not is_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Gravité
	if not is_on_floor():
		vertical_velocity -= gravity * delta
	else:
		vertical_velocity = 0.0

	# Mouvement horizontal
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	var move_input = input_dir.normalized()
	var horizontal_velocity = Vector3.ZERO

	if move_input != Vector2.ZERO:
		var dir = Vector3(move_input.x, 0, move_input.y)
		if not is_strafing:
			var target_basis = Basis().looking_at(dir, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
			horizontal_velocity = dir * speed
		else:
			# Strafing : conserve l'orientation et déplace latéralement
			var local_vel = Vector3(move_input.x * speed, 0, move_input.y * speed)
			horizontal_velocity = global_transform.basis * local_vel

	velocity = horizontal_velocity
	velocity.y = vertical_velocity

	move_and_slide()

func _on_strafe_timer_timeout() -> void:
	is_strafing = false
