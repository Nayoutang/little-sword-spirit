extends "res://scripts/battle/battle.gd"

# 不修改：逐动作改造前的合计结算，仅供差分回归。
func _resolve_enemy_turn() -> void:
	combo_telemetry.observe_combo(combo, "companion")
	combo_telemetry.finish_round(_visible_wind_count(), "end_turn")
	# 敌人上一轮获得的格挡在玩家回合结束时消失；本轮防御行动生成的新格挡
	# 会保留到下一个玩家回合。
	for index in range(enemy_guards.size()):
		enemy_guards[index] = 0
	# 上一轮强化只影响当前这轮已经预告的行动，结算前先移除旧强化；
	# 本轮再次使用强化时会重新获得，并影响下一轮。
	for index in range(enemy_strengths.size()):
		enemy_strengths[index] = 0
	var incoming_damage := 0
	var action_messages: Array[String] = []
	for index in range(enemy_hps.size()):
		if enemy_hps[index] <= 0:
			continue
		var intent := enemy_intents[index]
		match intent["type"]:
			EnemyIntent.ATTACK:
				_animate_enemy_action(index, "attack")
				incoming_damage += intent["value"]
				action_messages.append("敌人%d攻击%d" % [index + 1, intent["value"]])
			EnemyIntent.DEFEND:
				var guard_target := index
				if bool(intent.get("support", false)):
					guard_target = _guard_target(index)
				enemy_guards[guard_target] += intent["value"]
				_animate_enemy_action(index, "guard")
				if guard_target != index:
					_enemy_action_effect(guard_target, "guard", Color("#74c7bd"))
				_enemy_floating_text(guard_target, "+%d 护盾" % int(intent["value"]), Color("#74c7bd"))
				action_messages.append("敌人%d为敌人%d提供%d格挡" % [index + 1, guard_target + 1, intent["value"]])
			EnemyIntent.ENHANCE:
				enemy_strengths[index] = intent["value"]
				action_messages.append("敌人%d强化，攻击力+%d" % [index + 1, intent["value"]])
			EnemyIntent.CURSE:
				_animate_enemy_action(index, "curse")
				_enemy_floating_text(index, "心魔 +1", Color("#bf9de8"))
				discard_pile.append(CardType.CURSE)
				action_messages.append("敌人%d往你牌组里塞了一张心魔" % (index + 1))
			EnemyIntent.OTHER:
				action_messages.append("敌人%d观望" % (index + 1))
	# 玩家与小墨均使用本轮易伤，敌方行动结算后统一衰减。
	for index in range(enemy_vulnerabilities.size()):
		enemy_vulnerabilities[index] = maxi(enemy_vulnerabilities[index] - 1, 0)
	var damage_taken := maxi(incoming_damage - block, 0)
	var shield_absorbed := mini(incoming_damage, block)
	if shield_absorbed > 0:
		_player_floating_text("护盾吸收 %d" % shield_absorbed, Color("#74c7bd"), 2)
	var damage_without_companion := maxi(incoming_damage - maxi(block - companion_block_this_turn, 0), 0)
	if (
		not companion_save_recorded
		and companion_block_this_turn > 0
		and damage_without_companion >= player_hp
		and damage_taken < player_hp
	):
		companion_save_recorded = true
		RunState.record_moment("第%d场，敌人那一轮本来足以击倒只剩 %d 血的你，是小墨的格挡替你接住了。" % [
			battle_index, player_hp,
		], 4)
	block = 0
	companion_block_this_turn = 0
	var life_guard_triggered := false
	if (
		damage_taken >= player_hp
		and player_hp > 0
		and few_return_active
		and not few_return_used
	):
		damage_taken = player_hp - 1
		few_return_used = true
		life_guard_triggered = true
		RunState.record_moment("第%d场，本该倒下的那一击，灵剑护主替你留住了最后一口气。" % battle_index, 4)
	player_hp = maxi(player_hp - damage_taken, 0)
	if damage_taken > 0:
		_player_floating_text("-%d 生命" % damage_taken, Color("#e89584"))
		player_status.flash_damage()
	battle_damage_taken += damage_taken
	RunState.player_hp = player_hp
	RunState.record_player_hp()
	energy = max_energy + long_wind_bonus
	long_wind_bonus = 0
	var combo_was_preserved := preserve_combo_this_turn
	if not preserve_combo_this_turn:
		combo = 0
		if false:
			combo = 1
	preserve_combo_this_turn = false
	tune_breath_used_this_turn = false
	consecutive_attacks = 0
	flowing_cloud_triggered = false
	turn_player_cards.clear()
	_discard_remaining_hand()
	_draw_new_hand()
	if player_hp > 0:
		combo_telemetry.begin_round(battle_turn_count + 1, combo, flowing_cloud_active, RunState.get_bond_stage_index() >= ultimate_bond_stage_required, _visible_wind_count())
		combo_telemetry.current["cloud_in_hand"] = _visible_cloud_count()
	_assess_cooperation_window()
	var combo_result := "藏锋生效，保留连击" if combo_was_preserved else "连击清零"
	if not combo_was_preserved and false:
		combo_result = "百折生效，新回合保留1层连击"
	var guard_result := "；护命发动，保留1点生命" if life_guard_triggered else ""
	message_label.text = "敌方行动：%s。受到 %d 伤害，%s%s" % [
		"；".join(action_messages),
		damage_taken,
		combo_result,
		guard_result,
	]
	if player_hp <= 0:
		_end_battle(false)
	else:
		_roll_enemy_intents()
		_refresh_ui()
		_prepare_companion_intent()
