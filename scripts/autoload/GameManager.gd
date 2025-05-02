extends Node
class_name GameManager

# Constantes
const TARGET_SCN: PackedScene = preload("res://HUD/sprites/TargetSprite.tscn")
const TAKEDOWN_SCN: PackedScene = preload("res://HUD/sprites/TakedownSprite.tscn")
const DEFAULT_TEXTURE: Texture2D = preload("res://HUD/sprites/default_texture.png")  # Texture par défaut importée

# Variables exportées
@export var rotation_speed: float = 2.0  # Vitesse de rotation (rad/s)
@export var follow_lerp: float = 0.25    # Lissage du sprite

# Variables avec références directes
@onready var player = get_tree().get_first_node_in_group("player")
@onready var camera_rig: Node3D = $"/root/Aridia/CameraRig"
@onready var target_sprite: Sprite3D = _find_or_create_sprite("TargetSprite", TARGET_SCN)
@onready var takedown_sprite: Sprite3D = _find_or_create_sprite("TakedownSprite", TAKEDOWN_SCN)

func _ready() -> void:
	set_physics_process(false)
	call_deferred("_late_init")

func _late_init() -> void:
	# Vérification des références
	if not player or not camera_rig:
		push_error("Player ou CameraRig non trouvé. Vérifie les chemins.")
		return
	
	# Configuration initiale des sprites
	if takedown_sprite and "billboard_mode" in takedown_sprite:  # Vérification ajoutée
		takedown_sprite.billboard_mode = 1
	_init_sprite(target_sprite, Color(1, 0, 0, 1))  # Rouge par défaut
	_init_sprite(takedown_sprite, Color(0.2, 0.6, 1.0))  # Bleu
	
	# Configuration de la caméra
	if camera_rig.has_method("set_follow_target"):
		camera_rig.set_follow_target(player)
	
	set_physics_process(true)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(player):
		push_error("Player invalide.")
		return
	_update_target_sprite(dt)
	_update_takedown_sprite(dt)

func _find_or_create_sprite(group_name: String, scene: PackedScene) -> Sprite3D:
	var sprite = _find_sprite(group_name)
	if not sprite:
		sprite = _safe_instance(scene, group_name)
	return sprite

func _find_sprite(group_name: String) -> Sprite3D:
	for n in get_tree().get_nodes_in_group(group_name):
		if n is Sprite3D:
			return n
	return null

func _safe_instance(scene: PackedScene, group_name: String) -> Sprite3D:
	if not scene:
		push_error("%s: PackedScene non défini." % group_name)
		return null
	var inst = scene.instantiate()
	if not inst:
		push_error("%s: Échec de l’instanciation." % group_name)
		return null
	if not inst is Sprite3D:
		push_error("%s: L’instance n’est pas un Sprite3D." % group_name)
		inst.queue_free()
		return null
	get_tree().current_scene.add_child(inst)
	inst.add_to_group(group_name)
	return inst

func _init_sprite(s: Sprite3D, col: Color) -> void:
	if not s:
		return
	s.texture = DEFAULT_TEXTURE if not s.texture else s.texture
	s.modulate = col
	s.pixel_size = 0.015
	s.scale = Vector3.ONE * 1.5
	s.visible = false

func _update_target_sprite(dt: float) -> void:
	if not target_sprite:
		return
	var tgt: Node3D = player.get_detected_target()
	if tgt and is_instance_valid(tgt):
		target_sprite.visible = true
		target_sprite.modulate = Color(1, 0, 0, 1) if tgt.is_in_group("enemies") else Color(0, 1, 0, 1)
		_place_sprite(target_sprite, tgt, dt)
	else:
		target_sprite.visible = false

func _update_takedown_sprite(dt: float) -> void:
	if not takedown_sprite:
		return
	var stunned_enemy: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_stunned") and e.is_stunned():
			stunned_enemy = e
			break
	if stunned_enemy and is_instance_valid(stunned_enemy):
		takedown_sprite.visible = true
		_place_sprite(takedown_sprite, stunned_enemy, dt, 0.0)
	else:
		takedown_sprite.visible = false

func _place_sprite(s: Sprite3D, ent: Node3D, dt: float, y_off: float = 0.01) -> void:
	_adapt_scale(s, ent)
	var goal: Vector3 = _ground_pos(ent) + Vector3(0, y_off, 0)
	s.global_position = s.global_position.lerp(goal, follow_lerp)
	if s == target_sprite:
		s.rotate_y(rotation_speed * dt)

func _adapt_scale(s: Sprite3D, ent: Node3D) -> void:
	var sz: float = 1.5
	if ent.has_node("CollisionShape3D"):
		var cs := ent.get_node("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape:
			if cs.shape is BoxShape3D:
				sz = max(cs.shape.extents.x, cs.shape.extents.z) * 2.4
			elif cs.shape is SphereShape3D or cs.shape is CylinderShape3D:
				sz = cs.shape.radius * 2.4
	elif ent.has_node("MeshInstance3D"):
		var m: MeshInstance3D = ent.get_node("MeshInstance3D")
		if m and m.mesh:
			sz = max(m.mesh.get_aabb().size.x, m.mesh.get_aabb().size.z) * 1.2
	s.scale = Vector3.ONE * clamp(sz, 1.0, 2.0)

func _ground_pos(ent: Node3D) -> Vector3:
	if ent.has_node("GroundRay"):
		var ray = ent.get_node("GroundRay")
		if ray is RayCast3D:
			ray.force_raycast_update()
			if ray.is_colliding():
				return ray.get_collision_point()
	return ent.global_position
