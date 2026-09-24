extends SceneTree

# 运行：Godot --headless --path . --script res://tools/companion_relationship_diff.gd
# 退出码：0=三组全部分叉；1=未完全分叉或请求失败；2=API 配置不完整。

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const CompanionDirector = preload("res://scripts/battle/companion_card_director.gd")

const ARCHIVES := {
	"生疏": {
		"relationship_archive": "当前关系阶段：初遇；羁绊0/100；并肩胜利0次、失利1次；兑现约定0次、失约1次；本趟没有约定。",
		"run_journal": "【整趟远征事实记录】\n1. 上一次远征玩家在危险时拒绝了小墨的提醒，最终战败。",
	},
	"生死之交": {
		"relationship_archive": "当前关系阶段：生死之交；羁绊100/100；并肩胜利12次、失利2次；兑现约定5次、失约0次；本趟约定：玩家会保护好自己。",
		"run_journal": "【整趟远征事实记录】\n1. 本趟出发前，玩家再次答应会保护好自己。\n2. 上一场战斗玩家在小墨铺好剑势后完成了收尾。",
	},
}

const SCENARIOS := [
	{
		"name": "相识：利落 vs 引势",
		"allowed_ids": [CompanionCards.CLEAN_CUT, CompanionCards.LEAD_MOMENTUM],
		"battle": {
			"player_hp": 42, "player_max_hp": 50, "block": 0, "combo": 0,
			"living_enemies": 2, "lowest_enemy_hp": 14, "incoming_damage": 0,
		},
	},
	{
		"name": "交心：回护 vs 拱卫",
		"allowed_ids": [CompanionCards.RETURN_GUARD, CompanionCards.ESCORT],
		"battle": {
			"player_hp": 32, "player_max_hp": 50, "block": 0, "combo": 1,
			"living_enemies": 2, "lowest_enemy_hp": 22, "incoming_damage": 8,
		},
	},
	{
		"name": "生死之交：独断 vs 同心剑鸣",
		"allowed_ids": [CompanionCards.LONE_JUDGMENT, CompanionCards.HEART_RESONANCE],
		"battle": {
			"player_hp": 38, "player_max_hp": 50, "block": 4, "combo": 3,
			"living_enemies": 1, "lowest_enemy_hp": 40, "incoming_damage": 0,
		},
	},
]


func _initialize() -> void:
	call_deferred("_run_diff")


func _run_diff() -> void:
	if LLMConfig.API_URL.is_empty() or LLMConfig.MODEL_NAME.is_empty() or LLMConfig.get_api_key().is_empty():
		printerr("关系选牌 diff 无法运行：LLM API 配置不完整。")
		quit(2)
		return

	print("=== 小墨关系承重卡牌 diff ===")
	var divergent_count := 0
	var completed_count := 0
	for scenario in SCENARIOS:
		print("\n[%s]" % str(scenario["name"]))
		var choices := {}
		for archive_name in ARCHIVES:
			var context: Dictionary = scenario["battle"].duplicate(true)
			context.merge(ARCHIVES[archive_name], true)
			var choice := await CompanionDirector.request_online_choice(
				root,
				context,
				_typed_ids(scenario["allowed_ids"]),
				true
			)
			choices[archive_name] = choice
			if choice.is_empty():
				print("  %-8s ERROR：联网决策失败或 reason 未绑定具体事实" % archive_name)
			else:
				print("  %-8s %-18s %s" % [archive_name, choice["card_id"], choice["reason"]])

		var shallow: Dictionary = choices.get("生疏", {})
		var deep: Dictionary = choices.get("生死之交", {})
		if shallow.is_empty() or deep.is_empty():
			print("  分叉：无法判定")
			continue
		completed_count += 1
		var divergent: bool = str(shallow["card_id"]) != str(deep["card_id"])
		if divergent:
			divergent_count += 1
		print("  分叉：%s" % ("是" if divergent else "否（这对牌需要回炉）"))

	var rate := 0.0 if completed_count == 0 else float(divergent_count) / completed_count * 100.0
	print("\n汇总：完成 %d/%d 组；分叉 %d 组；分叉率 %.1f%%" % [
		completed_count,
		SCENARIOS.size(),
		divergent_count,
		rate,
	])
	quit(0 if completed_count == SCENARIOS.size() and divergent_count == completed_count else 1)


func _typed_ids(values: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in values:
		ids.append(str(value))
	return ids
