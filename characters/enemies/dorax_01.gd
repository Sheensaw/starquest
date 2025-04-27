extends Enemy
class_name RangedEnemy

# Constante pour la scène du projectile (non modifiable dans l'éditeur)
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://projectiles/enemy_laser_projectile.tscn")

# Propriétés spécifiques pour un ennemi à distance
@export var ranged_attack_range: float = 10.0  # Portée maximale pour attaquer
@export var ranged_attack_cooldown: float = 2.0  # Temps de recharge entre les tirs (base)
@export var preferred_distance: float = 8.0  # Distance préférée pour rester du joueur
@export var move_speed: float = 5.0  # Vitesse de déplacement
@export var projectile_speed: float = 15.0  # Vitesse des projectiles (réduite pour visibilité)
@export var projectile_damage_min: float = 5.0  # Dégâts minimum du projectile
@export var projectile_damage_max: float = 10.0  # Dégâts maximum du projectile

# Propriétés pour l'esquive
@export var dodge_speed: float = 7.0  # Vitesse de déplacement lors de l'esquive
@export var dodge_cooldown: float = 3.0  # Temps de recharge entre deux esquives

# Propriétés pour les rafales
@export var burst_count: int = 3  # Nombre de projectiles dans une rafale
@export var burst_interval: float = 0.2  # Intervalle entre les tirs d'une rafale

# Propriétés pour le comportement à faible santé
@export var low_health_threshold: float = 30.0  # Seuil de santé faible pour un comportement défensif

# Propriétés pour l'utilisation des couvertures
@export var cover_search_radius: float = 10.0  # Rayon pour chercher une couverture
@export var cover_attack_cooldown_modifier: float = 1.5  # Multiplicateur du cooldown d'attaque derrière une couverture

# Propriétés pour la coopération
@export var cooperation_radius: float = 15.0  # Rayon pour détecter les autres ennemis et coopérer
@export var distraction_distance: float = 5.0  # Distance à laquelle un ennemi distrayant s'approche du joueur

# Références aux nœuds
@onready var projectile_location: Marker3D = $ProjectileLocation
@onready var animation_tree = $AnimationTree  # Référence à l'AnimationTree (identique à celui du joueur)

# Variables pour gérer l'esquive et les rafales
var dodge_timer: float = 0.0  # Timer pour gérer le cooldown d'esquive
var is_dodging: bool = false  # Indique si l'ennemi est en train d'esquiver
var dodge_direction: Vector3 = Vector3.ZERO  # Direction de l'esquive
var burst_timer: float = 0.0  # Timer pour gérer les rafales
var current_burst_count: int = 0  # Compteur de projectiles dans la rafale actuelle

# Variables pour gérer les couvertures
var target_cover: Node3D = null  # Couverture ciblée
var is_at_cover: bool = false  # Indique si l'ennemi est à une couverture

# Variables pour la coopération
var is_distracting: bool = false  # Indique si cet ennemi joue le rôle de "distrayant"

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
	
	# Vérifier l'initialisation du Marker3D et de l'AnimationTree
	if not projectile_location:
		push_error("RangedEnemy.gd : ProjectileLocation non trouvé dans la scène de l'ennemi.")
	if not animation_tree:
		push_error("RangedEnemy.gd : AnimationTree non trouvé dans la scène de l'ennemi.")

