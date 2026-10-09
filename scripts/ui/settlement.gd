extends Node2D


func _ready() -> void:
	preload("res://scripts/ui/save_exit_button.gd").install(self, $SettlementUI, Vector2(1600, 24))
	$SettlementUI/HomeButton.pressed.connect(_return_home)
	var saved := RunState.room_checkpoint("settlement")
	var settlement: Dictionary = saved.settlement_result if saved.has("settlement_result") else RunState.apply_settlement()
	RunState.checkpoint("settlement", {"settlement_result": settlement})
	var result := str(settlement.get("result", "none"))

	if result == "kept":
		$SettlementUI/Result.text = "约定兑现"
		$SettlementUI/Reaction.text = "这趟答应她的事，你做到了。"
	elif result == "broken":
		$SettlementUI/Result.text = "约定未能兑现"
		$SettlementUI/Reaction.text = "这趟没能做到答应她的事，先回家歇歇。"
	elif result == "act_based":
		$SettlementUI/Result.text = "分层约定已结算"
		$SettlementUI/Reaction.text = "这一趟的经历，小墨会记得。"
	else:
		$SettlementUI/Result.text = "远征结束"
		$SettlementUI/Reaction.text = "一起走过这一趟，回家休息吧。"

	$SettlementUI/Bond.hide()
	$SettlementUI/RunResult.text = "远征通关" if RunState.run_won else "远征失败"
	if SpecialEventManager.has_waiting_events():
		$SettlementUI/Reaction.text += "\n小墨似乎还有话想在回家后对你说。"


func _return_home() -> void:
	RunState.clear_expedition()
	RunState.navigate("home", self)
