extends Area3D

# Vitesse du projectile
var speed: float = 60.0

# Direction du projectile (par défaut vers l'avant)
var direction: Vector3 = Vector3.FORWARD

# Dégâts infligés par le projectile (aléatoire entre deux bornes)
@export var min_damage: float = 10.0  # Dégâts minimum
@export var max_damage: float = 20.0  # Dégâts maximum
var damage: float

# Points attribués au joueur pour chaque ennemi touché
@export var points_per_hit: int = 5

# Son du tir
var shoot_sound = preload("res://audio/sfx/laser_shoot.wav")

# Durée de vie maximale du projectile (en secondes)
var lifetime: float = 5.0
var time_alive: float = 0.0

# Position initiale pour vérifier la distance parcourue
var initial_position: Vector3

func _ready() -> void:
	# Initialiser les dégâts aléatoires entre min_damage et max_damage
	damage = randf_range(min_damage, max_damage)
	
	# Enregistrer la position initiale
	initial_position = global_position
	
	# Ajouter le projectile au groupe "player_projectiles"
	add_to_group("player_projectiles")
	
	# Vérifier si le signal body_entered est connecté
	if not is_connected("body_entered", _on_body_entered):
		var err = connect("body_entered", _on_body_entered)
		if err != OK:
			push_error("Erreur lors de la connexion du signal body_entered : ", err)
	
	# Créer et jouer le son du tir
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = shoot_sound
	audio_player.autoplay = true
	audio_player.unit_size = 10.0  # Ajuste la portée du son (optionnel)
	add_child(audio_player)

func _physics_process(delta: float) -> void:
	# Déplacer le projectile dans la direction définie
	var motion = direction * speed * delta
	global_position += motion
	
	# Orienter le projectile visuellement dans la direction de son mouvement
	if direction != Vector3.ZERO:
		var target_rotation = atan2(direction.x, direction.z) + PI
		rotation.y = target_rotation
	
	# Mettre à jour le temps de vie
	time_alive += delta
	if time_alive > lifetime:
		queue_free()  # Supprimer le projectile après sa durée de vie maximale
	
	# Vérifier la distance parcourue depuis la position initiale
	var distance_traveled = global_position.distance_to(initial_position)
	if distance_traveled > 100.0:  # Distance maximale arbitraire (ajuste si nécessaire)
		queue_free()  # Supprimer le projectile s'il s'éloigne trop

func _on_body_entered(body: Node) -> void:
	# Vérifier si l'objet touché est un ennemi
	if body.is_in_group("enemies"):
		# Vérifier si l'ennemi a la méthode take_damage
		if body.has_method("take_damage"):
			body.take_damage(damage, self)  # Passer une référence à soi-même comme source
			# Ajouter des points au score du joueur
			var player_node = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
			if player_node and player_node.has_method("add_score"):
				player_node.add_score(points_per_hit)
	# Supprimer le projectile quand il touche un objet
	queue_free()
