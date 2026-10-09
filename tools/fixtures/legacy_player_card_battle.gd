extends "res://scripts/battle/battle.gd"

# Frozen before opportunity and simple player-card migration.

func _play_hand_card(index: int) -> void:
	if index < 0 or index >= hand.size() or not hand_buttons[index].visible:
		return
	if hand[index] == CardType.CURSE:
		message_label.text = "心魔无法打出"
		return
	var played_card := hand[index]
	if (played_card == CardType.FLOWING_CLOUD and flowing_cloud_active) or (played_card == CardType.RETAIN_SHIELD and retain_shield_active) or (played_card == CardType.TUNE_BREATH and tune_breath_used_this_turn):
		return
	var cost := _card_cost(played_card)
	if not _can_pay(cost):
		return
	if played_card in [CardType.ATTACK, CardType.HEAVY_ATTACK, CardType.COMBO_BOOST, CardType.BREAK_EDGE, CardType.UNLOAD_FORCE, CardType.CHASE_WIND, CardType.SHIELD_STRIKE]:
		pending_attack_index = index
		pending_skill_target = 0
		last_target_index = -1
		message_label.text = "请选择一个攻击目标"
		_refresh_ui()
		return

	pending_attack_index = -1
	pending_skill_target = 0
	_commit_hand_card(index)
	match played_card:
		CardType.DEFENSE:
			_play_defense_card(cost, defense_block)
		CardType.STATUS:
			_play_status_card(index, cost)
		CardType.HEAVY_DEFENSE:
			_play_defense_card(cost, heavy_defense_block)
		CardType.SWEEP:
			_play_sweep_card()
		CardType.TUNE_BREATH:
			_play_tune_breath(index)
		CardType.SHADOW_STEP:
			_play_shadow_step(index)
		CardType.HIDE_EDGE:
			_play_hide_edge()
		CardType.FLOWING_CLOUD:
			energy -= cost
			flowing_cloud_active = true
			message_label.text = "行云：本场每回合首次三连攻，抽1张并恢复1精力"
			_finish_action()
		CardType.RETAIN_SHIELD:
			energy -= cost
			retain_shield_active = true
			message_label.text = "留盾：剩余护盾跨回合保留"
			_finish_action()
		CardType.PARRY:
			parry_active = true
			_play_defense_card(cost, CardDatabase.get_number(CardDatabase.PARRY, "block"))
			message_label.text += "；回锋：本轮反击至多%d次" % parry_reaction_limit


func _resolve_targeted_attack(enemy_index: int) -> void:
	var card_index := pending_attack_index
	var card_type := hand[card_index]
	var cost := _card_cost(card_type)
	if not _can_pay(cost):
		return
	pending_attack_index = -1
	last_target_index = enemy_index
	_commit_hand_card(card_index)
	if card_type == CardType.HEAVY_ATTACK:
		_play_attack_card(cost, heavy_attack_base_damage, enemy_index)
	elif card_type == CardType.CHASE_WIND:
		_play_attack_card(cost, CardDatabase.get_number(CardDatabase.CHASE_WIND, "damage"), enemy_index)
	elif card_type == CardType.SHIELD_STRIKE:
		_play_shield_strike_card(cost, enemy_index)
	elif card_type == CardType.COMBO_BOOST:
		_play_combo_boost_card(enemy_index)
	elif card_type == CardType.BREAK_EDGE:
		_play_break_edge_card(enemy_index)
	elif card_type == CardType.UNLOAD_FORCE:
		_play_unload_force_card(enemy_index)
	else:
		_play_attack_card(_card_cost(card_type), attack_base_damage, enemy_index)


func _play_attack_card(cost: int, base_damage: int, target_index: int) -> void:
	energy -= cost
	var damage := base_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	combo += 1
	message_label.text = "攻击敌人%d，造成 %d 伤害，连击 +1" % [target_index + 1, damage]
	_finish_action()


func _play_defense_card(cost: int, block_amount: int) -> void:
	energy -= cost
	_gain_block(block_amount, "player")
	if cut_water_active:
		if combo > 0:
			_use_cooperation_window()
		message_label.text = "获得 %d 格挡；断水生效，连击保留" % block_amount
	else:
		_consume_parry_combo(parry_injected_remaining, "defense")
		combo = 0
		message_label.text = "获得 %d 格挡，连击清零" % block_amount
	_finish_action()


func _play_combo_boost_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.COMBO_BOOST)
	var damage := combo_boost_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	combo += 2
	message_label.text = "叠浪攻击敌人%d，造成 %d 伤害，连击 +2" % [
		target_index + 1,
		damage,
	]
	_finish_action()


