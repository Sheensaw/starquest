extends CharacterBody3D
class_name Enemy

# Variables exportées pour configuration dans l'éditeur
@export var max_health: float = 100.0  # Points de vie maximum
@export var attack_range: float = 2.0  # Portée d'attaque
@export var attack_damage: float = 10.0  # Dégâts infligés par attaque
@export var attack_cooldown: float = 1.0  # Délai entre les attaques (en secondes)
@export var stun_chance: float = 0.5  # Chance d'être étourdi (50% par défaut)
@export var stun_duration_max: float = 3.0  # Durée maximale de l'étourdissement (en secondes)
@export var health_recovery_amount: float = 20.0  # Quantité de vie récupérée par le joueur lors d'un takedown
@export var vision_radius: float = 15.0  # Rayon du cône de détection (champ visuel, augmenté)
@export var vision_angle: float = 90.0  # Angle du cône de détection en degrés (champ visuel, augmenté)

# Variables pour l'état de l'ennemi
var current_health: float
var target: Node3D = null  # Cible actuelle (par exemple, le joueur)
var attack_timer: float = 0.0  # Timer pour gérer le cooldown d'attaque
var is_stunned: bool = false  # Indique si l'ennemi est étourdi
var stun_duration: float = 0.0  # Temps restant de l'étourdissement

# Variables pour l'affichage de la santé ou de l'étourdissement
var show_health: bool = false  # Contrôle si l'UI doit être visible
var health_display_timer: float = 0.0  # Timer pour gérer la durée d'affichage
const HEALTH_DISPLAY_DURATION: float = 0.2  # Délai avant de masquer l'UI (0.2 seconde)

# Références aux nœuds (placeholders pour personnalisation)
@onready var collision_shape = $CollisionShape3D  # CollisionShape3D pour la taille et la détection
@onready var mesh_instance = $MeshInstance3D  # MeshInstance3D pour l'apparence visuelle
@onready var animation_player = $AnimationPlayer  # AnimationPlayer pour les animations
@onready var canvas_layer = $CanvasLayer  # CanvasLayer pour l'UI 2D
@onready var health_label = $CanvasLayer/HealthLabel  # Label pour la santé
@onready var stun_sprite = $CanvasLayer/TakedownSprite  # AnimatedSprite2D pour l'étourdissement
@onready var takedown_area = $TakedownArea  # Area3D pour la détection du takedown

func _ready() -> void:
	# Initialiser les points de vie
	current_health = max_health
	
	# Ajouter l'ennemi au groupe "enemies"
	add_to_group("enemies")
	
	# Ajouter l'ennemi au groupe "aimables" pour la détection
	add_to_group("aimables")
	
	# Vérifier les nœuds nécessaires
	if not collision_shape:
		push_error("CollisionShape3D manquant pour " + name)
	if not mesh_instance:
		push_warning("MeshInstance3D manquant pour " + name)
	if not animation_player:
		push_warning("AnimationPlayer manquant pour " + name)
	if not canvas_layer:
		push_error("CanvasLayer manquant pour " + name)
	else:
		# Cacher l'UI par défaut
		canvas_layer.hide()
	if not health_label:
		push_error("HealthLabel manquant pour " + name)
	if not stun_sprite:
		push_error("TakedownSprite manquant pour " + name)
	else:
		stun_sprite.visible = false  # Cacher le sprite d'étourdissement par défaut
		if stun_sprite is AnimatedSprite2D:
			stun_sprite.play()  # S'assurer que l'animation est jouée
			# Réduire la taille du TakedownSprite
			stun_sprite.scale = Vector2(0.7, 0.7)
	if not takedown_area:
		push_error("TakedownArea manquant pour " + name)
	else:
		# Désactiver la TakedownArea par défaut
		takedown_area.monitoring = false

func _physics_process(delta: float) -> void:
	# Si l'ennemi est étourdi, gérer le timer d'étourdissement
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0:
			die()  # L'ennemi meurt après la durée d'étourdissement
		# Mettre à jour la position de l'UI même pendant l'étourdissement
		update_ui_position()
		return
	
	# Mettre à jour le timer d'attaque (mais ne pas appeler attack() ici)
	if attack_timer > 0:
		attack_timer -= delta
	
	# Trouver une cible (par exemple, le joueur)
	if not target:
		target = get_closest_target()
	
	# Gérer le timer d'affichage de la santé
	if show_health:
		health_display_timer -= delta
		if health_display_timer <= 0:
			show_health = false
			if canvas_layer:
				canvas_layer.hide()
			else:
				push_error("CanvasLayer est null, impossible de cacher l'UI")
	
	# Mettre à jour l'UI de santé uniquement si elle est visible et que l'ennemi n'est pas étourdi
	if show_health and not is_stunned:
		update_health_ui()
		update_ui_position()

# Méthode pour mettre à jour la position de l'UI (santé et takedown sprite)
func update_ui_position() -> void:
	# Obtenir la caméra principale
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Calculer la position 3D au-dessus de l'ennemi
		var health_position = global_position + Vector3(0, 2.5, 0)  # Hauteur pour le HealthLabel
		var takedown_position = global_position + Vector3(0, 2.5, 0)  # Hauteur pour le TakedownSprite
		# Convertir les positions 3D en positions 2D à l'écran
		var health_screen_pos = camera.unproject_position(health_position)
		var takedown_screen_pos = camera.unproject_position(takedown_position)
		# Positionner le Label
		if health_label:
			health_label.position = health_screen_pos - Vector2(health_label.size.x / 2, health_label.size.y / 2)  # Centrer le Label
		else:
			push_error("HealthLabel est null, impossible de mettre à jour la position")
		# Positionner le sprite d'étourdissement
		if stun_sprite:
			stun_sprite.position = takedown_screen_pos
		else:
			push_error("TakedownSprite est null, impossible de mettre à jour la position")

