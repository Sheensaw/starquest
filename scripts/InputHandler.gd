extends Node

signal move_direction_changed(direction: Vector2)
signal shoot_pressed()
signal shoot_released()

@onready var joystick: Control = $PlayerHUD/VirtualJoystick
@onready var shoot_button: Button = $PlayerHUD/ShootButton

func _ready() -> void:
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_pressed)
		shoot_button.released.connect(_on_shoot_released)

func _process(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	if joystick and joystick.direction != Vector2.ZERO:
		direction = joystick.direction
	else:
		direction = Input.get_vector("MoveLeft", "MoveRight", "MoveTop", "MoveDown")
	emit_signal("move_direction_changed", direction)

	if Input.is_action_just_pressed("Shoot"):
		emit_signal("shoot_pressed")
	if Input.is_action_just_released("Shoot"):
		emit_signal("shoot_released")

func _on_shoot_pressed() -> void:
	emit_signal("shoot_pressed")

func _on_shoot_released() -> void:
	emit_signal("shoot_released")
