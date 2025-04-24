extends CharacterBody3D
class_name Enemy

# Variables exportées pour configuration dans l'éditeur
@export var max_health: float = 100.0  # Points de vie maximum
@export var move_speed: float = 5.0    # Vitesse de déplacement
@export var attack_range: float = 2.0  # Portée d'attaque
@export var attack_damage: float = 10.0  # Dégâts infligés par attaque
@export var attack_cooldown: float = 1.0  # Délai entre les attaques (en secondes)

# Variables pour l'état de l'ennemi
var current_health: float
var target: Node3D = null  # Cible actuelle (par exemple, le joueur)
var attack_timer: float = 0.0  # Timer pour gérer le cooldown d'attaque

# Références aux nœuds (placeholders pour personnalisation)
@onready var collision_shape = $CollisionShape3D  # CollisionShape3D pour la taille et la détection
@onready var mesh_instance = $MeshInstance3D  # MeshInstance3D pour l'apparence visuelle
@onready var animation_player = $AnimationPlayer  # AnimationPlayer pour les animations

func _ready() -> void:
	# Initialiser les points de vie
	current_health = max_health
	
	# Ajouter l'ennemi au groupe "enemies"
	add_to_group("enemies")
	
	# Vérifier les nœuds nécessaires
	if not collision_shape:
		push_error("CollisionShape3D manquant pour " + name)
	if not mesh_instance:
		push_warning("MeshInstance3D manquant pour " + name)
	if not animation_player:
		push_warning("AnimationPlayer manquant pour " + name)

func _physics_process(delta: float) -> void:
	# Mettre à jour le timer d'attaque
	if attack_timer > 0:
		attack_timer -= delta
	
	# Trouver une cible (par exemple, le joueur)
	if not target:
		target = get_closest_target()
	
	# Si une cible est trouvée, agir
	if target:
		# Se déplacer vers la cible si hors de portée
		if global_position.distance_to(target.global_position) > attack_range:
			move_toward_target(delta)
		else:
			# Attaquer si dans la portée et que le cooldown est terminé
			if attack_timer <= 0:
				attack()
				attack_timer = attack_cooldown

# Placeholder : Méthode pour trouver la cible la plus proche
func get_closest_target() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]  # Par défaut, retourne le premier joueur trouvé

# Placeholder : Méthode pour se déplacer vers la cible
func move_toward_target(delta: float) -> void:
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	# Orienter l'ennemi vers la cible
	if direction.length_squared() > 0:
		var target_yaw = atan2(direction.x, direction.z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

# Placeholder : Méthode d'attaque (à surcharger dans les classes enfants)
func attack() -> void:
	# Par défaut, inflige des dégâts à la cible
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)

# Placeholder : Méthode pour recevoir des dégâts
func take_damage(damage: float) -> void:
	current_health -= damage
	if current_health <= 0:
		die()

# Placeholder : Méthode appelée à la mort
func die() -> void:
	queue_free()  # Supprime l'ennemi de la scène

# Placeholder : Propriétés personnalisables pour les enfants
var rotation_speed: float = 5.0  # Vitesse de rotation pour s'orienter vers la cible
