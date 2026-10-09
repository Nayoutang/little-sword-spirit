extends "res://scripts/battle/battle.gd"

func _configure_encounter() -> void:
	super._configure_encounter()
	enemy_count = 3
	enemy_hps.append(100)
	enemy_roles.append("swordsman")
	enemy_guards.append(0)
	enemy_strengths.append(0)
	enemy_vulnerabilities.append(0)
	enemy_attack_reductions.append(0)

func _allowed_companion_cards() -> Array[String]:
	return [CompanionCards.TEN_STEPS]
