extends RefCounted

# 只计算单项参数；扣费、增益消耗和所有状态修改由战斗顺序执行。
static func resolve(authored: Dictionary, definition: Dictionary, context: Dictionary) -> Dictionary:
	var effect := authored.duplicate(true)
	if effect.has("amount_key"):
		effect["amount"] = int(definition[effect["amount_key"]])
	if bool(effect.get("combo_scaled", false)):
		effect["amount"] = int(effect["amount"]) + int(context["combo"]) * int(context["attack_combo_bonus"])
	return effect
