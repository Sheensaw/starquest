extends Node
class_name GameManager
#────────────────────────────────────────────────────────────
@onready var player       : CharacterBody3D = _first("player")
@onready var camera_rig   : Node3D          = _first("camera_rig")
@onready var target_sprite: Sprite3D        = _find_sprite()
#────────────────────────────────────────────────────────────
@export var rotation_speed: float = 2.0   # rad/s
@export var follow_lerp   : float = 0.25  # 0 = pas de lissage
#────────────────────────────────────────────────────────────
func _ready() -> void:
	if camera_rig and player and camera_rig.has_method("set_follow_target"):
		camera_rig.set_follow_target(player)
	_init_sprite()
#────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not player or not target_sprite:
		return
	_update_sprite(delta)
#────────────────────────────────────────────────────────────
#  Helpers init
#────────────────────────────────────────────────────────────
func _first(g:String)->Node:
	return get_tree().get_nodes_in_group(g)[0] if get_tree().has_group(g) and !get_tree().get_nodes_in_group(g).is_empty() else null

func _find_sprite()->Sprite3D:
	var s := get_node_or_null("NECROFROST/TargetSprite")
	if s and s is Sprite3D: return s
	for n in get_tree().get_nodes_in_group("TargetSprite"):
		if n is Sprite3D: return n
	return null

func _init_sprite()->void:
	if not target_sprite: return
	if not target_sprite.texture:
		var img:=Image.new(); img.create(64,64,false,Image.FORMAT_RGBA8); img.fill(Color.WHITE)
		target_sprite.texture = ImageTexture.create_from_image(img)
	target_sprite.visible    = false
	target_sprite.pixel_size = 0.015
	target_sprite.scale      = Vector3.ONE * 1.5
#────────────────────────────────────────────────────────────
#  Mise à jour du TargetSprite
#────────────────────────────────────────────────────────────
func _update_sprite(d:float)->void:
	var tgt: Node3D = player.get_detected_target() if player else null
	if not tgt or not is_instance_valid(tgt):
		target_sprite.visible = false
		return
	
	target_sprite.visible  = true
	target_sprite.modulate = Color(1,0,0,1) if tgt.is_in_group("enemies") else Color(0,1,0,1)
	
	_adapt_scale(tgt)
	var goal := _ground_pos(tgt)
	target_sprite.global_position = target_sprite.global_position.lerp(goal, follow_lerp)
	target_sprite.rotation.y += rotation_speed * d
#────────────────────────────────────────────────────────────
#  Helpers : échelle & sol
#────────────────────────────────────────────────────────────
func _adapt_scale(ent:Node3D)->void:
	var s:float = 1.5
	var cs := ent.get_node("CollisionShape3D") if ent.has_node("CollisionShape3D") else null
	if cs and cs.shape:
		match cs.shape:
			BoxShape3D:                        s = max(cs.shape.extents.x, cs.shape.extents.z) * 2.4
			SphereShape3D, CylinderShape3D:    s = cs.shape.radius * 2.4
	elif ent.has_node("MeshInstance3D"):
		var m:Mesh = ent.get_node("MeshInstance3D").mesh
		if m: s = max(m.get_aabb().size.x, m.get_aabb().size.z) * 1.2
	target_sprite.scale = Vector3.ONE * clamp(s, 1.0, 2.0)

func _ground_pos(ent:Node3D)->Vector3:
	# Chaque ennemi/aimable possède son propre RayCast3D nommé "GroundRay"
	if ent.has_node("GroundRay"):
		var ray: RayCast3D = ent.get_node("GroundRay")
		ray.force_raycast_update()
		if ray.is_colliding():
			var p := ray.get_collision_point()
			return Vector3(p.x, p.y + 0.01, p.z)
	# Repli : position XZ de l’entité
	return ent.global_position + Vector3(0,0.01,0)
