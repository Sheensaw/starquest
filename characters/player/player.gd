# Player.gd
# Gère le mouvement, le strafing et l'interaction
extends CharacterBody3D

@export var speed: float = 5.0                  # Vitesse de déplacement
@export var rotation_speed: float = 10.0        # Vitesse de rotation quand non-strafing
@export var gravity: float = 20.0               # Intensité de la gravité

var is_active: bool = true                      # Le joueur peut-il agir ?
var is_strafing: bool = false                   # En mode strafe ?
var nearby_interactable: Node3D = null          # Objet interactif à portée
var vertical_velocity: float = 0.0              # Composante Y de la vélocité

@onready var strafe_timer: Timer = Timer.new()

func _ready() -> void:
	add_to_group("player")

	# Timer pour la durée du strafing
	strafe_timer.one_shot = true
	strafe_timer.wait_time = 0.2
	strafe_timer.connect("timeout", Callable(self, "_on_strafe_timer_timeout"))
	add_child(strafe_timer)

	# Connexion aux signaux de l'aire d'interaction
	var interaction_area = $InteractionArea
	if interaction_area:
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
		interaction_area.connect("body_exited", Callable(self, "_on_body_exited"))
	else:
		push_error("Player.gd : InteractionArea introuvable")

func _on_body_entered(body: Node) -> void:
	if body.has_method("interact"):
		nearby_interactable = body as Node3D

func _on_body_exited(body: Node) -> void:
	if body == nearby_interactable:
		nearby_interactable = null

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("Interact") and nearby_interactable:
		nearby_interactable.interact(self)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("Shoot"):
		is_strafing = true
		strafe_timer.stop()
	elif event.is_action_released("Shoot"):
		strafe_timer.start()

func _physics_process(delta: float) -> void:
	if not is_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Applique la gravité
	if not is_on_floor():
		vertical_velocity -= gravity * delta
	else:
		vertical_velocity = 0.0

	# Récupère l’input W/A/S/D et normalise
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward").normalized()
	var horizontal_velocity = Vector3.ZERO

	if input_dir != Vector2.ZERO:
		# Même vecteur world-space que hors strafe
		var world_dir = Vector3(input_dir.x, 0, input_dir.y)

		if not is_strafing:
			# Rotation et déplacement avant
			var target_basis = Basis().looking_at(world_dir, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)

		# Dans tous les cas, on avance selon world_dir
		horizontal_velocity = world_dir * speed

	# Compose la vélocité et déplace
	velocity = horizontal_velocity
	velocity.y = vertical_velocity
	move_and_slide()  # Utilisation sans arguments en Godot 4 :contentReference[oaicite:2]{index=2}

func _on_strafe_timer_timeout() -> void:
	is_strafing = false