func _physics_process(delta: float) -> void:
	# Hériter le comportement de base (détection, UI, etc.)
	super._physics_process(delta)
	
	# Si l'ennemi est étourdi, arrêter ici (géré par Enemy.gd)
	if is_stunned:
		return
	
	# Mettre à jour les timers
	if attack_timer > 0:
		attack_timer -= delta
	if dodge_timer > 0:
		dodge_timer -= delta
	if is_dodging:
		burst_timer = 0.0  # Interrompre la rafale pendant l'esquive
	else:
		if burst_timer > 0:
			burst_timer -= delta
			if burst_timer <= 0 and current_burst_count > 0:
				fire_projectile()
				current_burst_count -= 1
				if current_burst_count > 0:
					burst_timer = burst_interval
	
	# Toujours chercher le joueur le plus proche
	var closest_player = get_closest_player()
	if not closest_player or not is_instance_valid(closest_player):
		velocity = Vector3.ZERO
		return
	
	# Tourner vers le joueur
	var direction_to_player = (closest_player.global_position - global_position).normalized()
	var target_yaw = atan2(direction_to_player.x, direction_to_player.z) + PI
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	
	# Vérifier si le joueur est dans le cône de détection
	if not target or not is_instance_valid(target):
		target = get_closest_target()
	
	# Gérer la coopération avec les autres ennemis
	manage_cooperation()
	
	# Gérer le déplacement et l'attaque
	var distance_to_player = global_position.distance_to(closest_player.global_position)
	var direction = direction_to_player
	
	# Détecter les projectiles du joueur à proximité pour esquiver
	var should_dodge = false
	if dodge_timer <= 0:
		var nearby_projectiles = get_nearby_projectiles()
		if nearby_projectiles.size() > 0:
			should_dodge = true
			is_dodging = true
			dodge_timer = dodge_cooldown
			# Calculer une direction d'esquive (perpendiculaire à la direction du joueur)
			var perpendicular = Vector3(-direction_to_player.z, 0, direction_to_player.x).normalized()
			dodge_direction = perpendicular if randf() > 0.5 else -perpendicular
	
	# Gérer le comportement en fonction de la santé
	var is_low_health = current_health <= low_health_threshold
	
	# Chercher une couverture si nécessaire
	if not target_cover or not is_instance_valid(target_cover):
		target_cover = find_nearest_cover()
	is_at_cover = false
	if target_cover and is_instance_valid(target_cover):
		var distance_to_cover = global_position.distance_to(target_cover.global_position)
		if distance_to_cover < 1.0:  # Considéré comme "à la couverture" si très proche
			is_at_cover = true
	
	# Déterminer le comportement de déplacement
	if is_dodging:
		# Esquiver un projectile
		direction = dodge_direction
		velocity = direction * dodge_speed
		# Arrêter l'esquive après un court délai (par exemple, 0.5 seconde)
		if dodge_timer <= dodge_cooldown - 0.5:
			is_dodging = false
	else:
		if target and is_instance_valid(target):
			# Si santé faible, s'éloigner davantage
			if is_low_health:
				direction = -direction_to_player
			else:
				if is_distracting:
					# Rôle de "distrayant" : se rapprocher du joueur
					if distance_to_player > distraction_distance:
						direction = direction_to_player
					else:
						direction = Vector3.ZERO
						if attack_timer <= 0 and burst_timer <= 0:
							start_burst()
							# Ajouter une variation aléatoire au cooldown d'attaque
							attack_timer = attack_cooldown * randf_range(0.8, 1.2)
				else:
					# Si derrière une couverture, rester immobile et attaquer
					if is_at_cover:
						direction = Vector3.ZERO
						if attack_timer <= 0 and burst_timer <= 0:
							start_burst()
							# Appliquer le modificateur de cooldown derrière une couverture
							attack_timer = attack_cooldown * cover_attack_cooldown_modifier * randf_range(0.8, 1.2)
					else:
						# Si une couverture est disponible, se déplacer vers elle
						if target_cover and is_instance_valid(target_cover):
							direction = (target_cover.global_position - global_position).normalized()
						else:
							# Si trop près, reculer
							if distance_to_player < preferred_distance:
								direction = -direction_to_player
							# Si trop loin, avancer
							elif distance_to_player > attack_range:
								direction = direction_to_player
							# Si dans la plage idéale, ne pas bouger et attaquer
							else:
								direction = Vector3.ZERO
								if attack_timer <= 0 and burst_timer <= 0:
									start_burst()
									# Ajouter une variation aléatoire au cooldown d'attaque
									attack_timer = attack_cooldown * randf_range(0.8, 1.2)
		else:
			# Si le joueur n'est pas détecté, se déplacer vers lui pour le chercher
			direction = direction_to_player
		velocity = direction * move_speed
	
	# Appliquer le déplacement
	move_and_slide()
	
	# Mettre à jour les animations
	update_animations()

