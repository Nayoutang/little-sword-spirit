extends "res://scripts/battle/battle.gd"

# Frozen pre-migration settlement; compare state, telemetry and result text.
func _apply_companion_card(choice: Dictionary) -> void:
	var card_id := str(choice.get("card_id", CompanionCards.QUICK_SLASH))
	var definition := CompanionCards.get_definition(card_id)
	if definition.is_empty():
		card_id = CompanionCards.QUICK_SLASH
		definition = CompanionCards.get_definition(card_id)
	companion_bonus_action = false
	companion_damage_multiplier = 1
	if int(definition.get("damage", 0)) > 0 and grind_sword_ready:
		companion_damage_multiplier = 2
		grind_sword_ready = false
	var target_index := _lowest_hp_enemy_index()
	var result_text := ""
	var combo_before := combo
	var incoming_before := _enemy_intent_damage_total()
	var block_before := block
	_show_companion_flash(card_id)
	match card_id:
		CompanionCards.GUARD_ECHO:
			var gained_block := int(definition["block"])
			_gain_block(gained_block, "companion")
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.FOLLOW_UP:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			combo += 1
			result_text = "对敌人%d造成 %d 伤害，连击 +1" % [target_index + 1, damage]
		CompanionCards.LEAD_MOMENTUM:
			pending_boon = {
				"type": str(definition["boon_type"]),
				"value": float(definition["boon_value"]),
				"source": str(definition["name"]),
			}
			result_text = "玩家下回合第一张攻击牌伤害 ×%.1f" % float(definition["boon_value"])
		CompanionCards.OATH_GUARD:
			var gained_block := int(definition["block"])
			if RunState.active_promise == "protect":
				gained_block += int(definition["promise_bonus"])
			_gain_block(gained_block, "companion")
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.RETURN_GUARD:
			var gained_block := int(definition["block"])
			_gain_block(gained_block, "companion")
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.ESCORT:
			var gained_block := int(definition["block"])
			_gain_block(gained_block, "companion")
			companion_block_this_turn += gained_block
			pending_boon = {
				"type": str(definition["boon_type"]),
				"value": int(definition["boon_value"]),
				"source": str(definition["name"]),
			}
			result_text = "获得 %d 格挡；玩家下回合第一张攻击牌伤害 +%d" % [
				gained_block,
				int(definition["boon_value"]),
			]
		CompanionCards.LONE_JUDGMENT:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			_consume_parry_combo(parry_injected_remaining, "other")
			combo = 0
			result_text = "对敌人%d造成 %d 伤害，连击清零" % [target_index + 1, damage]
		CompanionCards.HEART_RESONANCE:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			preserve_combo_this_turn = true
			result_text = "对敌人%d造成 %d 伤害，保留连击" % [target_index + 1, damage]
		CompanionCards.FROST_COLD:
			for index in range(enemy_hps.size()):
				if enemy_hps[index] <= 0:
					continue
				_damage_enemy_at(index, int(definition["damage"]) * companion_damage_multiplier)
				if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
					AttackSegments.reduce_each(enemy_intents[index], int(definition["weaken"]))
			last_target_index = -1
			result_text = "对全体敌人各造成 %d 伤害，它们本回合攻击 -%d" % [int(definition["damage"]) * companion_damage_multiplier, int(definition["weaken"])]
		CompanionCards.TEN_STEPS:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
			if target_index >= 0 and enemy_hps[target_index] <= 0:
				companion_bonus_action = _living_enemy_count() > 0
				result_text += "，击杀后立即再释放一次技能"
		CompanionCards.GRIND_SWORD:
			grind_sword_ready = true
			result_text = "积蓄剑势，小墨下次伤害技能伤害翻倍（不叠加）"
		CompanionCards.CUT_WATER:
			cut_water_active = true
			result_text = "玩家下回合防御或状态牌不会清空连击"
		CompanionCards.LONG_WIND:
			long_wind_bonus = int(definition["energy"])
			result_text = "玩家下回合精力 +%d" % long_wind_bonus
		CompanionCards.BEHEAD_LOULAN:
			var highest := _highest_hp_enemy_index()
			var damage := int(definition["damage"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(highest, damage, true)
			last_target_index = highest
			result_text = "无视格挡，对生命最高的敌人%d造成 %d 伤害" % [highest + 1, damage]
		CompanionCards.YIN_MOUNTAIN:
			var strongest := -1
			for index in range(enemy_intents.size()):
				if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
					if strongest < 0 or AttackSegments.total(enemy_intents[index]) > AttackSegments.total(enemy_intents[strongest]):
						strongest = index
			if strongest >= 0:
				var blocked := AttackSegments.total(enemy_intents[strongest])
				AttackSegments.intercept(enemy_intents[strongest])
				result_text = "挡下敌人%d本回合的攻击（%d）" % [strongest + 1, blocked]
			else:
				result_text = "本回合没有敌人要攻击，剑势落空"
		CompanionCards.FEW_RETURN:
			few_return_active = not few_return_used
			result_text = "本回合受到致命伤害时保留1点生命，并免疫剩余伤害" if few_return_active else "本场战斗已救险，不能再次发动"
		_:
			var damage := int(definition["damage"])
			damage *= companion_damage_multiplier
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
	if card_id in [CompanionCards.TEN_STEPS, CompanionCards.LONE_JUDGMENT]:
		RunState.record_cooperation("finishers")
		RunState.record_cooperation("finisher_combo_total", combo_before)
	if (block > block_before and incoming_before > block_before) or (card_id in [CompanionCards.YIN_MOUNTAIN, CompanionCards.FROST_COLD] and _enemy_intent_damage_total() < incoming_before):
		RunState.record_cooperation("guards")
	if CompanionCards.is_investment(card_id) and card_id != CompanionCards.GRIND_SWORD:
		cooperation_windows["resource"] = {"source": card_id, "used": false, "combo": combo}
	companion_last_card_id = card_id
	if str(choice.get("source", "")) == "llm":
		RunState.record_spoken_line(str(choice.get("reason", "")))
	companion_last_reason = str(choice.get("reason", "")).strip_edges()
	companion_last_source = str(choice.get("source", "fallback"))
	RunState.record_companion_card(card_id)
	var companion_name := str(definition["name"])
	battle_companion_card_counts[companion_name] = int(battle_companion_card_counts.get(companion_name, 0)) + 1
	companion_status_label.text = "小墨出牌：%s" % str(definition["name"])
	companion_reason_label.text = "“%s”" % companion_last_reason
	$BattleUI/CompanionPanel/Effect.text = result_text
	message_label.text = "小墨打出「%s」：%s" % [definition["name"], result_text]
	companion_damage_multiplier = 1
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()
