extends RefCounted

const Cards = preload("res://scripts/data/companion_card_database.gd")

# 无运行状态、无 RunState 依赖；调用者在每项效果执行前提供当前快照。
static func resolve(authored: Dictionary, definition: Dictionary, context: Dictionary) -> Dictionary:
	var effect := authored.duplicate(true)
	match str(effect["kind"]):
		Cards.EFFECT_DAMAGE:
			var amount := int(definition[effect["amount_key"]])
			if effect.has("combo_scale_key"):
				amount += int(context["combo"]) * int(definition[effect["combo_scale_key"]])
			effect["amount"] = amount * int(context["damage_multiplier"])
		Cards.EFFECT_BLOCK, Cards.EFFECT_WEAKEN, Cards.EFFECT_NEXT_TURN_ENERGY:
			var amount := int(definition[effect["amount_key"]])
			if effect.has("promise") and str(context["promise"]) == str(effect["promise"]):
				amount += int(definition[effect["bonus_key"]])
			effect["amount"] = amount
		Cards.EFFECT_BOON:
			var boon_type := str(definition["boon_type"])
			var boon_value: Variant = int(definition["boon_value"])
			if boon_type == "multiply":
				boon_value = float(definition["boon_value"])
			effect["boon"] = {
				"type": boon_type,
				"value": boon_value,
				"source": str(definition["name"]),
			}
	return effect
