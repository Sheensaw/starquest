extends Control

@export var radius: float = 100.0       # Maximum radius for knob movement
@export var dead_zone: float = 10.0     # Dead zone radius (pixels) for micro-movements
@export var dynamic_radius: float = 200.0  # Max distance from default center for dynamic positioning
var _touch_id: int = -1                 # Active touch index (-1 = none)
var direction: Vector2 = Vector2.ZERO   # Normalized output direction [-1,1]
var _center: Vector2                    # Local center of the joystick
var _default_center: Vector2            # Default center when not active

@onready var bg: TextureRect = $JoyBg
@onready var knob: TextureRect = $JoyKnob

func _ready() -> void:
	# Initialize joystick appearance and center
	modulate.a = 0.5            # Semi-transparent when idle
	knob.hide()                 # Hide knob until interaction
	_default_center = size * 0.5  # Default center based on control size
	_center = _default_center     # Initialize center
	bg.position = _center - bg.size / 2  # Center background initially

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id < 0:
			# Calculate local position from global touch position
			var local_pos = event.position - global_position
			# Restrict dynamic positioning to within dynamic_radius of default center
			if local_pos.distance_to(_default_center) <= dynamic_radius:
				_touch_id = event.index
				_center = local_pos  # Move joystick center to touch point
				direction = Vector2.ZERO
				# Center the knob and background at the new center
				knob.position = _center - knob.size / 2
				bg.position = _center - bg.size / 2
				knob.show()
				_tween_opacity(1.0)    # Smoothly transition to fully opaque
		elif not event.pressed and event.index == _touch_id:
			_reset()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		# Calculate local position from global drag position
		var local_pos = event.position - global_position
		var delta = local_pos - _center
		# Clamp delta within the radius
		if delta.length() > radius:
			delta = delta.normalized() * radius
		# Apply dead zone
		if delta.length() < dead_zone:
			delta = Vector2.ZERO
			direction = Vector2.ZERO
		else:
			# Scale direction to account for dead zone
			direction = (delta - delta.normalized() * dead_zone) / (radius - dead_zone)
			direction = direction.clamp(Vector2(-1, -1), Vector2(1, 1))
		# Position knob's center at _center + delta
		knob.position = _center + delta - knob.size / 2

func _reset() -> void:
	_touch_id = -1
	direction = Vector2.ZERO
	knob.hide()
	_tween_opacity(0.5)    # Smoothly transition to semi-transparent
	# Reset to default center
	_center = _default_center
	knob.position = _center - knob.size / 2
	bg.position = _center - bg.size / 2

func _tween_opacity(target: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", target, 0.2).set_ease(Tween.EASE_IN_OUT)
