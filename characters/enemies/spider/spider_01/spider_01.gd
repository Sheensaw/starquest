extends CharacterBody3D
class_name SpiderEnemy

# --- Propriétés ---
@export var speed: float = 5.0
@export var attack_range: float = 2.0
@export var gravity: float = 9.8
@export var attack_cooldown: float = 1.0
@export var stun_duration: float = 2.0
@export var max_health: float = 50.0
@export var rotation_lerp_speed: float = 5.0
@export var stun_probability: float = 0.5
@export var impact_scale_factor: float = 1.5
@export var impact_animation_duration: float = 0.2
@export var hit_duration: float = 0.2
@export var hit_flash_speed: float = 20.0  # Vitesse de clignotement rouge (impact)
@export var stun_flash_speed: float = 5.0  # Vitesse de clignotement blanc (stun)

# --- Références ---
@onready var player          = get_tree().get_first_node_in_group("player")
@onready var anim_tree       = $AnimationTree
@onready var anim_state      = anim_tree.get("parameters/playback")
@onready var collision_shape = $CollisionShape3D
@onready var health_label    = $HealthLabel
@onready var ground_ray      = $GroundRay
@onready var animation_player = $AnimationPlayer
@onready var mesh_instance    = $model
@onready var takedown_sprite = $TakedownSprite

# --- États internes ---
var moving: bool       = false
var attacking: bool    = false
var dead: bool         = false
var stun: bool         = false
var spawned: bool      = false
var can_attack: bool   = true
var current_health: float
var blend_position: Vector2 = Vector2.ZERO
var current_normal: Vector3 = Vector3.UP
var takedown_performed: bool = false
var original_scale: Vector3
var hit_timer: float = 0.0
var stun_flash_timer: float = 0.0
var original_modulate: Color
var is_hit_active: bool = false
var is_stunned_active: bool = false
var attack_index: int = 0  # Pour BlendSpace1D (0 à 3)

# --- Timers ---
var attack_timer: Timer
var stun_timer: Timer
var health_label_timer: Timer
var impact_timer: Timer
var death_delay_timer: Timer

# --- Initialisation ---
func _ready():
	add_to_group("enemies")
	current_health = max_health

	anim_tree.active = true
	anim_tree.process_mode = AnimationTree.ANIMATION_PROCESS_PHYSICS

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.timeout.connect(self._on_attack_timer_timeout)

	stun_timer = Timer.new()
	stun_timer.wait_time = stun_duration
	stun_timer.one_shot = true
	add_child(stun_timer)
	stun_timer.timeout.connect(self._on_stun_timer_timeout)

	health_label_timer = Timer.new()
	health_label_timer.wait_time = 0.5
	health_label_timer.one_shot = true
	add_child(health_label_timer)
	health_label_timer.timeout.connect(self._on_health_label_timer_timeout)

	impact_timer = Timer.new()
	impact_timer.wait_time = impact_animation_duration
	impact_timer.one_shot = true
	add_child(impact_timer)
	impact_timer.timeout.connect(self._on_impact_timer_timeout)

	death_delay_timer = Timer.new()
	death_delay_timer.wait_time = 3.0
	death_delay_timer.one_shot = true
	add_child(death_delay_timer)
	death_delay_timer.timeout.connect(self._on_death_delay_timer_timeout)

	if health_label:
		original_scale = health_label.scale
		health_label.text = str(int(current_health))
		health_label.visible = false

	if takedown_sprite:
		takedown_sprite.visible = false
	else:
		print("TakedownSprite not found!")

	# Sauvegarder la couleur de base (modulate) du modèle
	if mesh_instance:
		original_modulate = mesh_instance.modulate
	else:
		print("MeshInstance $model not found!")

	spawned = true
	await get_tree().create_timer(1.0).timeout
	spawned = false
	print("Enemy spawned")

# --- Physique ---
func _physics_process(delta):
	if dead:
		velocity = Vector3.ZERO
		return

	# Mise à jour des timers pour le clignotement
	if hit_timer > 0:
		hit_timer -= delta
		is_hit_active = hit_timer > 0
	else:
		is_hit_active = false

	if stun:
		stun_flash_timer += delta
		is_stunned_active = true
	else:
		is_stunned_active = false
		stun_flash_timer = 0.0

	# Appliquer l'effet de clignotement via modulate
	if mesh_instance:
		if is_hit_active:
			# Clignotement rouge pour l'impact
			var hit_factor = sin(stun_flash_timer * hit_flash_speed) * 0.5 + 0.5
			mesh_instance.modulate = original_modulate.lerp(Color.RED, hit_factor)
		elif is_stunned_active:
			# Clignotement blanc pendant le stun
			var stun_factor = sin(stun_flash_timer * stun_flash_speed) * 0.5 + 0.5
			mesh_instance.modulate = original_modulate.lerp(Color.WHITE, stun_factor)
		else:
			mesh_instance.modulate = original_modulate

	# Gérer la visibilité et l'animation du TakedownSprite
	if takedown_sprite:
		takedown_sprite.visible = stun
		if stun and not takedown_sprite.is_playing():
			takedown_sprite.play("stunned")

	# Direction vers le joueur
	var direction = Vector3.ZERO
	var dist = 0.0
	if player and is_instance_valid(player) and (player.has_method("is_dead") and not player.is_dead()):
		direction = (player.global_position - global_position).normalized()
		dist = global_position.distance_to(player.global_position)
		moving = direction.length() > 0 and dist > attack_range
	else:
		moving = false

	apply_gravity(delta)
	if attacking or stun:
		velocity.x = 0; velocity.z = 0
	elif moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0; velocity.z = 0

	if not (stun or dead) and direction.length_squared() > 0:
		var target_yaw = atan2(direction.x, direction.z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)

	adjust_to_terrain(delta)
	update_blend_position()
	if player and is_instance_valid(player) and (player.has_method("is_dead") and not player.is_dead()) and dist <= attack_range and can_attack and not stun and not dead:
		start_attack()
	update_animation()
	if health_label and health_label.visible:
		_face_camera(health_label)
		health_label.text = str(int(current_health))
	move_and_slide()

