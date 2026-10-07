extends "res://scripts/battle/battle.gd"

# 仅用于离线场景标定，不进入正式敌人池。
var calibration_hit := 32
var calibration_multi := false
var calibration_continuous := false

func _roll_enemy_intents() -> void:
	var intent: Dictionary = {"type": EnemyIntent.OTHER, "value": 0}
	if calibration_continuous or battle_turn_count % 2 == 1:
		intent = {"type": EnemyIntent.ATTACK, "value": calibration_hit}
		if calibration_multi:
			var part := calibration_hit / 3
			intent["segments"] = [part, part, calibration_hit - part * 2]
	enemy_intents.assign([intent, {"type": EnemyIntent.OTHER, "value": 0}])
