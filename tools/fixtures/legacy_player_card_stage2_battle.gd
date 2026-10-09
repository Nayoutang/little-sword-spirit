extends "res://tools/fixtures/legacy_player_card_battle.gd"

# Frozen special player effects before stage two.

func _play_shield_strike_card(cost: int, target_index: int) -> void:
	energy -= cost
	var base_damage := floori(block * CardDatabase.get_number(CardDatabase.SHIELD_STRIKE, "shield_percent") / 100.0)
	var damage := _apply_pending_boon_to_player_attack(base_damage)
	_damage_enemy_at(target_index, damage)
	combo += 1
	message_label.text = "护盾攻击：以 %d 护盾攻击敌人%d，连击 +1" % [block, target_index + 1]
	_finish_action()


# 兼容既有战斗测试入口，仍走同一效果执行器。


func _play_break_edge_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.BREAK_EDGE)
	var damage := break_edge_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	enemy_vulnerabilities[target_index] += break_edge_vulnerable
	_enemy_floating_text(target_index, "+%d层易伤" % break_edge_vulnerable, Color("#e89584"), 2)
	combo += 1
	message_label.text = "破锋攻击敌人%d，造成 %d 伤害，施加 %d 层易伤，连击 +1" % [
		target_index + 1,
		damage,
		break_edge_vulnerable,
	]
	_finish_action()


func _play_unload_force_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.UNLOAD_FORCE)
	if enemy_intents[target_index]["type"] == EnemyIntent.ATTACK:
		AttackSegments.reduce_next(enemy_intents[target_index], unload_force_reduction)
	else:
		enemy_attack_reductions[target_index] += unload_force_reduction
	message_label.text = "拨千斤：敌人%d下一段攻击伤害降低 %d" % [target_index + 1, unload_force_reduction]
	_finish_action()


func _play_hide_edge() -> void:
	energy -= CardDatabase.get_cost(CardDatabase.HIDE_EDGE)
	_gain_block(hide_edge_block, "player")
	preserve_combo_this_turn = true
	message_label.text = "藏锋：获得 %d 格挡，本回合结束保留连击" % hide_edge_block
	_finish_action()


func _play_status_card(hand_index: int, cost: int) -> void:
	energy -= cost
	if cut_water_active:
		if combo > 0:
			_use_cooperation_window()
		_draw_card_into_slot(hand_index)
		message_label.text = "抽取 1 张牌；断水生效，连击保留"
	else:
		_consume_parry_combo(parry_injected_remaining, "other")
		combo = 0
		_draw_card_into_slot(hand_index)
		message_label.text = "抽取 1 张牌，连击清零"
	_finish_action()


func _on_parry_attack_segment(enemy_index: int, _damage: int, _absorbed: int, _lost: int) -> void:
	if not parry_active or player_hp <= 0 or enemy_hps[enemy_index] <= 0 or parry_reactions >= parry_reaction_limit:
		return
	parry_reactions += 1
	var hp_before := enemy_hps[enemy_index]
	_damage_enemy_at(enemy_index, CardDatabase.get_number(CardDatabase.PARRY, "reaction_damage"))
	battle_parry_damage += hp_before - enemy_hps[enemy_index]
	var reward := 0
	if parry_combo_awards < parry_combo_limit:
		reward = 1
		parry_combo_awards += 1
		parry_pending_combo += 1
	_record_enemy_action({"enemy":enemy_index,"type":"parry","executed":true,"damage":hp_before-enemy_hps[enemy_index],"combo_award":reward,"reaction":parry_reactions})
	if not combo_telemetry.current.is_empty():
		combo_telemetry.current["parry_reactions"] = parry_reactions
		combo_telemetry.current["parry_awarded"] = parry_combo_awards


func _card_cost(card_type: CardType) -> int:
	if card_type == CardType.CHASE_WIND:
		return maxi(CardDatabase.get_cost(int(card_type)) - consecutive_attacks, 0)
	return CardDatabase.get_cost(int(card_type))
