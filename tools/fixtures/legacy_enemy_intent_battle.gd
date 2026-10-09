extends "res://scripts/battle/battle.gd"

# Frozen pre-refactor planner for deterministic behavior comparison.
func _roll_enemy_intents() -> void:
	if fixed_cooperation_test:
		enemy_intents.assign([{"type": EnemyIntent.ATTACK, "value": 6}, {"type": EnemyIntent.ATTACK, "value": 8}])
		return
	enemy_intents.clear()
	if _is_boss_battle():
		boss_charge_hits = 0
		var action := boss_action_step % 3
		boss_action_step += 1
		if action == 1:
			enemy_intents.append({"type": EnemyIntent.DEFEND, "value": int(EnemyDatabase.get_boss_config(RunState.route_layer)["guard"])})
		else:
			var charging := action == 2
			var enraged := enemy_hps[0] * 2 <= enemy_max_hps[0]
			var damage := int(EnemyDatabase.get_boss_config(RunState.route_layer)["attack"])
			if charging:
				damage = int(EnemyDatabase.get_boss_config(RunState.route_layer)["enraged_heavy"] if enraged else EnemyDatabase.get_boss_config(RunState.route_layer)["heavy"])
			damage = maxi(damage - enemy_attack_reductions[0], 0)
			enemy_attack_reductions[0] = 0
			enemy_intents.append({"type": EnemyIntent.ATTACK, "value": damage, "charging": charging})
		return
	var role_step := enemy_action_step
	enemy_action_step += 1
	for hp in enemy_hps:
		if hp <= 0:
			enemy_intents.append({"type": EnemyIntent.OTHER, "value": 0})
			continue
		var enemy_index := enemy_intents.size()
		if enemy_index < enemy_roles.size():
			var role_intent := EnemyDatabase.get_role_intent(enemy_roles[enemy_index], role_step, RunState.pending_encounter == RunState.EncounterType.ELITE, RunState.route_layer)
			if role_intent["type"] == EnemyIntent.ATTACK:
				AttackSegments.reduce_next(role_intent, enemy_attack_reductions[enemy_index])
				enemy_attack_reductions[enemy_index] = 0
			enemy_intents.append(role_intent)
			continue
		var roll := _enemy_roll(0, 99)
		if roll < EnemyDatabase.INTENT_ATTACK_END:
			enemy_intents.append({
				"type": EnemyIntent.ATTACK,
				"value": maxi(
					_enemy_roll(EnemyDatabase.ATTACK_DAMAGE_MIN, EnemyDatabase.ATTACK_DAMAGE_MAX)
					+ enemy_strengths[enemy_index]
					- enemy_attack_reductions[enemy_index],
					0
				),
			})
			enemy_attack_reductions[enemy_index] = 0
		elif roll < EnemyDatabase.INTENT_DEFEND_END:
			enemy_intents.append({
				"type": EnemyIntent.DEFEND,
				"value": _enemy_roll(EnemyDatabase.DEFENSE_MIN, EnemyDatabase.DEFENSE_MAX),
			})
		elif roll < EnemyDatabase.INTENT_ENHANCE_END:
			enemy_intents.append({"type": EnemyIntent.ENHANCE, "value": EnemyDatabase.STRENGTH_GAIN})
		elif roll < EnemyDatabase.INTENT_CURSE_END:
			enemy_intents.append({"type": EnemyIntent.CURSE, "value": 1})
		else:
			enemy_intents.append({"type": EnemyIntent.OTHER, "value": 0})
