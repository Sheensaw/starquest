extends CharacterBody3D

#────────────────────────────────────────────────────────────
#  PARAMÈTRES EXPOSÉS
#────────────────────────────────────────────────────────────
@export var base_speed        : float = 7.0
@export var strafe_speed      : float = 5.0
@export var gravity           : float = 9.8
@export var rotation_speed    : float = 10.0      # rad/s
@export var detection_radius  : float = 20.0
@export var cone_angle        : float = 45.0      # °
@export var max_health        : float = 100.0
@export var fire_rate         : float = 0.1       # s (intervalle entre tirs)
@export var detectable_groups : PackedStringArray = ["aimables", "enemies"]

#────────────────────────────────────────────────────────────
#  INPUT (ACTIONS)
#────────────────────────────────────────────────────────────
const INPUT_LEFT      = "MoveLeft"
const INPUT_RIGHT     = "MoveRight"
const INPUT_TOP       = "MoveTop"
const INPUT_DOWN      = "MoveDown"
const INPUT_SHOOT     = "Shoot"

const STRAFE_LEFT     = "StrafeLeft"
const STRAFE_RIGHT    = "StrafeRight"
const STRAFE_TOP      = "StrafeTop"
const STRAFE_DOWN     = "StrafeDown"

const STRAFE_EXIT_DELAY : float = 0.1   # s

#────────────────────────────────────────────────────────────
#  RÉFÉRENCES DE SCÈNE & CONTROLES UI
#────────────────────────────────────────────────────────────
@onready var animation_tree     : AnimationTree = $AnimationTree
@onready var projectile_origin  : Node3D        = $ProjectileLocation
@onready var hud                : CanvasLayer   = $PlayerHUD
@onready var health_bar         = $PlayerHUD/Healthbar
@onready var health_label       = $PlayerHUD/HealthLabel
@onready var score_label        = $PlayerHUD/ScoreLabel
@onready var score_value        = $PlayerHUD/ScoreValue

# Virtual joystick contrôlé par VirtualJoystick.gd
@onready var joystick           : Control       = $PlayerHUD/VirtualJoystick
# Bouton de tir (optionnel)
@onready var shoot_button_node  = $PlayerHUD/ShootButton

#────────────────────────────────────────────────────────────
#  VARIABLES RUNTIME
#────────────────────────────────────────────────────────────
var locked_yaw       : float = 0.0
var strafing         : bool  = false
var was_shooting     : bool  = false
var strafe_exit_timer: float = 0.0

var locked_target : Node3D = null
var current_health: float
var score         : int   = 0

var can_shoot   : bool  = true
var shoot_timer : float = 0.0
var projectile_scene = preload("res://projectiles/laser_projectile.tscn")

#────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	# Initialisation vie et score
	current_health = max_health
	if health_bar and health_label:
		health_bar.max_value = max_health
		health_bar.value     = current_health
		health_label.text    = str(int(current_health))
	if score_label and score_value:
		score_label.text = "Score:"
		score_value.text = str(score)

	# Connexion du bouton de tir si présent
	if shoot_button_node and shoot_button_node is Button:
		shoot_button_node.pressed.connect(Callable(self, "_on_ShootButton_pressed"))
		shoot_button_node.released.connect(Callable(self, "_on_ShootButton_released"))

