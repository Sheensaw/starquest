extends CharacterBody3D
class_name Player

# Variables exportées pour ajuster les paramètres dans l'éditeur
@export var base_speed: float = 10.0   # Vitesse de base du personnage
@export var strafe_speed: float = 5.0  # Vitesse en mode strafe
@export var gravity: float = 9.8       # Accélération gravitationnelle
@export var rotation_speed: float = 10.0  # Vitesse de rotation de base en radians par seconde
@export var detection_radius: float = 10.0  # Rayon de détection pour le cône
@export var cone_angle: float = 30.0  # Angle du cône de détection (en degrés)

# Constantes pour les actions d'input (mode normal)
const INPUT_LEFT = "MoveLeft"
const INPUT_RIGHT = "MoveRight"
const INPUT_TOP = "MoveTop"
const INPUT_DOWN = "MoveDown"
const INPUT_SHOOT = "Shoot"

# Constantes pour les actions de strafe
const STRAFE_LEFT = "StrafeLeft"
const STRAFE_RIGHT = "StrafeRight"
const STRAFE_TOP = "StrafeTop"
const STRAFE_DOWN = "StrafeDown"

# Variables pour gérer l'état du personnage
var locked_yaw: float = 0.0        # Rotation verrouillée en mode strafe
var was_shooting: bool = false     # État précédent du tir
var target_yaw: float = 0.0        # Angle de rotation cible
var locked_target: Node3D = null   # Cible verrouillée pour le strafe

# Variable pour contrôler les transitions d'animation
var strafing: bool = false

# Timer pour le délai de sortie du mode strafe
var strafe_exit_timer: float = 0.0
const STRAFE_EXIT_DELAY: float = 0.1  # Délai en secondes

# Référence à l'AnimationTree
@onready var animation_tree = $AnimationTree

# Variables pour le tir
var projectile_scene = preload("res://projectiles/laser_projectile.tscn")  # Chemin de la scène du projectile
var can_shoot: bool = true
var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 0.1  # Intervalle de tir en secondes

# Références au RayCast3D pour détecter le sol
@onready var surface_ray = $SurfaceDetector  # RayCast3D pour détecter le sol

func _ready() -> void:
	# Vérifier l'initialisation du RayCast3D pour le sol
	if surface_ray == null:
		print("Erreur : SurfaceDetector (surface_ray) non trouvé dans la scène !")
	else:
		print("SurfaceDetector (surface_ray) correctement initialisé")

func _physics_process(delta: float) -> void:
	# Vérifier si le personnage tire
	var is_shooting = Input.is_action_pressed(INPUT_SHOOT)
	
	# Détection de cible dans un cône
	var detected_entity = get_detected_enemy()
	if detected_entity:
		print("Ennemi détecté dans le cône : ", detected_entity.name)
		if is_shooting:
			# Verrouiller la cible et activer le mode strafe
			locked_target = detected_entity
			strafing = true
			print("Cible verrouillée : ", locked_target.name, " | Mode strafe activé")
	else:
		# Sortir du mode strafe si le joueur ne tire plus
		if not is_shooting:
			if locked_target:
				print("Tir arrêté, cible déverrouillée : ", locked_target.name)
			locked_target = null
			strafing = false
	
	# Gérer la transition du mode strafe (même sans cible verrouillée)
	if is_shooting:
		strafe_exit_timer = 0.0
		strafing = true
	else:
		if strafing:
			strafe_exit_timer += delta
			if strafe_exit_timer >= STRAFE_EXIT_DELAY:
				strafing = false
		else:
			strafe_exit_timer = 0.0
	
	# Déterminer la vitesse actuelle en fonction du mode
	var current_speed = strafe_speed if strafing else base_speed
	
	# Récupérer le vecteur d'input en fonction du mode
	var input_dir_2d
	if not strafing:
		# Mode normal : déplacements standards
		input_dir_2d = Input.get_vector(INPUT_LEFT, INPUT_RIGHT, INPUT_TOP, INPUT_DOWN)
	else:
		# Mode strafe : déplacements spécifiques au strafe
		input_dir_2d = Input.get_vector(STRAFE_LEFT, STRAFE_RIGHT, STRAFE_TOP, STRAFE_DOWN)
	
	# Normaliser le vecteur d'input si nécessaire
	if input_dir_2d.length_squared() > 0.0:
		input_dir_2d = input_dir_2d.normalized()
	
	# Convertir l'input 2D en vecteur 3D pour le mouvement
	var input_dir = Vector3(input_dir_2d.x, 0, input_dir_2d.y)
	
	# Déterminer la vitesse de rotation en fonction du mode
	var current_rotation_speed = 100.0 if (strafing and locked_target) else rotation_speed
	
	# Gestion de la rotation et du mouvement
	if strafing and locked_target:
		# Mode STRAFE avec cible verrouillée : s'orienter vers la cible
		var direction_to_target = (locked_target.global_position - global_position).normalized()
		# Correction : ajouter PI pour inverser la direction et faire face à l'ennemi
		locked_yaw = atan2(direction_to_target.x, direction_to_target.z) + PI
		rotation.y = lerp_angle(rotation.y, locked_yaw, current_rotation_speed * delta)
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.z * current_speed
	elif not strafing:
		# Mode NORMAL : orientation basée sur l'input
		if input_dir.length_squared() > 0.0:
			target_yaw = atan2(input_dir.x, input_dir.z) + PI
			rotation.y = lerp_angle(rotation.y, target_yaw, current_rotation_speed * delta)
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.z * current_speed
	else:
		# Mode STRAFE sans cible : rotation verrouillée + déplacement
		if not was_shooting:
			locked_yaw = rotation.y
		rotation.y = locked_yaw
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.z * current_speed
	
	# Mettre à jour l'état précédent du tir
	was_shooting = is_shooting
	
	# Gestion de la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Appliquer le déplacement physique
	move_and_slide()
	
	# Gestion du tir
	if is_shooting and can_shoot:
		shoot_projectile()
		can_shoot = false
		shoot_timer = 0.0
	else:
		if not can_shoot:
			shoot_timer += delta
			if shoot_timer >= SHOOT_INTERVAL:
				can_shoot = true
		else:
			can_shoot = true
	
	# Mettre à jour les animations
	update_animations(strafing)
	
	# Ajuster la position du décal avec le RayCast3D (pour le GameManager)
	adjust_decal_with_raycast()

