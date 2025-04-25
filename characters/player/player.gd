extends CharacterBody3D

# Variables exportées pour ajuster les paramètres dans l'éditeur
@export var base_speed: float = 10.0   # Vitesse de base du personnage
@export var strafe_speed: float = 5.0  # Vitesse en mode strafe
@export var gravity: float = 9.8       # Accélération gravitationnelle
@export var rotation_speed: float = 10.0  # Vitesse de rotation de base en radians par seconde
@export var detection_radius: float = 20.0  # Rayon de détection pour le cône
@export var cone_angle: float = 45.0  # Angle du cône de détection (en degrés)
@export var max_health: float = 100.0  # Santé maximale du joueur

# Constantes pour les actions d'input (mode normal)
const INPUT_LEFT = "MoveLeft"
const INPUT_RIGHT = "MoveRight"
const INPUT_TOP = "MoveTop"
const INPUT_DOWN = "MoveDown"
const INPUT_SHOOT = "Shoot"
const INPUT_TAKEDOWN = "Shoot"  # Même input que Shoot

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

# Variables pour la santé et le score
var current_health: float
var score: int = 0

# Gestion des takedowns
var is_in_takedown_area: bool = false  # Indique si le joueur est dans une TakedownArea
var takedown_target: Node = null  # Référence à l'ennemi associé à la TakedownArea

# Référence à l'AnimationTree
@onready var animation_tree = $AnimationTree

# Variables pour le tir
var projectile_scene = preload("res://projectiles/laser_projectile.tscn")  # Chemin de la scène du projectile
var can_shoot: bool = true
var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 0.1  # Intervalle de tir en secondes

# Références au HUD (directement dans la scène du joueur)
@onready var hud: CanvasLayer = $PlayerHUD
@onready var health_bar = $PlayerHUD/Healthbar
@onready var health_label = $PlayerHUD/HealthLabel
@onready var score_label = $PlayerHUD/ScoreLabel
@onready var score_value = $PlayerHUD/ScoreValue

func _ready() -> void:
	# Initialiser la santé
	current_health = max_health
	
	# Vérifier les références au HUD
	if not hud:
		push_error("Player.gd : PlayerHUD non trouvé dans la scène du joueur.")
	if not health_bar:
		push_error("Player.gd : Healthbar non trouvé dans PlayerHUD.")
	if not health_label:
		push_error("Player.gd : HealthLabel non trouvé dans PlayerHUD.")
	if not score_label:
		push_error("Player.gd : ScoreLabel non trouvé dans PlayerHUD.")
	if not score_value:
		push_error("Player.gd : ScoreValue non trouvé dans PlayerHUD.")
	
	# Initialiser l'affichage du HUD
	if health_bar and health_label and score_label and score_value:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_label.text = str(int(current_health))
		score_label.text = "Score:"
		score_value.text = str(score)

func _physics_process(delta: float) -> void:
	# Vérifier si le personnage veut effectuer une action (shoot ou takedown)
	var is_action_pressed = Input.is_action_pressed(INPUT_SHOOT)
	
	# Détection de cible dans un cône
	var detected_entity = get_detected_target()
	if detected_entity:
		if is_action_pressed:
			# Verrouiller la cible et activer le mode strafe
			locked_target = detected_entity
			strafing = true
	else:
		# Sortir du mode strafe si le joueur ne tire plus
		if not is_action_pressed:
			locked_target = null
			strafing = false
	
	# Gérer la transition du mode strafe (même sans cible verrouillée)
	if is_action_pressed:
		strafe_exit_timer = 0.0
		strafing = true
	else:
		if strafing:
			strafe_exit_timer += delta
			if strafe_exit_timer >= STRAFE_EXIT_DELAY:
				strafing = false
				locked_target = null  # Réinitialiser la cible lorsqu'on sort du mode strafe
		else:
			strafe_exit_timer = 0.0
	
	# Vérifier si la cible verrouillée est toujours valide (pas détruite)
	if locked_target and not is_instance_valid(locked_target):
		locked_target = null
		strafing = false
	
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
	was_shooting = is_action_pressed
	
	# Gestion de la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Appliquer le déplacement physique
	move_and_slide()
	
	# Gestion de l'action (takedown ou tir)
	if is_action_pressed:
		if is_in_takedown_area and takedown_target and takedown_target.is_stunned:
			# Prioriser le takedown si le joueur est dans une TakedownArea et que la cible est étourdie
			if takedown_target.has_method("perform_takedown"):
				takedown_target.perform_takedown(self)
				# Réinitialiser les variables de tir pour éviter un tir juste après
				can_shoot = false
				shoot_timer = 0.0
		else:
			# Sinon, tirer un projectile si possible (tir continu autorisé)
			if can_shoot:
				shoot_projectile()
				can_shoot = false
				shoot_timer = 0.0
	
	# Gestion du cooldown de tir pour permettre le tir continu
	if not can_shoot:
		shoot_timer += delta
		if shoot_timer >= SHOOT_INTERVAL:
			can_shoot = true
	
	# Mettre à jour les animations
	update_animations(strafing)

