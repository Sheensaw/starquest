extends Node

@onready var player: CharacterBody3D = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
@onready var camera_rig: Node3D = get_tree().get_nodes_in_group("camera_rig")[0] if get_tree().has_group("camera_rig") else null
@onready var target_sprite: Sprite3D = find_target_sprite()  # Utiliser une méthode pour trouver le TargetSprite
@onready var ground_ray: RayCast3D = $GroundRay  # Référence au RayCast3D pour détecter le sol

# Vitesse de rotation de la cible
var rotation_speed: float = 2.0  # Vitesse de rotation en radians par seconde

func _ready() -> void:
	# Vérifier les références et afficher leur état
	if not player:
		push_error("GameManager.gd : aucun joueur trouvé dans le groupe 'player'.")
	else:
		print("GameManager.gd : Joueur trouvé : ", player.name)
	if not camera_rig:
		push_error("GameManager.gd : aucun camera_rig trouvé dans le groupe 'camera_rig'.")
	else:
		print("GameManager.gd : Camera Rig trouvé : ", camera_rig.name)
	if not target_sprite:
		push_error("GameManager.gd : aucun TargetSprite trouvé dans la scène après recherche.")
	else:
		# S'assurer que le sprite a une texture
		if not target_sprite.texture:
			# Créer une texture par défaut si aucune texture n'est définie
			var default_texture = ImageTexture.new()
			var image = Image.new()
			image.create(64, 64, false, Image.FORMAT_RGBA8)  # Créer une image 64x64
			image.fill(Color.WHITE)  # Remplir avec du blanc
			default_texture.create_from_image(image)
			target_sprite.texture = default_texture
			print("GameManager.gd : Texture par défaut assignée à TargetSprite")
		else:
			print("GameManager.gd : TargetSprite a une texture : ", target_sprite.texture.resource_path)
		# Cacher le sprite par défaut
		target_sprite.visible = false
	if not ground_ray:
		push_error("GameManager.gd : aucun GroundRay trouvé dans la scène.")
	else:
		print("GameManager.gd : GroundRay trouvé : ", ground_ray.name)
	if player and camera_rig:
		camera_rig.set_follow_target(player)
	else:
		print("GameManager.gd : Impossible de connecter camera_rig au joueur - player : ", player, ", camera_rig : ", camera_rig)

func _physics_process(delta: float) -> void:
	# Confirmer que _physics_process est appelé
	print("GameManager.gd : _physics_process appelé")
	
	# Vérifier pourquoi _physics_process pourrait ne pas s'exécuter
	if not player:
		print("GameManager.gd : Player est null")
		return
	if not target_sprite:
		print("GameManager.gd : TargetSprite est null")
		return
	if not ground_ray:
		print("GameManager.gd : GroundRay est null")
		return
	
	# Gérer la cible (Sprite3D)
	update_target_sprite(delta)

# Méthode pour trouver le TargetSprite dans la scène
func find_target_sprite() -> Sprite3D:
	# Essayer d'abord le chemin spécifique
	var sprite = get_node_or_null("NECROFROST/TargetSprite")
	if sprite and sprite is Sprite3D:
		print("GameManager.gd : TargetSprite trouvé via chemin direct : NECROFROST/TargetSprite")
		return sprite
	
	# Si le chemin direct échoue, chercher dans toute la scène
	var scene_root = get_tree().root
	var found_sprite = null
	var nodes_to_check = [scene_root]
	while not nodes_to_check.is_empty():
		var node = nodes_to_check.pop_front()
		if node.name == "TargetSprite" and node is Sprite3D:
			found_sprite = node
			break
		for child in node.get_children():
			nodes_to_check.append(child)
	
	if found_sprite:
		print("GameManager.gd : TargetSprite trouvé via recherche dans la scène : ", found_sprite.get_path())
	else:
		print("GameManager.gd : TargetSprite non trouvé dans la scène après recherche exhaustive")
	return found_sprite

