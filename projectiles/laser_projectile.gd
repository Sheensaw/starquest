extends Area3D

# Variables exportées
@export var speed: float = 60.0
@export var min_damage: float = 10.0
@export var max_damage: float = 20.0
@export var points_per_hit: int = 5
@export var shoot_sound: AudioStream = preload("res://audio/sfx/laser_shoot.wav")
@export var vertical_homing_lerp: float = 0.25
@export_range(1, 5, 1) var sub_steps: int = 2

# Variables runtime
var direction: Vector3 = Vector3.FORWARD
var damage: float
var lifetime: float = 5.0
var time_alive: float = 0.0
var initial_position: Vector3
var audio_player: AudioStreamPlayer3D
var target_ref: Node3D = null

func _ready() -> void:
	damage = randf_range(min_damage, max_damage)
	initial_position = global_position
	add_to_group("player_projectiles")
	connect("body_entered", Callable(self, "_on_body_entered"))
	audio_player = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
	audio_player.stream = shoot_sound
	audio_player.play()

func _physics_process(delta: float) -> void:
	var step: float = delta / sub_steps
	for _i in range(sub_steps):
		_home_vertical(step)
		_move(step)
		if _check_lifetime():
			return

func _home_vertical(dt: float) -> void:
	if target_ref and is_instance_valid(target_ref):
		var off: Vector3 = target_ref.global_position - global_position
		var dist_xz: float = max(0.001, sqrt(off.x * off.x + off.z * off.z))
		var desired_y: float = clamp(off.y / dist_xz, -1.0, 1.0)
		direction.y = lerp(direction.y, desired_y, vertical_homing_lerp)
		direction = direction.normalized()

func _move(dt: float) -> void:
	global_position += direction * speed * dt
	rotation.x = -asin(direction.y)

func _check_lifetime() -> bool:
	time_alive += get_physics_process_delta_time() / sub_steps
	if time_alive > lifetime or global_position.distance_to(initial_position) > 100.0:
		queue_free()
		return true
	return false

func _on_body_entered(body: Node) -> void:
	if not body is PhysicsBody3D or not body.is_in_group("enemies"):
		return
	if body.has_method("is_stunned") and body.has_method("is_dead"):
		if body.is_stunned() or body.is_dead():
			return
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_method("add_score"):
			players[0].add_score(points_per_hit)
	audio_player.get_parent().remove_child(audio_player)
	get_tree().root.add_child(audio_player)
	audio_player.global_transform = global_transform
	audio_player.play()
	var audio_timer = Timer.new()
	audio_timer.wait_time = audio_player.stream.get_length() + 0.1
	audio_timer.one_shot = true
	get_tree().root.add_child(audio_timer)
	audio_timer.connect("timeout", Callable(audio_player, "queue_free"))
	audio_timer.start()
	queue_free()
