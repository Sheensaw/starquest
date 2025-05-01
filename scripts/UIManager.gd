extends CanvasLayer

@onready var health_bar: ProgressBar = $Healthbar
@onready var health_label: Label = $HealthLabel
@onready var score_label: Label = $ScoreLabel
@onready var score_value: Label = $ScoreValue

func _ready() -> void:
	score_label.text = "Score:"
	score_value.text = "0"

func update_health(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	health_label.text = str(int(health))

func update_score(score: int) -> void:
	score_value.text = str(score)
