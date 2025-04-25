extends CanvasLayer

@onready var score_value: Label = $MarginContainer2/ScoreValue2
@onready var health_bar: ProgressBar = $MarginContainer2/ProgressBar2

func _ready() -> void:
	# Vérifier les références et afficher leur état
	if not score_value:
		push_error("HUDPlayer.gd : ScoreValue2 non trouvé.")
	else:
		print("HUDPlayer.gd : ScoreValue2 trouvé : ", score_value.name)
		# Vérifier la visibilité et les propriétés initiales
		print("HUDPlayer.gd : ScoreValue2 visible : ", score_value.visible)
		print("HUDPlayer.gd : ScoreValue2 text : ", score_value.text)
	if not health_bar:
		push_error("HUDPlayer.gd : ProgressBar2 non trouvé.")
	else:
		print("HUDPlayer.gd : ProgressBar2 trouvé : ", health_bar.name)
		# Initialiser la barre de santé avec des valeurs par défaut
		health_bar.max_value = 100.0
		health_bar.value = 100.0
		# Vérifier la visibilité et les valeurs initiales
		print("HUDPlayer.gd : ProgressBar2 visible : ", health_bar.visible)
		print("HUDPlayer.gd : ProgressBar2 max_value : ", health_bar.max_value, ", value : ", health_bar.value)
	# Initialiser le score à 0
	if score_value:
		score_value.text = "0"

# Méthode pour mettre à jour le score
func update_score(new_score: int) -> void:
	if score_value:
		score_value.text = str(new_score)
		print("HUDPlayer.gd : Score mis à jour à ", new_score, ", text : ", score_value.text)
	else:
		print("HUDPlayer.gd : ScoreValue2 est null, impossible de mettre à jour le score")

# Méthode pour mettre à jour la santé
func update_health(health: float, max_health: float) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		print("HUDPlayer.gd : Santé mise à jour - valeur : ", health, ", max : ", max_health, ", ProgressBar value : ", health_bar.value)
	else:
		print("HUDPlayer.gd : ProgressBar2 est null, impossible de mettre à jour la santé")
