extends Node2D


func _ready() -> void:
	$SettlementUI/HomeButton.pressed.connect(_return_home)
	var settlement: Dictionary = RunState.apply_settlement()
	var result := str(settlement.get("result", "none"))
	var bond_gain := int(settlement.get("bond_gain", 0))

	if result == "kept":
		$SettlementUI/Result.text = "约定兑现"
		$SettlementUI/Reaction.text = "约定兑现，羁绊 +%d" % bond_gain
	elif result == "broken":
		$SettlementUI/Result.text = "约定未能兑现"
		$SettlementUI/Reaction.text = "约定没有兑现，本次没有约定奖励。"
	elif result == "act_based":
		$SettlementUI/Result.text = "分层约定已结算"
		$SettlementUI/Reaction.text = "每层的守约结果已经分别结算。\n每场战斗羁绊均已即时增加"
	else:
		$SettlementUI/Result.text = "远征结束"
		$SettlementUI/Reaction.text = "本次没有立下约定。\n本场战斗羁绊已增加 2"

	$SettlementUI/Bond.text = "当前羁绊：%d/100　%s" % [
		RunState.bond_value,
		RunState.get_bond_stage_name(),
	]
	$SettlementUI/RunResult.text = "远征通关" if RunState.run_won else "远征失败"
	if SpecialEventManager.has_waiting_events():
		$SettlementUI/Reaction.text += "\n小墨似乎还有话想在回家后对你说。"


func _return_home() -> void:
	if RunState.has_pending_bond_milestone():
		get_tree().change_scene_to_file("res://scenes/relationship_milestone.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