#────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Entrée de tir
	var shoot_pressed = Input.is_action_pressed(INPUT_SHOOT)
	var detected = get_detected_target()

	# Strafe / lock
	if shoot_pressed:
		strafing = true
		if detected and not _is_invalid_enemy(detected):
			locked_target = detected
	else:
		strafing = false
		locked_target = null

	# Délai de sortie du strafe
	if not shoot_pressed:
		strafe_exit_timer += delta
		if strafe_exit_timer >= STRAFE_EXIT_DELAY:
			strafing = false
			locked_target = null
	else:
		strafe_exit_timer = 0.0

	# Détermination du vecteur d'entrée
	var input_vec2: Vector2
	if joystick.direction != Vector2.ZERO:
		input_vec2 = joystick.direction
	else:
		input_vec2 = Input.get_vector(
			STRAFE_LEFT if strafing else INPUT_LEFT,
			STRAFE_RIGHT if strafing else INPUT_RIGHT,
			STRAFE_TOP if strafing else INPUT_TOP,
			STRAFE_DOWN if strafing else INPUT_DOWN
		)
	if input_vec2.length_squared() > 1.0:
		input_vec2 = input_vec2.normalized()

	# Calcul de la vitesse et direction 3D
	var move_speed = strafe_speed if strafing else base_speed
	var dir3 = Vector3(input_vec2.x, 0.0, input_vec2.y)

	# Rotation
	var rot_spd = 100.0 if strafing and locked_target else rotation_speed
	if locked_target:
		var target_dir = (locked_target.global_position - global_position).normalized()
		locked_yaw = atan2(target_dir.x, target_dir.z) + PI
		rotation.y = lerp_angle(rotation.y, locked_yaw, rot_spd * delta)
	elif strafing:
		if not was_shooting:
			locked_yaw = rotation.y
		rotation.y = locked_yaw
	else:
		if dir3.length_squared() > 0.0:
			var target_yaw = atan2(dir3.x, dir3.z) + PI
			rotation.y = lerp_angle(rotation.y, target_yaw, rot_spd * delta)

	# Mouvement & gravité
	velocity.x = dir3.x * move_speed
	velocity.z = dir3.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

	# Tir selon intervalle
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

#────────────────────────────────────────────────────────────
func _on_ShootButton_pressed() -> void:
	Input.action_press(INPUT_SHOOT)

func _on_ShootButton_released() -> void:
	Input.action_release(INPUT_SHOOT)

func _shoot_projectile() -> void:
	var p = projectile_scene.instantiate()
	get_tree().root.add_child(p)
	p.global_transform = projectile_origin.global_transform
	
	var dir = -global_transform.basis.z.normalized()
	if locked_target and is_instance_valid(locked_target):
		dir = (locked_target.global_position - projectile_origin.global_position).normalized()
		p.target_ref = locked_target
	p.direction = dir
	p.look_at(p.global_transform.origin + dir, Vector3.UP)
	p.add_to_group("player_projectiles")

func _update_animations(is_strafe: bool) -> void:
	var local_vel = global_transform.basis.inverse() * velocity
	var blend_vec = Vector2.ZERO
	if velocity.length_squared() > 0.0:
		blend_vec = Vector2(local_vel.x, local_vel.z).normalized()
	if is_strafe:
		animation_tree.set("parameters/Strafe/blend_position", blend_vec)
	else:
		animation_tree.set("parameters/Normal/blend_position", clamp(velocity.length() / base_speed, 0.0, 1.0))

func get_detected_target() -> Node3D:
	if locked_target and is_instance_valid(locked_target) and _is_in_cone(locked_target) and not _is_invalid_enemy(locked_target):
		return locked_target
	
	var fwd = -global_transform.basis.z.normalized()
	var best_dist = detection_radius
	var nearest: Node3D = null
	for grp in detectable_groups:
		for ent in get_tree().get_nodes_in_group(grp):
			if not (ent is Node3D) or not is_instance_valid(ent) or _is_invalid_enemy(ent):
				continue
			var dist = global_position.distance_to(ent.global_position)
			if dist < best_dist and fwd.dot((ent.global_position - global_position).normalized()) >= cos(deg_to_rad(cone_angle)):
				best_dist = dist
				nearest = ent
	return nearest

func _is_in_cone(ent: Node3D) -> bool:
	var fwd = -global_transform.basis.z.normalized()
	var dir = (ent.global_position - global_position).normalized()
	return fwd.dot(dir) >= cos(deg_to_rad(cone_angle))

func _is_invalid_enemy(ent: Node3D) -> bool:
	if ent.has_method("is_stunned") and ent.is_stunned():
		return true
	if ent.has_method("is_dead") and ent.is_dead():
		return true
	return false

func take_damage(dmg: float) -> void:
	current_health = clamp(current_health - dmg, 0.0, max_health)
	if health_bar and health_label:
		health_bar.value = current_health
		health_label.text = str(int(current_health))
	if current_health <= 0.0:
		queue_free()

func recover_health(amount: float) -> void:
	current_health = clamp(current_health + amount, 0.0, max_health)
	if health_bar and health_label:
		health_bar.value = current_health
		health_label.text = str(int(current_health))

func add_score(points: int) -> void:
	score += points
	if score_value:
		score_value.text = str(score)
