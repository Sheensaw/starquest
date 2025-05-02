extends CharacterBody3D

signal health_changed(health: float, max_health: float)
signal score_changed(score: int)

@export var base_speed: float = 7.0
@export var strafe_speed: float = 5.0
@export var gravity: float = 9.8
@export var rotation_speed: float = 10.0
@export var max_health: float = 100.0
@export var fire_rate: float = 0.1

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var projectile_origin: Node3D = $ProjectileLocation
@onready var targeting_system: Node = $TargetingSystem
@onready var projectile_pool: Node = get_node("../GlobalObjects/ProjectilePool")
@onready var input_handler: Node = $InputHandler

var locked_yaw: float = 0.0
var strafing: bool = false
var was_shooting: bool = false
var strafe_exit_timer: float = 0.0

var locked_target: Node3D = null
var current_health: float
var score: int = 0
var is_dead: bool = false

var can_shoot: bool = true
var shoot_timer: float = 0.0

var input_direction: Vector2 = Vector2.ZERO
var is_shooting: bool = false

var projectile_scene: PackedScene = preload("res://projectiles/laser_projectile.tscn")

func _ready() -> void:
	print("PlayerCharacter - InputHandler :", input_handler)
	add_to_group("player")
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	emit_signal("score_changed", score)

	if input_handler:
		print("Connexion des signaux de l’InputHandler")
		input_handler.move_direction_changed.connect(_on_move_direction_changed)
		input_handler.shoot_pressed.connect(_on_shoot_pressed)
		input_handler.shoot_released.connect(_on_shoot_released)
	else:
		print("ERREUR : InputHandler non trouvé ! Vérifiez la scène.")

func _on_move_direction_changed(direction: Vector2) -> void:
	print("PlayerCharacter - Direction reçue :", direction)
	input_direction = direction

func _on_shoot_pressed() -> void:
	is_shooting = true

func _on_shoot_released() -> void:
	is_shooting = false

func _physics_process(delta: float) -> void:
	print("PlayerCharacter - Direction d'entrée actuelle :", input_direction)
	var shoot_pressed = is_shooting
	var detected = targeting_system.get_detected_target()

	if detected and not targeting_system._is_invalid_enemy(detected):
		locked_target = detected
	else:
		locked_target = null

	strafing = shoot_pressed

	var input_vec2: Vector2 = input_direction
	var move_speed = strafe_speed if strafing else base_speed
	var dir3 = Vector3(input_vec2.x, 0.0, input_vec2.y)

	var rot_spd = 100.0 if strafing and locked_target else rotation_speed

	if shoot_pressed and locked_target:
		var target_dir = (locked_target.global_position - global_position).normalized()
		locked_yaw = atan2(target_dir.x, target_dir.z) + PI
		rotation.y = lerp_angle(rotation.y, locked_yaw, rot_spd * delta)
	elif not shoot_pressed and dir3.length_squared() > 0.0:
		var target_yaw = atan2(dir3.x, dir3.z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, rot_spd * delta)

	velocity.x = dir3.x * move_speed
	velocity.z = dir3.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

	if shoot_pressed and can_shoot:
		_shoot_projectile()
		can_shoot = false
		shoot_timer = 0.0
	if not can_shoot:
		shoot_timer += delta
		if shoot_timer >= fire_rate:
			can_shoot = true

	_update_animations(strafing)
	was_shooting = shoot_pressed

func _shoot_projectile() -> void:
	var laser = projectile_scene.instantiate()
	laser.global_transform = projectile_origin.global_transform
	if locked_target and is_instance_valid(locked_target):
		laser.direction = (locked_target.global_position - projectile_origin.global_position).normalized()
		laser.initialize(true, locked_target)
	else:
		laser.direction = -global_transform.basis.z.normalized()
		laser.initialize(true, null)
	get_tree().root.add_child(laser)

func _update_animations(is_strafe: bool) -> void:
	var local_vel = global_transform.basis.inverse() * velocity
	var blend_vec = Vector2.ZERO
	if velocity.length_squared() > 0.0:
		blend_vec = Vector2(local_vel.x, local_vel.z).normalized()
	if is_strafe:
		animation_tree.set("parameters/Strafe/blend_position", blend_vec)
	else:
		animation_tree.set("parameters/Normal/blend_position", clamp(velocity.length() / base_speed, 0.0, 1.0))

func take_damage(dmg: float, source: Node) -> void:
	current_health = clamp(current_health - dmg, 0.0, max_health)
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		queue_free()

func recover_health(amount: float) -> void:
	current_health = clamp(current_health + amount, 0.0, max_health)
	emit_signal("health_changed", current_health, max_health)

func add_score(points: int) -> void:
	score += points
	emit_signal("score_changed", score)

func get_detected_target() -> Node3D:
	if locked_target and is_instance_valid(locked_target):
		return locked_target
	return null