# --- Fonctions utilitaires ---
func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

func start_attack():
	attacking = true
	can_attack = false
	attack_timer.start()
	# Sélectionner une attaque aléatoire (0 à 3 pour Attack_01 à Attack_04)
	attack_index = randi_range(0, 3)  # Utiliser un entier pour une sélection précise
	anim_state.travel("Attack")  # Forcer la transition vers l'état Attack
	anim_tree.set("parameters/Attack/blend_position", float(attack_index))  # Définir la position dans le BlendSpace1D
	if player and is_instance_valid(player):
		player.take_damage(10)
	print("Starting attack: Attack_0", attack_index + 1)

func _on_attack_timer_timeout():
	attacking = false
	can_attack = true
	anim_tree.set("parameters/Attack/blend_position", 0.0)  # Réinitialiser pour éviter des transitions incorrectes
	anim_state.travel("Idle")  # Forcer le retour à l'état Idle après l'attaque
	print("Attack ended")

func take_damage(damage: float, projectile: Node) -> void:
	if dead or stun:
		return

	current_health = max(current_health - damage, 0)
	print("Hit! Damage:", damage, "Health:", current_health)

	hit_timer = hit_duration
	is_hit_active = true

	if health_label:
		health_label.visible = true
		health_label.text = str(int(current_health))
		health_label.scale = original_scale * impact_scale_factor
		impact_timer.start()
		health_label_timer.start()

	if current_health <= 0:
		if randf() < stun_probability:
			enter_stun_state()
		else:
			die()

func enter_stun_state():
	stun = true
	stun_timer.start()
	if player and is_instance_valid(player):
		player.add_score(10)
	print("Enemy stunned!")
	is_stunned_active = true
	if takedown_sprite:
		takedown_sprite.visible = true
		takedown_sprite.play("stunned")

func die():
	dead = true
	collision_shape.disabled = true
	velocity = Vector3.ZERO
	if player and is_instance_valid(player):
		player.add_score(50)
	print("Enemy died")
	if health_label:
		health_label.visible = false
	if takedown_sprite:
		takedown_sprite.visible = false
		takedown_sprite.stop()
	if mesh_instance:
		is_stunned_active = false
		mesh_instance.modulate = original_modulate
	if animation_player and animation_player.has_animation("Death"):
		var anim = animation_player.get_animation("Death")
		var animation_length = anim.length
		animation_player.play("Death")
		await get_tree().create_timer(animation_length).timeout
	death_delay_timer.start()

func _on_stun_timer_timeout():
	if not takedown_performed:
		die()
	else:
		takedown_performed = false
		stun = false
		if takedown_sprite:
			takedown_sprite.visible = false
			takedown_sprite.stop()
		print("Takedown performed, enemy recovered or other logic")
	if mesh_instance:
		is_stunned_active = false
		mesh_instance.modulate = original_modulate

func _on_health_label_timer_timeout():
	if health_label:
		health_label.visible = false

func _on_impact_timer_timeout():
	if health_label:
		health_label.scale = original_scale

func _on_death_delay_timer_timeout():
	queue_free()

func update_blend_position():
	if (moving or attacking) and velocity.length_squared() > 0 and not stun:
		var local_vel = global_transform.basis.inverse() * velocity
		blend_position = Vector2(clamp(local_vel.x / speed, -1, 1), clamp(-local_vel.z / speed, -1, 1))
	else:
		blend_position = Vector2.ZERO

func update_animation():
	if dead:
		anim_state.travel("Death")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)
		anim_tree.set("parameters/Attack/blend_position", 0.0)
	elif stun:
		anim_state.travel("Stun")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)
		anim_tree.set("parameters/Attack/blend_position", 0.0)
	elif attacking:
		anim_state.travel("Attack")
		anim_tree.set("parameters/Attack/blend_position", float(attack_index))
		anim_tree.set("parameters/Walk/blend_position", blend_position if moving else Vector2.ZERO)
	elif moving:
		anim_state.travel("Walk")
		anim_tree.set("parameters/Walk/blend_position", blend_position)
		anim_tree.set("parameters/Attack/blend_position", 0.0)
	else:
		anim_state.travel("Idle")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)
		anim_tree.set("parameters/Attack/blend_position", 0.0)

func _face_camera(node: Node3D):
	var cam = get_viewport().get_camera_3d()
	if cam:
		node.look_at(cam.global_transform.origin, Vector3.UP)

func adjust_to_terrain(delta: float):
	if not ground_ray:
		return
	ground_ray.force_raycast_update()
	var target_normal = ground_ray.get_collision_normal() if ground_ray.is_colliding() else Vector3.UP
	current_normal = current_normal.lerp(target_normal, rotation_lerp_speed * delta).normalized()
	var up = current_normal
	var forward = (global_transform.basis.z - up * up.dot(global_transform.basis.z)).normalized()
	var right = up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	var target_basis = Basis(right, up, forward)
	var new_basis = global_transform.basis.slerp(target_basis, rotation_lerp_speed * delta)
	var current_yaw = rotation.y
	global_transform.basis = new_basis
	rotation.y = current_yaw

func is_stunned() -> bool:
	return stun

func is_dead() -> bool:
	return dead