func update_target_sprite(delta: float) -> void:
	# Vérifier si une cible est détectée dans le cône
	var detected_target = player.get_detected_target()
	if detected_target:
		# Afficher la cible
		target_sprite.visible = true
		# Définir une opacité complète pour plus de visibilité
		target_sprite.modulate.a = 1.0  # Opacité à 1.0
		
		# Déterminer la couleur du sprite en fonction du groupe "enemies"
		if detected_target.is_in_group("enemies"):
			target_sprite.modulate = Color(1, 0, 0, 1.0)  # Rouge pour les ennemis
			print("GameManager.gd : Cible détectée : ", detected_target.name, " (ennemi), couleur rouge")
		else:
			target_sprite.modulate = Color(0, 1, 0, 1.0)  # Vert pour les autres aimables
			print("GameManager.gd : Cible détectée : ", detected_target.name, " (aimable), couleur verte")
		
		# Ajuster l'échelle et la taille des pixels pour une taille raisonnable
		target_sprite.scale = Vector3(1.5, 1.5, 1.5)  # Échelle à 1.5
		target_sprite.pixel_size = 0.015  # Taille des pixels à 0.015
		
		# Positionner la cible au niveau du sol sous l'entité
		position_sprite_on_ground(detected_target)
		
		# Vérifier la position du sprite et la position de la caméra
		var camera = get_viewport().get_camera_3d()
		if camera:
			var sprite_screen_pos = camera.unproject_position(target_sprite.global_position)
			var camera_pos = camera.global_position
			print("GameManager.gd : Position du TargetSprite : ", target_sprite.global_position, ", Position en écran : ", sprite_screen_pos)
			print("GameManager.gd : Position de la caméra : ", camera_pos)
		else:
			print("GameManager.gd : Aucune caméra principale trouvée")
		
		# Faire tourner la cible
		target_sprite.rotation.y += rotation_speed * delta
	else:
		# Cacher la cible
		target_sprite.visible = false
		# Lister les entités aimables dans la scène
		var aimables = get_tree().get_nodes_in_group("aimables")
		if aimables.is_empty():
			print("GameManager.gd : Aucune entité dans le groupe 'aimables' détectée dans la scène")
		else:
			var aimable_info = aimables.map(func(entity): return entity.name + " (position: " + str(entity.global_position) + ")")
			print("GameManager.gd : Entités dans le groupe 'aimables' : ", aimable_info)

func adapt_sprite_to_entity_size(entity: Node3D) -> void:
	var sprite_size: float = 2.0  # Taille par défaut si aucune taille n'est trouvée
	
	# Vérifier si l'entité a un CollisionShape3D
	var collision_shape = entity.get_node("CollisionShape3D") if entity.has_node("CollisionShape3D") else null
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is BoxShape3D:
			var entity_extents = collision_shape.shape.extents
			# Utiliser la plus grande dimension (x ou z) pour calculer la taille
			sprite_size = max(entity_extents.x, entity_extents.z) * 2.4  # 2.4 pour correspondre à 1.2x les extents (diamètre)
		elif collision_shape.shape is SphereShape3D:
			var entity_radius = collision_shape.shape.radius
			sprite_size = entity_radius * 2.4  # 2.4 pour correspondre à 1.2x le rayon (diamètre)
		elif collision_shape.shape is CylinderShape3D:
			var entity_radius = collision_shape.shape.radius
			sprite_size = entity_radius * 2.4  # 2.4 pour correspondre à 1.2x le rayon (diamètre)
		else:
			# Si la forme n'est pas reconnue, utiliser une taille par défaut
			sprite_size = 2.0
	else:
		# Si aucun CollisionShape3D n'est trouvé, chercher un nœud visuel (comme un MeshInstance3D)
		var mesh_instance = entity.get_node("MeshInstance3D") if entity.has_node("MeshInstance3D") else null
		if mesh_instance and mesh_instance.mesh:
			var aabb = mesh_instance.mesh.get_aabb()
			# Utiliser la plus grande dimension (x ou z) de la boîte englobante
			sprite_size = max(aabb.size.x, aabb.size.z) * 1.2  # 1.2 pour correspondre à la taille visuelle
	
	# S'assurer que la taille n'est ni trop petite ni trop grande
	sprite_size = clamp(sprite_size, 1.0, 2.0)  # Plage de taille à 1.0-2.0
	
	# Appliquer la taille au sprite
	target_sprite.scale = Vector3(sprite_size, sprite_size, sprite_size)

func position_sprite_on_ground(entity: Node3D) -> void:
	# Positionner le RayCast3D au-dessus de l'entité pour détecter le sol
	ground_ray.global_position = entity.global_position + Vector3(0, 2, 0)  # Commencer 2 unités au-dessus
	ground_ray.global_rotation = Vector3.ZERO  # S'assurer qu'il pointe vers le bas
	ground_ray.force_raycast_update()  # Forcer une mise à jour immédiate du RayCast
	
	# Vérifier si le RayCast détecte le sol
	if ground_ray.is_colliding():
		var ground_point = ground_ray.get_collision_point()
		# Positionner le sprite au point de collision avec un léger décalage
		target_sprite.global_position = Vector3(ground_point.x, ground_point.y + 0.01, ground_point.z)
	else:
		# Si aucun sol n'est détecté, position par défaut
		target_sprite.global_position = Vector3(entity.global_position.x, 0.01, entity.global_position.z)
