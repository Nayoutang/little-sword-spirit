extends RefCounted

# 只计算单项参数；扣费、增益消耗和所有状态修改由战斗顺序执行。
# context 可含：combo、attack_combo_bonus、block、companion_intent（小墨本回合亮出的意向类别）、
# defenses_this_turn（本回合已打出的防御牌数）、xiaomo_bound（她是否被紫线缠住）。
static func resolve(authored: Dictionary, definition: Dictionary, context: Dictionary) -> Dictionary:
	var effect := authored.duplicate(true)
	var intent := str(context.get("companion_intent", ""))
	if effect.has("requires_intent") and intent not in effect["requires_intent"]:
		effect["skip"] = true
		return effect
	if effect.has("unless_intent") and intent in effect["unless_intent"]:
		effect["skip"] = true
		return effect
	if bool(effect.get("requires_no_defense", false)) and int(context.get("defenses_this_turn", 0)) > 0:
		effect["skip"] = true
		return effect
	if effect.has("amount_key"):
		effect["amount"] = int(definition[effect["amount_key"]])
	if effect.has("shield_percent_key"):
		effect["amount"] = floori(int(context["block"]) * int(definition[effect["shield_percent_key"]]) / 100.0)
	if bool(effect.get("combo_scaled", false)):
		effect["amount"] = int(effect["amount"]) + int(context["combo"]) * int(context["attack_combo_bonus"])
	if effect.has("context_add_key"):
		effect["amount"] = int(effect.get("amount", 0)) + int(context.get(effect["context_add_key"], 0))
	if effect.has("per_context_key"):
		effect["amount"] = int(effect.get("amount", 0)) + int(context.get(effect["per_context_key"], 0)) * int(definition[effect["per_amount_key"]])
	if effect.has("combo_scale_key"):
		var scale_key: String = effect["combo_scale_key"]
		if effect.has("intent_combo_scale_key") and intent in effect.get("bonus_intent", []):
			scale_key = effect["intent_combo_scale_key"]
		effect["amount"] = int(effect.get("amount", 0)) + int(context["combo"]) * int(definition[scale_key])
	if effect.has("defense_scale_key"):
		effect["amount"] = int(effect["amount"]) + int(context.get("defenses_this_turn", 0)) * int(definition[effect["defense_scale_key"]])
	if effect.has("intent_bonus_key") and intent in effect.get("bonus_intent", []):
		effect["amount"] = int(effect["amount"]) + int(definition[effect["intent_bonus_key"]])
	if effect.has("thread_bonus_key") and bool(context.get("xiaomo_bound", false)):
		effect["amount"] = int(effect["amount"]) + int(definition[effect["thread_bonus_key"]])
	return effect


static func cost(definition: Dictionary, context: Dictionary) -> int:
	var amount := int(definition["cost"])
	var rule: Dictionary = definition.get("cost_rule", {})
	if rule.has("subtract_state"):
		amount = maxi(amount - int(context[rule["subtract_state"]]), int(rule.get("minimum", 0)))
	if rule.has("free_when_intent") and str(context.get("companion_intent", "")) in rule["free_when_intent"]:
		amount = 0
	return amount