func shoot_projectile():
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	# Ajouter le projectile au groupe "player_projectiles"
	projectile.add_to_group("player_projectiles")
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

# Fonctions pour que GameManager puisse vérifier l'état du joueur
func is_moving() -> bool:
	return velocity.length_squared() > 0.0

func is_in_lock_mode() -> bool:
	return strafing and locked_target

# Méthode pour détecter une cible dans un cône devant le joueur (uniquement les "aimables")
func get_detected_target() -> Node3D:
	# Si en mode strafe avec une cible verrouillée, vérifier si elle est encore dans le cône
	if strafing and locked_target and is_instance_valid(locked_target):
		# Vérifier si la cible verrouillée est encore dans le cône
		var player_forward = -global_transform.basis.z.normalized()
		var distance = global_position.distance_to(locked_target.global_position)
		if distance <= detection_radius:
			var direction_to_entity = (locked_target.global_position - global_position).normalized()
			var angle_to_entity = acos(player_forward.dot(direction_to_entity))
			var max_angle_radians = deg_to_rad(cone_angle)
			if angle_to_entity <= max_angle_radians:
				return locked_target
		# Si la cible n'est plus dans le cône, réinitialiser le ciblage
		locked_target = null
		strafing = false
	
	# Direction du joueur (vers l'avant)
	var player_forward = -global_transform.basis.z.normalized()
	
	# Trouver la cible la plus proche dans le cône
	var nearest_target: Node3D = null
	var nearest_distance: float = detection_radius
	var aimables = get_tree().get_nodes_in_group("aimables")
	
	# Détection uniquement parmi les "aimables"
	for entity in aimables:
		# Vérifier que l'entité est valide (pas détruite)
		if not is_instance_valid(entity):
			continue
		var distance = global_position.distance_to(entity.global_position)
		if distance <= detection_radius:
			# Vérifier si l'entité est dans le cône
			var direction_to_entity = (entity.global_position - global_position).normalized()
			var angle_to_entity = acos(player_forward.dot(direction_to_entity))
			var max_angle_radians = deg_to_rad(cone_angle)
			
			if angle_to_entity <= max_angle_radians and distance < nearest_distance:
				nearest_target = entity
				nearest_distance = distance
	
	return nearest_target

# Méthode pour recevoir des dégâts
func take_damage(damage: float) -> void:
	current_health -= damage
	current_health = clamp(current_health, 0, max_health)
	if health_bar and health_label:
		health_bar.value = current_health
		health_label.text = str(int(current_health))
	if current_health <= 0:
		die()

# Méthode appelée à la mort
func die() -> void:
	queue_free()  # Supprime le joueur (à ajuster selon vos besoins)

# Méthode pour augmenter le score
func add_score(points: int) -> void:
	score += points
	if score_value:
		score_value.text = str(score)

# Méthode pour récupérer de la vie après un takedown
func recover_health(amount: float) -> void:
	current_health += amount
	current_health = clamp(current_health, 0, max_health)
	if health_bar and health_label:
		health_bar.value = current_health
		health_label.text = str(int(current_health))

# Méthodes pour gérer l'entrée/sortie dans une TakedownArea
func _on_area_entered(area: Area3D) -> void:
	if area.name == "TakedownArea":
		var parent = area.get_parent()
		if parent and parent.is_in_group("enemies"):
			is_in_takedown_area = true
			takedown_target = parent

func _on_area_exited(area: Area3D) -> void:
	if area.name == "TakedownArea":
		is_in_takedown_area = false
		takedown_target = null
