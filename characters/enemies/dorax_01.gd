extends Enemy
class_name RangedEnemy

# Constante pour la scène du projectile (non modifiable dans l'éditeur)
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://projectiles/enemy_laser_projectile.tscn")

# Propriétés spécifiques pour un ennemi à distance
@export var ranged_attack_range: float = 10.0  # Portée maximale pour attaquer
@export var ranged_attack_cooldown: float = 2.0  # Temps de recharge entre les tirs
@export var preferred_distance: float = 8.0  # Distance préférée pour rester du joueur
@export var move_speed: float = 5.0  # Vitesse de déplacement
@export var projectile_speed: float = 15.0  # Vitesse des projectiles (réduite pour visibilité)
@export var projectile_damage_min: float = 5.0  # Dégâts minimum du projectile
@export var projectile_damage_max: float = 10.0  # Dégâts maximum du projectile

func _ready() -> void:
	super._ready()  # Appeler la méthode _ready() de la classe parent (Enemy)
	# Surcharger les propriétés héritées
	attack_range = ranged_attack_range
	attack_cooldown = ranged_attack_cooldown
	# Augmenter la vitesse de rotation pour une meilleure réactivité
	rotation_speed = 20.0
	# Assurer que les paramètres du cône de détection sont adaptés
	vision_radius = max(vision_radius, ranged_attack_range)  # Le cône doit couvrir au moins la portée d'attaque
	vision_angle = max(vision_angle, 90.0)  # Champ de vision suffisamment large
	print("RangedEnemy.gd : Initialisé avec portée ", attack_range, ", cooldown ", attack_cooldown)

func _physics_process(delta: float) -> void:
	# Hériter le comportement de base (détection, UI, etc.)
	super._physics_process(delta)
	
	# Si l'ennemi est étourdi, arrêter ici (géré par Enemy.gd)
	if is_stunned:
		return
	
	# Mettre à jour le timer d'attaque
	if attack_timer > 0:
		attack_timer -= delta
	
	# Toujours chercher le joueur le plus proche
	var closest_player = get_closest_player()
	if not closest_player:
		velocity = Vector3.ZERO
		return
	
	# Tourner vers le joueur
	var direction_to_player = (closest_player.global_position - global_position).normalized()
	var target_yaw = atan2(direction_to_player.x, direction_to_player.z) + PI
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	
	# Vérifier si le joueur est dans le cône de détection
	if not target:
		target = get_closest_target()
	
	# Gérer le déplacement et l'attaque
	var distance_to_player = global_position.distance_to(closest_player.global_position)
	var direction = direction_to_player
	
	# Si le joueur est détecté (dans le cône de détection)
	if target:
		# Si trop près, reculer
		if distance_to_player < preferred_distance:
			direction = -direction_to_player
		# Si trop loin, avancer
		elif distance_to_player > attack_range:
			direction = direction_to_player
		# Si dans la plage idéale, ne pas bouger et attaquer
		else:
			direction = Vector3.ZERO
			if attack_timer <= 0:
				attack()
				attack_timer = attack_cooldown
	else:
		# Si le joueur n'est pas détecté, se déplacer vers lui pour le chercher
		direction = direction_to_player
	
	# Appliquer le déplacement
	velocity = direction * move_speed
	move_and_slide()

func attack() -> void:
	# Vérifier que la cible est valide
	if not target or not target.has_method("take_damage"):
		return
	
	# Instancier un projectile
	var projectile = ENEMY_PROJECTILE_SCENE.instantiate()
	get_tree().root.add_child(projectile)
	
	# Positionner le projectile à l'origine de l'ennemi
	projectile.global_position = global_position + Vector3(0, 1.0, 0)  # Légère hauteur pour éviter le sol
	
	# Définir la direction du projectile vers le joueur
	var direction_to_target = (target.global_position - projectile.global_position).normalized()
	projectile.direction = direction_to_target
	
	# Configurer les propriétés du projectile
	projectile.speed = projectile_speed
	projectile.min_damage = projectile_damage_min
	projectile.max_damage = projectile_damage_max
	
	print("RangedEnemy.gd : ", name, " tire un laser vers le joueur")

# Méthode pour trouver le joueur le plus proche (même hors du cône de détection)
func get_closest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var closest_player: Node3D = null
	var closest_distance: float = INF
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	return closest_player
