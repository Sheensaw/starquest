extends Area3D

# Vitesse du projectile
var speed: float = 60.0

# Direction du projectile (par défaut vers l'avant)
var direction: Vector3 = Vector3.FORWARD

# Dégâts infligés par le projectile (aléatoire entre deux bornes)
@export var min_damage: float = 10.0  # Dégâts minimum
@export var max_damage: float = 20.0  # Dégâts maximum
var damage: float

# Son du tir
var shoot_sound = preload("res://audio/sfx/laser_shoot.wav")

func _ready() -> void:
	# Initialiser les dégâts aléatoires entre min_damage et max_damage
	damage = randf_range(min_damage, max_damage)
	
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

func _on_body_entered(body: Node) -> void:
	# Vérifier si l'objet touché est un joueur
	if body.is_in_group("player"):
		# Vérifier si le joueur a la méthode take_damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
	# Supprimer le projectile quand il touche un objet
	queue_free()
