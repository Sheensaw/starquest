extends Node
class_name GameManager

#────────────────────────────────────────────────────────────
@export var rotation_speed : float = 2.0      # rad /s
@export var follow_lerp    : float = 0.25     # lissage sprite

#────────────────────────────────────────────────────────────
var player          : CharacterBody3D
var camera_rig      : Node3D
var target_sprite   : Sprite3D        # rouge / vert
var takedown_sprite : Sprite3D        # bleu (billboard)

#────────────────────────────────────────────────────────────
const TARGET_SCN   : PackedScene = preload("res://HUD/sprites/TargetSprite.tscn")
const TAKEDOWN_SCN : PackedScene = preload("res://HUD/sprites/TakedownSprite.tscn")

#────────────────────────────────────────────────────────────
func _ready() -> void:
	set_physics_process(false)
	call_deferred("_late_init")

#────────────────────────────────────────────────────────────
func _late_init() -> void:
	player        = _first("player")
	camera_rig    = _first("camera_rig")
	target_sprite = _find_sprite("TargetSprite")
	takedown_sprite = _find_sprite("TakedownSprite")
	
	# ── instanciation sûre ──────────────────────────────────
	if target_sprite == null:
		target_sprite = _safe_instance(TARGET_SCN, "TargetSprite")
	if takedown_sprite == null:
		takedown_sprite = _safe_instance(TAKEDOWN_SCN, "TakedownSprite")
	
	# Billboard pour le sprite de takedown (1 = BILLBOARD_ENABLED)
	if takedown_sprite and "billboard_mode" in takedown_sprite:
		takedown_sprite.billboard_mode = 1
	
	# Apparence par défaut
	_init_sprite(target_sprite)
	_init_sprite(takedown_sprite, Color(0.2, 0.6, 1.0))
	
	# Caméra suiveuse
	if camera_rig and player and camera_rig.has_method("set_follow_target"):
		camera_rig.set_follow_target(player)
	
	set_physics_process(true)

#────────────────────────────────────────────────────────────
func _physics_process(dt: float) -> void:
	if not player or not is_instance_valid(player):
		player = _first("player")
	if not player: return
	
	_update_target_sprite(dt)
	_update_takedown_sprite(dt)

#────────────────────────────────────────────────────────────
#  ── helpers ───────────────────────────────────────────────
#────────────────────────────────────────────────────────────
func _first(group_name: String) -> Node:
	var nodes = get_tree().get_nodes_in_group(group_name)
	return nodes[0] if nodes else null

func _find_sprite(group_name: String) -> Sprite3D:
	for n in get_tree().get_nodes_in_group(group_name):
		if n is Sprite3D:
			return n
	return null

func _safe_instance(scene: PackedScene, group_name: String) -> Sprite3D:
	if scene == null:
		push_error("%s: PackedScene not found." % group_name)
		return null
	var inst = scene.instantiate()
	if inst == null:
		push_error("%s: instantiation failed." % group_name)
		return null
	if inst is Sprite3D:
		get_tree().current_scene.add_child(inst)
		inst.add_to_group(group_name)
		return inst
	else:
		push_error("%s scene is not a Sprite3D." % group_name)
		return null

#────────────────────────────────────────────────────────────
func _init_sprite(s: Sprite3D, col: Color = Color.WHITE) -> void:
	if s == null: return
	if not s.texture:
		var img := Image.new()
		img.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		s.texture = ImageTexture.create_from_image(img)
	s.modulate   = col
	s.pixel_size = 0.015
	s.scale      = Vector3.ONE * 1.5
	s.visible    = false

#────────────────────────────────────────────────────────────
#  sprite de visée rouge / vert
#────────────────────────────────────────────────────────────
func _update_target_sprite(dt: float) -> void:
	if target_sprite == null: return
	var tgt: Node3D = player.get_detected_target()
	if tgt and is_instance_valid(tgt):
		target_sprite.visible  = true
		target_sprite.modulate = Color(1, 0, 0, 1) if tgt.is_in_group("enemies") else Color(0, 1, 0, 1)
		_place_sprite(target_sprite, tgt, dt)
	else:
		target_sprite.visible = false

#────────────────────────────────────────────────────────────
#  sprite de takedown bleu
#────────────────────────────────────────────────────────────
func _update_takedown_sprite(dt: float) -> void:
	if takedown_sprite == null: return
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

#────────────────────────────────────────────────────────────
#  placement commun
#────────────────────────────────────────────────────────────
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
		var ray: RayCast3D = ent.get_node("GroundRay")
		ray.force_raycast_update()
		if ray.is_colliding():
			return ray.get_collision_point()
	return ent.global_position
