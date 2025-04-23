# Interactable.gd
# Script de base pour objets interactifs, à attacher sur Node3D
extends Node3D
class_name Interactable

signal interacted(by)

func interact(by: Node):
	emit_signal("interacted", by)
