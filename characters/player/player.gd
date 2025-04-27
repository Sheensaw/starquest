extends CharacterBody3D

#────────────────────────────────────────────────────────────
#  PARAMÈTRES EXPOSÉS
#────────────────────────────────────────────────────────────
@export var base_speed        : float = 7.0
@export var strafe_speed      : float = 5.0
@export var gravity           : float = 9.8
@export var rotation_speed    : float = 10.0         # rad/s
@export var detection_radius  : float = 20.0
@export var cone_angle        : float = 45.0         # °
@export var max_health        : float = 100.0
@export var detectable_groups : PackedStringArray = ["aimables", "enemies"]

#────────────────────────────────────────────────────────────
#  CONSTANTES D’INPUT
#────────────────────────────────────────────────────────────
const INPUT_LEFT   = "MoveLeft"
const INPUT_RIGHT  = "MoveRight"
const INPUT_TOP    = "MoveTop"
const INPUT_DOWN   = "MoveDown"
const INPUT_SHOOT  = "Shoot"

const STRAFE_LEFT  = "StrafeLeft"
const STRAFE_RIGHT = "StrafeRight"
const STRAFE_TOP   = "StrafeTop"
const STRAFE_DOWN  = "StrafeDown"

const STRAFE_EXIT_DELAY : float = 0.1
const SHOOT_INTERVAL    : float = 0.1

#────────────────────────────────────────────────────────────
#  VARIABLES RUNTIME
#────────────────────────────────────────────────────────────
var locked_yaw      : float = 0.0
var target_yaw      : float = 0.0
var locked_target   : Node3D = null
var strafing        : bool = false
var was_shooting    : bool = false
var strafe_exit_timer : float = 0.0

var current_health  : float
var score           : int = 0

var can_shoot   : bool  = true
var shoot_timer : float = 0.0
var projectile_scene = preload("res://projectiles/laser_projectile.tscn")

#────────────────────────────────────────────────────────────
#  RÉFÉRENCES SCÈNE
#────────────────────────────────────────────────────────────
@onready var animation_tree    : AnimationTree = $AnimationTree
@onready var projectile_origin : Node3D        = $ProjectileLocation

@onready var hud          : CanvasLayer = $PlayerHUD
@onready var health_bar   = $PlayerHUD/Healthbar
@onready var health_label = $PlayerHUD/HealthLabel
@onready var score_label  = $PlayerHUD/ScoreLabel
@onready var score_value  = $PlayerHUD/ScoreValue

#────────────────────────────────────────────────────────────
#  READY
#────────────────────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	if health_bar and health_label:
		health_bar.max_value = max_health
		health_bar.value     = current_health
		health_label.text    = str(int(current_health))
	if score_label and score_value:
		score_label.text = "Score:"
		score_value.text = str(score)

#────────────────────────────────────────────────────────────
#  PHYSICS PROCESS
#────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	var shoot_pressed: bool = Input.is_action_pressed(INPUT_SHOOT)
	var detected: Node3D = get_detected_target()
	
	# ── Gestion strafe / lock
	if shoot_pressed:
		strafing = true
		if detected:
			locked_target = detected
	else:
		strafing      = false
		locked_target = null
	
	# ── Délai sortie strafe
	if shoot_pressed:
		strafe_exit_timer = 0.0
	else:
		strafe_exit_timer += delta
		if strafe_exit_timer >= STRAFE_EXIT_DELAY:
			strafing      = false
			locked_target = null
	
	if locked_target and not is_instance_valid(locked_target):
		locked_target = null
	
	# ── Mouvement et rotation
	var speed: float = strafe_speed if strafing else base_speed
	var in2d: Vector2 = Input.get_vector(
		STRAFE_LEFT  if strafing else INPUT_LEFT,
		STRAFE_RIGHT if strafing else INPUT_RIGHT,
		STRAFE_TOP   if strafing else INPUT_TOP,
		STRAFE_DOWN  if strafing else INPUT_DOWN)
	if in2d.length_squared() > 0.0:
		in2d = in2d.normalized()
	var input_dir: Vector3 = Vector3(in2d.x, 0, in2d.y)
	
	var rot_spd: float = (100.0 if (strafing and locked_target) else rotation_speed)
	
	if locked_target:
		var to: Vector3 = (locked_target.global_position - global_position).normalized()
		locked_yaw = atan2(to.x, to.z) + PI
		rotation.y = lerp_angle(rotation.y, locked_yaw, rot_spd * delta)
	elif strafing:
		if not was_shooting:
			locked_yaw = rotation.y
		rotation.y = locked_yaw
	else:
		if input_dir.length_squared() > 0.0:
			target_yaw = atan2(input_dir.x, input_dir.z) + PI
			rotation.y = lerp_angle(rotation.y, target_yaw, rot_spd * delta)
	
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	
	# ── Tir
	if shoot_pressed and can_shoot:
		shoot_projectile()
		can_shoot   = false
		shoot_timer = 0.0
	if not can_shoot:
		shoot_timer += delta
		if shoot_timer >= SHOOT_INTERVAL:
			can_shoot = true
	
	update_animations(strafing)
	was_shooting = shoot_pressed

#────────────────────────────────────────────────────────────
#  SHOOT PROJECTILE – look_at vers la cible
#────────────────────────────────────────────────────────────
func shoot_projectile() -> void:
	var p := projectile_scene.instantiate()
	get_tree().root.add_child(p)
	p.global_transform = projectile_origin.global_transform
	
	var final_dir: Vector3 = -global_transform.basis.z.normalized()
	if locked_target and is_instance_valid(locked_target):
		final_dir = (locked_target.global_position - projectile_origin.global_position).normalized()
		p.target_ref = locked_target
	
	p.direction = final_dir
	p.look_at(p.global_transform.origin + final_dir, Vector3.UP)

#────────────────────────────────────────────────────────────
#  ANIMATIONS
#────────────────────────────────────────────────────────────
func update_animations(strafe: bool) -> void:
	var local_v: Vector3 = global_transform.basis.inverse() * velocity
	var blend: Vector2 = Vector2(local_v.x, local_v.z).normalized() if velocity.length_squared() > 0 else Vector2.ZERO
	if strafe:
		animation_tree.set("parameters/Strafe/blend_position", blend)
	else:
		animation_tree.set("parameters/Normal/blend_position", velocity.length() / base_speed)

#────────────────────────────────────────────────────────────
#  DÉTECTION DANS LE CÔNE
#────────────────────────────────────────────────────────────
func get_detected_target() -> Node3D:
	if locked_target and is_instance_valid(locked_target) and _is_in_cone(locked_target):
		return locked_target
	
	var fwd: Vector3 = -global_transform.basis.z.normalized()
	var cos_max: float = cos(deg_to_rad(cone_angle))
	var nearest: Node3D = null
	var best_dist: float = detection_radius
	
	for grp in detectable_groups:
		for ent in get_tree().get_nodes_in_group(grp):
			if not (ent is Node3D) or not is_instance_valid(ent):
				continue
			var dist: float = global_position.distance_to(ent.global_position)
			if dist > detection_radius or dist >= best_dist:
				continue
			var dir: Vector3 = (ent.global_position - global_position).normalized()
			if fwd.dot(dir) >= cos_max:
				nearest   = ent
				best_dist = dist
	return nearest

func _is_in_cone(ent: Node3D) -> bool:
	var fwd: Vector3 = -global_transform.basis.z.normalized()
	var dir: Vector3 = (ent.global_position - global_position).normalized()
	return fwd.dot(dir) >= cos(deg_to_rad(cone_angle))
