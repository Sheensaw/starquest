extends ProgressBar
func update_health(health, max_health):
	value = (float(health) / max_health) * 100