func shoot_projectile():
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_transform = $ProjectileLocation.global_transform
	projectile.direction = -global_transform.basis.z.normalized()

func update_animations(is_strafing: bool) -> void:
	var local_velocity = global_transform.basis.inverse() * velocity
	var move_vector = Vector2(local_velocity.x, local_velocity.z).normalized() if velocity.length_squared() > 0.0 else Vector2.ZERO
	
	if not is_strafing:
		var move_speed = velocity.length() / base_speed
		animation_tree.set("parameters/Normal/blend_position", move_speed)
	else:
		animation_tree.set("parameters/Strafe/blend_position", move_vector)

func adjust_decal_with_raycast() -> void:
	# Ne manipule plus directement la flèche, mais transmet les données au GameManager
	if surface_ray != null and surface_ray.is_colliding():
		var collision_point = surface_ray.get_collision_point()
		var normal = surface_ray.get_collision_normal()
		var angle = acos(normal.dot(Vector3.DOWN))
		var scale_factor = 1.0 / cos(angle) if cos(angle) != 0 else 1.0
		# Stocker les données dans des variables d'instance accessibles
		get_node("/root/GameManager").update_arrow_position(collision_point + Vector3(0, 0.01, 0), Vector3(scale_factor, 1.0, scale_factor))
	else:
		if surface_ray == null:
			print("RayCast (surface_ray) est null, vérifiez la scène !")

# Fonctions pour que GameManager puisse vérifier l'état du joueur
func is_moving() -> bool:
	return velocity.length_squared() > 0.0

func is_in_lock_mode() -> bool:
	return strafing and locked_target

# Méthode pour détecter un ennemi dans un cône devant le joueur
func get_detected_enemy() -> Node3D:
	if strafing and locked_target:
		# Si en mode strafe avec une cible verrouillée, retourner cette cible
		return locked_target
	
	# Direction du joueur (vers l'avant)
	var player_forward = -global_transform.basis.z.normalized()
	
	# Trouver l'ennemi le plus proche dans le cône
	var nearest_enemy: Node3D = null
	var nearest_distance: float = detection_radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= detection_radius:
			# Vérifier si l'ennemi est dans le cône
			var direction_to_enemy = (enemy.global_position - global_position).normalized()
			var angle_to_enemy = acos(player_forward.dot(direction_to_enemy))
			var max_angle_radians = deg_to_rad(cone_angle)
			
			if angle_to_enemy <= max_angle_radians and distance < nearest_distance:
				nearest_enemy = enemy
				nearest_distance = distance
	
	return nearest_enemy
