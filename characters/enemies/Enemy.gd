extends CharacterBody3D
class_name Enemy
#────────────────────────────────────────────────────────────
#  Paramètres exposés
#────────────────────────────────────────────────────────────
@export var max_health       : float = 100.0
@export var attack_range     : float = 2.0
@export var attack_damage    : float = 10.0
@export var attack_cooldown  : float = 1.0
@export var stun_chance      : float = 0.5
@export var stun_duration_max: float = 3.0
@export var health_recovery_amount: float = 20.0
@export var vision_radius    : float = 15.0
@export var vision_angle     : float = 90.0          # degrés
@export var rotation_speed   : float = 5.0
#────────────────────────────────────────────────────────────
#  Variables runtime
#────────────────────────────────────────────────────────────
var current_health : float
var target         : Node3D = null
var attack_timer   : float = 0.0

var is_stunned     : bool  = false
var stun_duration  : float = 0.0
# UI temporisation
var show_health            : bool = false
var health_display_timer   : float = 0.0
const HEALTH_DISPLAY_DURATION : float = 0.2
#────────────────────────────────────────────────────────────
#  Références de nœuds
#────────────────────────────────────────────────────────────
@onready var canvas_layer : CanvasLayer   = $CanvasLayer
@onready var health_label : Label         = $CanvasLayer/HealthLabel
@onready var takedown_area: Area3D        = $TakedownArea
#────────────────────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("aimables")
	if canvas_layer: canvas_layer.hide()
	if takedown_area: takedown_area.monitoring = false
#────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			die()
		_update_health_ui(delta)
		return
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if not target:
		target = get_closest_target()
	
	_update_health_ui(delta)
#────────────────────────────────────────────────────────────
func get_closest_target() -> Node3D:
	var fwd      : Vector3 = -global_transform.basis.z.normalized()
	var cos_max  : float   = cos(deg_to_rad(vision_angle))
	var best_dist: float   = vision_radius
	var nearest  : Node3D  = null
	
	for p in get_tree().get_nodes_in_group("player"):
		if !(p is Node3D) or not is_instance_valid(p):
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist >= best_dist:
			continue
		var dir: Vector3 = (p.global_position - global_position).normalized()
		if fwd.dot(dir) >= cos_max:
			nearest   = p
			best_dist = dist
	return nearest
#────────────────────────────────────────────────────────────
func take_damage(dmg: float, source: Node = null) -> void:
	if is_stunned:
		return
	if source and not source.is_in_group("player_projectiles"):
		return
	
	current_health = max(current_health - dmg, 0)
	show_health = true
	health_display_timer = HEALTH_DISPLAY_DURATION
	if health_label:
		health_label.text = str(int(current_health))
	
	if current_health <= 0:
		if randf() < stun_chance:
			is_stunned   = true
			current_health = 1.0
			stun_duration  = stun_duration_max
			if takedown_area:
				takedown_area.monitoring = true
		else:
			die()
#────────────────────────────────────────────────────────────
func _update_health_ui(delta: float) -> void:
	if show_health:
		health_display_timer -= delta
		if health_display_timer <= 0.0:
			show_health = false
			if canvas_layer:
				canvas_layer.hide()
	if show_health and not canvas_layer.is_visible():
		canvas_layer.show()
		var cam := get_viewport().get_camera_3d()
		if cam:
			var pos2d : Vector2 = cam.unproject_position(global_position + Vector3(0, 2.5, 0))
			health_label.position = pos2d - health_label.size * 0.5
#────────────────────────────────────────────────────────────
func perform_takedown(by: Node) -> void:
	if not is_stunned:
		return
	if by and by.has_method("recover_health"):
		by.recover_health(health_recovery_amount)
	die()
#────────────────────────────────────────────────────────────
func die() -> void:
	if takedown_area:
		takedown_area.monitoring = false
	queue_free()
