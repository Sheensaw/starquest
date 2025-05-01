extends Node

@export var pool_size: int = 20
@export var projectile_scene: PackedScene

var pool: Array[Node3D] = []

func _ready() -> void:
	if not projectile_scene:
		push_error("ProjectilePool: 'projectile_scene' is not assigned!")
		return
	for i in range(pool_size):
		var p = projectile_scene.instantiate()
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(p)
		pool.append(p)

func get_projectile() -> Node3D:
	for p in pool:
		if not p.visible:
			p.visible = true
			p.process_mode = Node.PROCESS_MODE_INHERIT
			return p
	return null

func return_projectile(p: Node3D) -> void:
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
