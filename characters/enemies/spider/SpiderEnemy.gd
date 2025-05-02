extends Enemy
class_name SpiderEnemy

# --- Propriétés exportées ---
@export var speed: float = 5.0
@export var attack_range: float = 2.0
@export var gravity: float = 9.8
@export var attack_cooldown: float = 1.0
@export var stun_duration: float = 2.0
@export var rotation_lerp_speed: float = 5.0
@export var stun_probability: float = 0.5
@export var impact_scale_factor: float = 1.5
@export var impact_animation_duration: float = 0.2
@export var hit_duration: float = 0.2
@export var hit_flash_speed: float = 20.0
@export var stun_flash_speed: float = 5.0

# --- Références ---
@onready var player = get_tree().get_first_node_in_group("player")
@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback") if anim_tree else null
@onready var collision_shape = $CollisionShape3D
@onready var health_label = $HealthLabel
@onready var ground_ray = $GroundRay
@onready var animation_player = $AnimationPlayer
@onready var takedown_sprite = $TakedownSprite

# --- États internes ---
var moving: bool = false
var attacking: bool = false
var stun: bool = false
var can_attack: bool = true
var blend_position: Vector2 = Vector2.ZERO
var current_normal: Vector3 = Vector3.UP
var takedown_performed: bool = false
var original_scale: Vector3
var hit_timer: float = 0.0
var stun_flash_timer: float = 0.0
var is_hit_active: bool = false
var is_stunned_active: bool = false

# --- Timers ---
var attack_timer: Timer
var stun_timer: Timer
var health_label_timer: Timer
var impact_timer: Timer
var death_delay_timer: Timer

# --- Initialisation ---
func _ready() -> void:
	super._ready()
	health = max_health

	if not anim_tree:
		print("ERREUR : AnimationTree non trouvé !")
		return

	anim_tree.active = true
	anim_state = anim_tree.get("parameters/playback")
	if not anim_state:
		print("ERREUR : AnimationNodeStateMachinePlayback non trouvé !")
		return

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	stun_timer = Timer.new()
	stun_timer.wait_time = stun_duration
	stun_timer.one_shot = true
	add_child(stun_timer)
	stun_timer.timeout.connect(_on_stun_timer_timeout)

	health_label_timer = Timer.new()
	health_label_timer.wait_time = 0.5
	health_label_timer.one_shot = true
	add_child(health_label_timer)
	health_label_timer.timeout.connect(_on_health_label_timer_timeout)

	impact_timer = Timer.new()
	impact_timer.wait_time = impact_animation_duration
	impact_timer.one_shot = true
	add_child(impact_timer)
	impact_timer.timeout.connect(_on_impact_timer_timeout)

	death_delay_timer = Timer.new()
	death_delay_timer.wait_time = 3.0
	death_delay_timer.one_shot = true
	add_child(death_delay_timer)
	death_delay_timer.timeout.connect(_on_death_delay_timer_timeout)

	if health_label:
		original_scale = health_label.scale
		health_label.text = str(int(health))
		health_label.visible = false

	if takedown_sprite:
		takedown_sprite.visible = false
	else:
		print("TakedownSprite not found!")

# --- Physique ---
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return

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

	if takedown_sprite:
		takedown_sprite.visible = stun
		if stun and not takedown_sprite.is_playing():
			takedown_sprite.play("stunned")

	if not player or not is_instance_valid(player) or player.is_dead:
		moving = false
		velocity = Vector3.ZERO
		update_animation()
		return

	var direction = (player.global_position - global_position).normalized()
	var dist = global_position.distance_to(player.global_position)

	if stun:
		velocity = Vector3.ZERO
	elif dist <= attack_range and can_attack and not attacking:
		start_attack()
	else:
		if dist > attack_range:
			moving = true
			var target_yaw = atan2(direction.x, direction.z) + PI
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_lerp_speed * delta)
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			moving = false
			velocity.x = 0
			velocity.z = 0

	apply_gravity(delta)
	adjust_to_terrain(delta)
	update_blend_position()
	update_animation()

	if health_label and health_label.visible:
		_face_camera(health_label)
		health_label.text = str(int(health))

	move_and_slide()

# --- Fonctions utilitaires ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

func start_attack() -> void:
	attacking = true
	can_attack = false

	var attack_index = randi() % 4
	anim_tree.set("parameters/Attack/AttackBlendspace/attack_index", float(attack_index))
	anim_state.travel("Attack")

	if player and is_instance_valid(player):
		player.take_damage(10, self)

	attack_timer.start()

func _on_attack_timer_timeout() -> void:
	attacking = false
	can_attack = true
	if anim_state:
		anim_state.travel("Idle")

func take_damage(amount: float, projectile: Node = null) -> void:
	if is_dead or stun:
		return
	super.take_damage(amount)
	hit_timer = hit_duration
	is_hit_active = true
	if health_label:
		health_label.visible = true
		health_label.text = str(int(health))
		health_label.scale = original_scale * impact_scale_factor
		impact_timer.start()
		health_label_timer.start()
	if health <= 0:
		if randf() < stun_probability:
			enter_stun_state()

func enter_stun_state() -> void:
	stun = true
	stun_timer.start()
	if player and is_instance_valid(player):
		player.add_score(10)
	is_stunned_active = true
	if takedown_sprite:
		takedown_sprite.visible = true
		takedown_sprite.play("stunned")

func die() -> void:
	super.die()
	collision_shape.disabled = true
	velocity = Vector3.ZERO
	if player and is_instance_valid(player):
		player.add_score(50)
	if health_label:
		health_label.visible = false
	if takedown_sprite:
		takedown_sprite.visible = false
		takedown_sprite.stop()
	if animation_player and animation_player.has_animation("Death"):
		var anim = animation_player.get_animation("Death")
		var animation_length = anim.length
		animation_player.play("Death")
		await get_tree().create_timer(animation_length).timeout
	death_delay_timer.start()

func _on_stun_timer_timeout() -> void:
	if not takedown_performed:
		die()
	else:
		takedown_performed = false
		stun = false
		if takedown_sprite:
			takedown_sprite.visible = false
			takedown_sprite.stop()

func _on_health_label_timer_timeout() -> void:
	if health_label:
		health_label.visible = false

func _on_impact_timer_timeout() -> void:
	if health_label:
		health_label.scale = original_scale

func _on_death_delay_timer_timeout() -> void:
	queue_free()

func update_blend_position() -> void:
	if (moving or attacking) and velocity.length_squared() > 0 and not stun:
		var local_vel = global_transform.basis.inverse() * velocity
		blend_position = Vector2(clamp(local_vel.x / speed, -1, 1), clamp(-local_vel.z / speed, -1, 1))
	else:
		blend_position = Vector2.ZERO

func update_animation() -> void:
	if not anim_state:
		return
	if is_dead:
		anim_state.travel("Death")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)
	elif stun:
		anim_state.travel("Stun")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)
	elif attacking:
		anim_state.travel("Attack")
		anim_tree.set("parameters/Walk/blend_position", blend_position if moving else Vector2.ZERO)
	elif moving:
		anim_state.travel("Walk")
		anim_tree.set("parameters/Walk/blend_position", blend_position)
	else:
		anim_state.travel("Idle")
		anim_tree.set("parameters/Walk/blend_position", Vector2.ZERO)

func _face_camera(node: Node3D) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam:
		node.look_at(cam.global_transform.origin, Vector3.UP)

func adjust_to_terrain(delta: float) -> void:
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