# Méthode pour mettre à jour les animations (compatible avec l'AnimationTree du joueur, mais avec des animations uniques)
func update_animations() -> void:
	var local_velocity = global_transform.basis.inverse() * velocity
	var move_vector = Vector2(local_velocity.x, local_velocity.z).normalized() if velocity.length_squared() > 0.0 else Vector2.ZERO
	
	# Utiliser le mode "strafe" pour l'esquive ou lorsqu'à une couverture et en train de tirer
	var is_strafing = is_dodging or (is_at_cover and attack_timer > 0)
	
	if not is_strafing:
		var move_speed = velocity.length() / move_speed  # Normaliser par move_speed (similaire à base_speed du joueur)
		animation_tree.set("parameters/Normal/blend_position", move_speed)
	else:
		animation_tree.set("parameters/Strafe/blend_position", move_vector)

# Méthode pour détecter les projectiles du joueur à proximité
func get_nearby_projectiles() -> Array:
	var nearby_projectiles = []
	var projectiles = get_tree().get_nodes_in_group("player_projectiles")
	for projectile in projectiles:
		if not is_instance_valid(projectile):
			continue
		var distance = global_position.distance_to(projectile.global_position)
		if distance < 5.0:  # Ajuste ce seuil selon tes besoins
			nearby_projectiles.append(projectile)
	return nearby_projectiles

# Méthode pour trouver la couverture la plus proche
func find_nearest_cover() -> Node3D:
	var covers = get_tree().get_nodes_in_group("cover")
	if covers.is_empty():
		return null
	
	var nearest_cover: Node3D = null
	var nearest_distance: float = cover_search_radius
	for cover in covers:
		if not is_instance_valid(cover):
			continue
		var distance = global_position.distance_to(cover.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_cover = cover
	return nearest_cover

# Méthode pour gérer la coopération avec les autres ennemis
func manage_cooperation() -> void:
	# Trouver les autres RangedEnemy à proximité
	var nearby_enemies = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy == self or not enemy is RangedEnemy or not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < cooperation_radius:
			nearby_enemies.append(enemy)
	
	# Décider du rôle (distrayant ou tireur)
	if nearby_enemies.size() > 0:
		# Vérifier si un autre ennemi est déjà distrayant
		var has_distractor = false
		for enemy in nearby_enemies:
			if enemy.is_distracting:
				has_distractor = true
				break
		
		# Si aucun distrayant, devenir distrayant si plus proche du joueur
		if not has_distractor:
			var closest_enemy = self
			var closest_distance = global_position.distance_to(target.global_position) if target and is_instance_valid(target) else INF
			for enemy in nearby_enemies:
				var dist = enemy.global_position.distance_to(enemy.target.global_position) if enemy.target and is_instance_valid(enemy.target) else INF
				if dist < closest_distance:
					closest_distance = dist
					closest_enemy = enemy
			is_distracting = (closest_enemy == self)
		else:
			is_distracting = false
	else:
		is_distracting = false

# Méthode pour démarrer une rafale de tirs
func start_burst() -> void:
	current_burst_count = burst_count
	burst_timer = burst_interval
	fire_projectile()
	current_burst_count -= 1

# Méthode pour tirer un projectile individuel
func fire_projectile() -> void:
	# Vérifier que la cible est valide
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	
	# Vérifier que le Marker3D existe
	if not projectile_location:
		return
	
	# Instancier un projectile
	var projectile = ENEMY_PROJECTILE_SCENE.instantiate()
	get_tree().root.add_child(projectile)
	
	# Positionner le projectile à l'emplacement du Marker3D
	projectile.global_transform = projectile_location.global_transform
	
	# Définir la direction du projectile vers le joueur
	var direction_to_target = (target.global_position - projectile_location.global_position).normalized()
	projectile.direction = direction_to_target
	
	# Configurer les propriétés du projectile
	projectile.speed = projectile_speed
	projectile.min_damage = projectile_damage_min
	projectile.max_damage = projectile_damage_max

# Méthode pour trouver le joueur le plus proche (même hors du cône de détection)
func get_closest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var closest_player: Node3D = null
	var closest_distance: float = INF
	for player in players:
		if not is_instance_valid(player):
			continue
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	return closest_player
