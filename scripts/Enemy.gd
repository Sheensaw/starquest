extends CharacterBody3D
class_name Enemy

# Propriétés communes
var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false

# Méthodes communes
func _ready() -> void:
	add_to_group("enemies")

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	queue_free()