func _play_sweep_card() -> void:
	energy -= CardDatabase.get_cost(CardDatabase.SWEEP)
	var damage := sweep_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	for index in range(enemy_hps.size()):
		if enemy_hps[index] > 0:
			_damage_enemy_at(index, damage)
	combo += 1
	last_target_index = -1
	message_label.text = "扫叶对所有敌人造成 %d 伤害，连击 +1" % damage
	_finish_action()


func _play_tune_breath(hand_index: int) -> void:
	tune_breath_used_this_turn = true
	_draw_card_into_slot(hand_index)
	message_label.text = "调息：抽取 1 张牌"
	_finish_action()


func _play_shadow_step(hand_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.SHADOW_STEP)
	var drawn := _draw_cards_into_empty_slots(2, hand_index)
	message_label.text = "掠影：抽取 %d 张牌" % drawn
	_finish_action()


func _finish_action() -> void:
	_resolve_consecutive_attack()
	if not telemetry_action.is_empty():
		combo_telemetry.record_action(int(telemetry_action["card_id"]), int(telemetry_action["cost"]), int(telemetry_action["combo"]), combo, flowing_cloud_active, _visible_wind_count(), RunState.deck.count(CardDatabase.CHASE_WIND))
		telemetry_action.clear()
	if combo == 0 and cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) in [CompanionCards.HEART_RESONANCE]:
		cooperation_windows["resource"]["lost"] = true
	if cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) == CompanionCards.LONG_WIND and energy < int(CompanionCards.get_definition(CompanionCards.LONG_WIND)["energy"]):
		_use_cooperation_window()
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _damage_enemy_at(target_index: int, damage: int, ignore_guard: bool = false) -> void:
	if target_index >= 0:
		if combo > 0 and cooperation_windows.has("resource"):
			var source := str(cooperation_windows["resource"].get("source", ""))
			if source in [CompanionCards.HEART_RESONANCE] and not companion_turn_pending and not bool(cooperation_windows["resource"].get("lost", false)):
				_use_cooperation_window()
		var hp_before := enemy_hps[target_index]
		damage += enemy_vulnerabilities[target_index]
		var absorbed := 0 if ignore_guard else mini(enemy_guards[target_index], damage)
		enemy_guards[target_index] -= absorbed
		enemy_hps[target_index] = maxi(enemy_hps[target_index] - (damage - absorbed), 0)
		battle_damage_dealt += hp_before - enemy_hps[target_index]
		if damage > 0 and hp_before > 0:
			_animate_enemy_hit(target_index)
			if absorbed > 0:
				_enemy_floating_text(target_index, "护盾吸收 %d" % absorbed, Color("#74c7bd"))
			if hp_before > enemy_hps[target_index]:
				_enemy_floating_text(target_index, "-%d 生命" % (hp_before - enemy_hps[target_index]), Color("#f1a292"), 1 if absorbed > 0 else 0)
			if enemy_hps[target_index] == 0:
				_animate_enemy_death(target_index)
		if _is_boss_battle() and hp_before > 0 and damage > 0 and bool(enemy_intents[target_index].get("charging", false)):
			boss_charge_hits += 1
			if boss_charge_hits >= EnemyDatabase.BOSS_INTERRUPT_HITS:
				enemy_intents[target_index]["charging"] = false
				enemy_intents[target_index]["interrupted"] = true
				enemy_intents[target_index]["value"] = mini(int(enemy_intents[target_index]["value"]), int(EnemyDatabase.get_boss_config(RunState.route_layer)["attack"]))
				_enemy_floating_text(target_index, "破势！重斩打断", Color("#f1ce82"), 2)


func _assess_cooperation_window() -> void:
	if not cooperation_windows.has("resource"):
		return
	var attack := false
	var defense := false
	var total_cost := 0
	for card in hand:
		var definition: Dictionary = CardDatabase.get_definition(int(card))
		var cost := _card_cost(card)
		if cost <= energy and card != CardType.CURSE:
			total_cost += cost
			attack = attack or definition.get("type", "") == "攻击"
			defense = defense or card in [CardType.DEFENSE, CardType.HEAVY_DEFENSE, CardType.STATUS]
	var source := str(cooperation_windows["resource"]["source"])
	var available := attack
	if source == CompanionCards.CUT_WATER:
		available = defense and (combo > 0 or attack)
	elif source == CompanionCards.LONG_WIND:
		available = total_cost > max_energy
	elif source in [CompanionCards.HEART_RESONANCE]:
		available = attack and combo > 0
	cooperation_windows["resource"]["available"] = available
