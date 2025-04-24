extends RigidBody3D

# Vitesse du projectile
var speed: float = 40.0

# Direction du projectile (par défaut vers l'avant)
var direction: Vector3 = Vector3.FORWARD

func _physics_process(delta: float) -> void:
	# Déplacer le projectile dans la direction définie
	linear_velocity = direction * speed

func _on_body_entered(body: Node) -> void:
	# Supprimer le projectile quand il touche un objet
	queue_free()
