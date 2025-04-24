extends Node

@onready var player: CharacterBody3D = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
@onready var camera_rig: Node3D = get_tree().get_nodes_in_group("camera_rig")[0] if get_tree().has_group("camera_rig") else null
@onready var arrow_decal: Decal = player.get_node("ArrowDirection") if player and player.has_node("ArrowDirection") else null
@onready var target_sprite: Sprite3D = $TargetSprite  # Référence au nœud Sprite3D dans la scène
@onready var ground_ray: RayCast3D = $GroundRay  # Référence au RayCast3D pour détecter le sol

# Variables pour gérer la flèche
var current_alpha: float = 0.0  # Opacité actuelle
var target_alpha: float = 0.0   # Opacité cible
const FADE_SPEED: float = 5.0   # Vitesse du fondu (5.0 ≈ 0.2 seconde)

# Vitesse de rotation de la cible
var rotation_speed: float = 2.0  # Vitesse de rotation en radians par seconde

func _ready() -> void:
	if not player:
		push_error("GameManager.gd : aucun joueur trouvé dans le groupe 'player'.")
	if not camera_rig:
		push_error("GameManager.gd : aucun camera_rig trouvé dans le groupe 'camera_rig'.")
	if not arrow_decal:
		push_error("GameManager.gd : aucun ArrowDirection trouvé dans les enfants du joueur.")
	if not target_sprite:
		push_error("GameManager.gd : aucun TargetSprite trouvé dans la scène.")
	else:
		# S'assurer que le sprite a une texture
		if not target_sprite.texture:
			push_warning("GameManager.gd : TargetSprite n'a pas de texture définie. Vérifiez la configuration dans la scène.")
		# Cacher le sprite par défaut
		target_sprite.visible = false
	if not ground_ray:
		push_error("GameManager.gd : aucun GroundRay trouvé dans la scène.")
	if player and camera_rig:
		camera_rig.set_follow_target(player)

func _physics_process(delta: float) -> void:
	if not player or not arrow_decal or not target_sprite or not ground_ray:
		return
	
	# Gérer l'opacité de la flèche
	update_arrow_alpha(delta)
	
	# Gérer la cible (Sprite3D)
	update_target_sprite(delta)

func update_arrow_position(position: Vector3, scale: Vector3) -> void:
	if arrow_decal:
		arrow_decal.global_position = position
		arrow_decal.scale = scale

func update_arrow_alpha(delta: float) -> void:
	if not arrow_decal:
		return
	
	# Si le joueur est en mode verrouillage, la flèche disparaît
	if player.is_in_lock_mode():
		target_alpha = 0.0
	else:
		# Sinon, la flèche apparaît si le joueur bouge
		var is_moving = player.is_moving()
		target_alpha = 1.0 if is_moving else 0.0
	
	# Interpoler l'opacité actuelle vers l'opacité cible
	current_alpha = lerp(current_alpha, target_alpha, FADE_SPEED * delta)
	arrow_decal.modulate.a = current_alpha

func update_target_sprite(delta: float) -> void:
	# Vérifier si un ennemi est détecté dans le cône
	var detected_enemy = player.get_detected_enemy()
	if detected_enemy:
		# Afficher la cible
		target_sprite.visible = true
		# Définir une opacité de 0.2
		target_sprite.modulate.a = 0.2
		
		# Adapter la taille de la cible à celle de l'ennemi
		adapt_sprite_to_enemy_size(detected_enemy)
		
		# Positionner la cible au niveau du sol sous l'ennemi
		position_sprite_on_ground(detected_enemy)
		
		# Faire tourner la cible
		target_sprite.rotation.y += rotation_speed * delta
	else:
		# Cacher la cible
		target_sprite.visible = false

func adapt_sprite_to_enemy_size(enemy: Node3D) -> void:
	var sprite_size: float = 2.0  # Taille par défaut si aucune taille n'est trouvée
	
	# Vérifier si l'ennemi a un CollisionShape3D
	var collision_shape = enemy.get_node("CollisionShape3D") if enemy.has_node("CollisionShape3D") else null
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is BoxShape3D:
			var enemy_extents = collision_shape.shape.extents
			# Utiliser la plus grande dimension (x ou z) pour calculer la taille
			sprite_size = max(enemy_extents.x, enemy_extents.z) * 2.4  # 2.4 pour correspondre à 1.2x les extents (diamètre)
		elif collision_shape.shape is SphereShape3D:
			var enemy_radius = collision_shape.shape.radius
			sprite_size = enemy_radius * 2.4  # 2.4 pour correspondre à 1.2x le rayon (diamètre)
		elif collision_shape.shape is CylinderShape3D:
			var enemy_radius = collision_shape.shape.radius
			sprite_size = enemy_radius * 2.4  # 2.4 pour correspondre à 1.2x le rayon (diamètre)
		else:
			# Si la forme n'est pas reconnue, utiliser une taille par défaut
			sprite_size = 2.0
	else:
		# Si aucun CollisionShape3D n'est trouvé, chercher un nœud visuel (comme un MeshInstance3D)
		var mesh_instance = enemy.get_node("MeshInstance3D") if enemy.has_node("MeshInstance3D") else null
		if mesh_instance and mesh_instance.mesh:
			var aabb = mesh_instance.mesh.get_aabb()
			# Utiliser la plus grande dimension (x ou z) de la boîte englobante
			sprite_size = max(aabb.size.x, aabb.size.z) * 1.2  # 1.2 pour correspondre à la taille visuelle
	
	# S'assurer que la taille n'est ni trop petite ni trop grande
	sprite_size = clamp(sprite_size, 1.0, 10.0)  # Limiter entre 1 et 10 unités
	
	# Appliquer la taille au sprite
	target_sprite.scale = Vector3(sprite_size, sprite_size, sprite_size)

func position_sprite_on_ground(enemy: Node3D) -> void:
	# Positionner le RayCast3D au-dessus de l'ennemi pour détecter le sol
	ground_ray.global_position = enemy.global_position + Vector3(0, 2, 0)  # Commencer 2 unités au-dessus
	ground_ray.global_rotation = Vector3.ZERO  # S'assurer qu'il pointe vers le bas
	ground_ray.force_raycast_update()  # Forcer une mise à jour immédiate du RayCast
	
	# Vérifier si le RayCast détecte le sol
	if ground_ray.is_colliding():
		var ground_point = ground_ray.get_collision_point()
		# Positionner le sprite au point de collision avec un léger décalage
		target_sprite.global_position = Vector3(ground_point.x, ground_point.y + 0.01, ground_point.z)
	else:
		# Si aucun sol n'est détecté, position par défaut
		target_sprite.global_position = Vector3(enemy.global_position.x, 0.01, enemy.global_position.z)
