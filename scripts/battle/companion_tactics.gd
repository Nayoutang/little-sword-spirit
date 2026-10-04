class_name CompanionTactics
extends RefCounted

const Cards = preload("res://scripts/data/companion_card_database.gd")


static func interruption_prevention(context: Dictionary, card_id: String) -> int:
	if not bool(context.get("boss_charging", false)) or int(Cards.get_definition(card_id).get("damage", 0)) <= 0:
		return 0
	if int(context.get("boss_hits", 0)) + 1 < int(context.get("boss_hit_required", 3)):
		return 0
	return maxi(int(context.get("boss_attack_value", 0)) - int(context.get("boss_interrupted_damage", 8)), 0)


static func cooperation_plan(context: Dictionary, card_id: String) -> Dictionary:
	if card_id == Cards.GRIND_SWORD and (int(context.get("combo", 0)) > 0 or bool(context.get("can_build_combo", false))):
		return {"kind": "preserve_combo"}
	if not bool(context.get("boss_charging", false)) or int(Cards.get_definition(card_id).get("damage", 0)) <= 0:
		return {}
	var player_hits := maxi(int(context.get("boss_hit_required", 3)) - int(context.get("boss_hits", 0)) - 1, 0)
	if player_hits > int(context.get("affordable_attack_hits", 0)):
		return {}
	return {"kind": "boss_interrupt", "required_total": int(context.get("boss_hit_required", 3)), "companion_hits": 1}

# 只过滤当前没有用途或不能覆盖致命伤害的选择；不要求选数学最优牌。
static func candidates(context: Dictionary, allowed: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var hp := int(context.get("player_hp", 0))
	var threat := maxi(int(context.get("incoming_damage", 0)) - int(context.get("block", 0)), 0)
	var combo := int(context.get("combo", 0))
	var can_build := bool(context.get("can_build_combo", false))
	for id in allowed:
		var d: Dictionary = Cards.get_definition(id)
		var shield := int(d.get("block", 0))
		if id == Cards.FEW_RETURN:
			shield = int(d.get("block_low", 0)) if hp * 4 <= int(context.get("player_max_hp", 1)) else shield
		if id == Cards.OATH_GUARD and context.get("active_promise", "") == "protect":
			shield += int(d.get("promise_bonus", 0))
		if id == Cards.YIN_MOUNTAIN:
			shield = int(context.get("strongest_attack", 0))
		if id == Cards.FROST_COLD:
			shield = int(context.get("frost_prevention", 0))
		var damage := int(d.get("damage", 0)) + combo * int(d.get("combo_scale", 0))
		if id == Cards.GRIND_SWORD:
			damage = 0
		var kill := damage >= int(context.get("lowest_enemy_effective_hp", 999999))
		if id == Cards.BEHEAD_LOULAN:
			kill = damage >= int(context.get("highest_enemy_effective_hp", 999999))
		var remaining_threat := maxi(threat - interruption_prevention(context, id), 0)
		if remaining_threat >= hp and shield < remaining_threat - hp + 1 and not (kill and int(context.get("living_enemies", 0)) == 1):
			continue
		if shield > 0 and threat == 0 and not Cards.is_investment(id):
			continue
		if id == Cards.YIN_MOUNTAIN and threat == 0:
			continue
		if id == Cards.GRIND_SWORD and combo == 0 and not can_build:
			continue
		if int(d.get("combo_scale", 0)) > 0 and combo == 0 and not can_build:
			continue
		result.append(id)
	return result

static func choose(context: Dictionary, options: Array[String]) -> Dictionary:
	if options.is_empty():
		return {}
	var memory: Dictionary = context.get("cooperation", {})
	var used := float(memory.get("opportunities_used", 0))
	var wasted := float(memory.get("opportunities_wasted", 0))
	var confidence := (used + 2.0) / (used + wasted + 3.0)
	var finishers := float(memory.get("finishers", 0))
	var average_combo := float(memory.get("finisher_combo_total", 0)) / maxf(finishers, 1.0)
	var guard_history := float(memory.get("guards", 0))
	var threat := maxi(int(context.get("incoming_damage", 0)) - int(context.get("block", 0)), 0)
	var best := options[0]
	var best_score := -INF
	for id in options:
		var d: Dictionary = Cards.get_definition(id)
		var damage := float(d.get("damage", 0)) + int(context.get("combo", 0)) * float(d.get("combo_scale", 0))
		var score := damage
		# 已打两击的补击是确定收益；起手可配合仅是计划，不能作为救命保证。
		score += interruption_prevention(context, id) * 2.0
		if interruption_prevention(context, id) == 0 and cooperation_plan(context, id).get("kind", "") == "boss_interrupt":
			score += maxi(int(context.get("boss_attack_value", 0)) - int(context.get("boss_interrupted_damage", 8)), 0) * 1.5
		# 只在可接剑时让过去交给她的剑势影响偏好，不解锁专用流派。
		if int(context.get("combo", 0)) > 0:
			score += minf(average_combo, 5.0) * float(d.get("combo_scale", 0)) * 0.25
		var target_hp := int(context.get("highest_enemy_effective_hp", 999999)) if id == Cards.BEHEAD_LOULAN else int(context.get("lowest_enemy_effective_hp", 999999))
		if damage >= target_hp and int(d.get("damage", 0)) > 0:
			score += 20.0
			if id != Cards.BEHEAD_LOULAN and context.get("companion_target_role", "") in ["guardian", "hexer"]:
				score += 4.0
		if Cards.is_investment(id):
			score += 5.0 + confidence * 14.0
		if id == Cards.GRIND_SWORD:
			score = 5.0 + confidence * 14.0 + int(context.get("combo", 0)) * 2.0
		var shield := float(d.get("block", 0))
		if id == Cards.YIN_MOUNTAIN:
			shield = float(context.get("strongest_attack", 0))
		if id == Cards.FROST_COLD:
			shield = float(context.get("frost_prevention", 0))
		if id == Cards.FEW_RETURN and int(context.get("player_hp", 0)) * 4 <= int(context.get("player_max_hp", 1)):
			shield = float(d.get("block_low", 0))
		if id == Cards.OATH_GUARD and context.get("active_promise", "") == "protect":
			shield += float(d.get("promise_bonus", 0))
		score += minf(shield, threat) * (2.0 + guard_history / (guard_history + 10.0) * 0.25)
		if score > best_score:
			best_score = score
			best = id
	return {"card_id": best, "reason": "这回合的机会留给你。" if Cards.is_investment(best) else "这回合我来接这一剑。", "source": "fallback"}
