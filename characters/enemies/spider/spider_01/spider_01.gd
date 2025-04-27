extends Enemy
class_name SpiderEnemy
#────────────────────────────────────────────────────────────
#  PARAMÈTRES
#────────────────────────────────────────────────────────────
@export var melee_attack_range    : float = 5.0
@export var melee_attack_cooldown : float = 1.5
@export var move_speed            : float = 3.0
@export var attack_anim_duration  : float = 0.60
@export var death_delay           : float = 0.5    # délai avant queue_free
#────────────────────────────────────────────────────────────
#  RÉFÉRENCES
#────────────────────────────────────────────────────────────
@onready var animation_tree : AnimationTree = $AnimationTree
var state_machine : AnimationNodeStateMachinePlayback
#────────────────────────────────────────────────────────────
#  ÉTATS
#────────────────────────────────────────────────────────────
var attack_anim_timer  : float = 0.0
var attack_in_progress : bool  = false
var dying              : bool  = false
#────────────────────────────────────────────────────────────
func _ready() -> void:
	super._ready()
	
	# stats de base
	attack_range    = melee_attack_range
	attack_cooldown = melee_attack_cooldown
	attack_damage   = 15.0
	rotation_speed  = 10.0
	vision_radius   = 10.0
	vision_angle    = 90.0
	
	assert(animation_tree, "AnimationTree manquant.")
	animation_tree.active = true                      # doit être actif avant get()
	state_machine = animation_tree.get("parameters/playback")
	assert(state_machine, "Playback non trouvé.")
	
	state_machine.start("Spawn")
	if canvas_layer: canvas_layer.hide()
	randomize()
#────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dying:                                         # plus aucune logique si mort
		move_and_slide()
		return
	
	# étourdissement
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			die()
		_update_health_ui_if_needed()
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# timers
	if attack_timer > 0.0:
		attack_timer -= delta
	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0.0:
			attack_in_progress = false
	
	# cible
	if not target or not is_instance_valid(target):
		target = get_closest_target()
	if not target:
		velocity = Vector3.ZERO
		_update_animation_state()
		move_and_slide()
		return
	
	_update_health_ui_if_needed()
	
	# orientation
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	var dist: float = global_position.distance_to(target.global_position)
	
	# combat / déplacement
	if dist <= attack_range and attack_timer <= 0.0 and not attack_in_progress:
		_start_attack()
	elif not attack_in_progress:
		_move_toward_target()
	else:
		velocity = Vector3.ZERO
	
	_update_animation_state()
	move_and_slide()
#────────────────────────────────────────────────────────────
#  MOUVEMENT
#────────────────────────────────────────────────────────────
func _move_toward_target() -> void:
	var dir: Vector3 = (target.global_position - global_position).normalized()
	velocity = dir * move_speed
#────────────────────────────────────────────────────────────
#  ATTAQUE
#────────────────────────────────────────────────────────────
func _start_attack() -> void:
	attack_in_progress = true
	attack_anim_timer  = attack_anim_duration
	attack_timer       = attack_cooldown
	
	animation_tree.set("parameters/Attack/attack_index", randi() % 4)
	state_machine.travel("Attack")
	
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)
#────────────────────────────────────────────────────────────
#  ANIMATION STATE
#────────────────────────────────────────────────────────────
func _update_animation_state() -> void:
	var current: StringName = state_machine.get_current_node()
	if current in ["Spawn", "Death"]:
		return
	
	if attack_in_progress:
		if current != "Attack":
			state_machine.travel("Attack")
		return
	
	if velocity.length() > 0.05:
		var local_v: Vector3 = global_transform.basis.inverse() * velocity.normalized()
		animation_tree.set("parameters/Walk/blend_position", Vector2(local_v.x, -local_v.z))
		if current != "Walk":
			state_machine.travel("Walk")
	else:
		if current != "Idle":
			state_machine.travel("Idle")
#────────────────────────────────────────────────────────────
#  UI SANTÉ
#────────────────────────────────────────────────────────────
func _update_health_ui_if_needed() -> void:
	if show_health:
		health_display_timer -= get_physics_process_delta_time()
		if health_display_timer <= 0.0:
			show_health = false
			if canvas_layer: canvas_layer.hide()
	if show_health and not is_stunned:
		update_health_ui()
		update_ui_position()
#────────────────────────────────────────────────────────────
#  MORT
#────────────────────────────────────────────────────────────
func die() -> void:
	if dying:
		return
	dying = true
	
	# retirer des groupes pour qu’il ne soit plus détectable
	for g in ["aimables", "enemies"]:
		if is_in_group(g):
			remove_from_group(g)
	
	# désactiver collisions
	for shape in get_tree().get_nodes_in_group("collision_shapes"):
		if shape.is_ancestor_of(self) or self.is_ancestor_of(shape):
			shape.disabled = true
	collision_layer = 0
	collision_mask  = 0
	
	animation_tree.set("parameters/Death/death_index", randi() % 2)
	state_machine.travel("Death")
	
	await get_tree().create_timer(death_delay).timeout
	queue_free()