# Méthode pour mettre à jour l'affichage de la santé
func update_health_ui() -> void:
	# Mettre à jour le texte du Label
	if health_label:
		health_label.text = str(int(current_health))
	else:
		push_error("HealthLabel est null, impossible de mettre à jour le texte")

# Méthode pour trouver la cible la plus proche dans le cône de détection
func get_closest_target() -> Node3D:
	# Direction de l'ennemi (vers l'avant)
	var enemy_forward = -global_transform.basis.z.normalized()
	
	# Trouver le joueur dans le cône de détection
	var nearest_target: Node3D = null
	var nearest_distance: float = vision_radius
	var players = get_tree().get_nodes_in_group("player")
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance <= vision_radius:
			# Vérifier si le joueur est dans le cône
			var direction_to_player = (player.global_position - global_position).normalized()
			var angle_to_player = acos(enemy_forward.dot(direction_to_player))
			var max_angle_radians = deg_to_rad(vision_angle)
			
			if angle_to_player <= max_angle_radians and distance < nearest_distance:
				nearest_target = player
				nearest_distance = distance
	
	return nearest_target

# Méthode pour recevoir des dégâts
func take_damage(damage: float, source: Node = null) -> void:
	# Si l'ennemi est étourdi, ignorer les dégâts (seul un takedown peut le tuer)
	if is_stunned:
		return
	
	# Vérifier la source des dégâts : seuls les projectiles du joueur sont autorisés
	if source != null:
		# Vérifier si la source est un projectile du joueur en utilisant le groupe
		if not source.is_in_group("player_projectiles"):
			return  # Ignorer les dégâts si la source n'est pas un projectile du joueur
	
	# Vérifier si current_health est bien initialisé
	if current_health == null:
		current_health = max_health  # Réinitialiser si nécessaire
	
	# Réduire la santé
	current_health -= damage
	current_health = max(0, current_health)  # Empêcher la santé de devenir négative
	
	# Afficher l'UI de santé lorsqu'un dégât est reçu (sauf si étourdi)
	if not is_stunned:
		show_health = true
		health_display_timer = HEALTH_DISPLAY_DURATION
		if canvas_layer:
			canvas_layer.show()
		else:
			push_error("CanvasLayer est null, impossible d'afficher l'UI")
		if health_label:
			health_label.visible = true
		else:
			push_error("HealthLabel est null, impossible de rendre visible")
		if stun_sprite:
			stun_sprite.visible = false
		else:
			push_error("TakedownSprite est null, impossible de cacher")
	
	# Vérifier si l'ennemi doit être étourdi ou mourir
	if current_health <= 0:
		# Générer une chance aléatoire d'être étourdi
		var random_value = randf()  # Valeur aléatoire entre 0.0 et 1.0
		if random_value < stun_chance:
			# Étourdir l'ennemi
			is_stunned = true
			current_health = 1.0  # Réinitialiser à 1 pour éviter une mort immédiate
			stun_duration = stun_duration_max  # Initialiser le timer d'étourdissement
			# Activer la TakedownArea
			if takedown_area:
				takedown_area.monitoring = true
			else:
				push_error("TakedownArea est null, impossible de l'activer")
			# Afficher l'animation d'étourdissement
			show_health = true
			health_display_timer = HEALTH_DISPLAY_DURATION
			if canvas_layer:
				canvas_layer.show()
			else:
				push_error("CanvasLayer est null, impossible d'afficher l'UI")
			if health_label:
				health_label.visible = false
			else:
				push_error("HealthLabel est null, impossible de cacher")
			if stun_sprite:
				stun_sprite.visible = true
			else:
				push_error("TakedownSprite est null, impossible de rendre visible")
		else:
			# Mourir immédiatement si pas étourdi
			die()

# Méthode appelée à la mort
func die() -> void:
	# Ajouter des points au score du joueur
	var player_node = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
	if player_node and player_node.has_method("add_score"):
		player_node.add_score(10)  # Ajoute 10 points au score (ajustable)
	
	# Désactiver la TakedownArea
	if takedown_area:
		takedown_area.monitoring = false
	else:
		push_error("TakedownArea est null, impossible de le désactiver")
	
	# Supprimer le CanvasLayer lors de la mort
	if canvas_layer:
		canvas_layer.queue_free()
	else:
		push_error("CanvasLayer est null, impossible de le libérer")
	queue_free()  # Supprime l'ennemi de la scène

# Méthode appelée lorsqu'un takedown est effectué
func perform_takedown(player: Node) -> void:
	# Vérifier que l'ennemi est bien étourdi
	if not is_stunned:
		return
	
	# Ajouter de la vie au joueur
	if player and player.has_method("recover_health"):
		player.recover_health(health_recovery_amount)
	
	# Tuer l'ennemi
	die()

# Placeholder : Méthode pour le déplacement (à surcharger dans les sous-classes)
func move_toward_target(delta: float) -> void:
	pass

# Placeholder : Méthode d'attaque (à surcharger dans les sous-classes)
func attack() -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)

# Placeholder : Propriétés personnalisables pour les enfants
var rotation_speed: float = 5.0  # Vitesse de rotation pour s'orienter vers la cible
