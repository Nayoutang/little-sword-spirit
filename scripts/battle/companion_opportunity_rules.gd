extends RefCounted

const Cards = preload("res://scripts/data/companion_card_database.gd")

static func kind(definition: Dictionary) -> String:
	return str(definition.get("opportunity", {}).get("kind", ""))

static func available(definition: Dictionary, context: Dictionary) -> bool:
	match kind(definition):
		Cards.OPPORTUNITY_COMBO_PROTECTION:
			return bool(context["defense"]) and (int(context["combo"]) > 0 or bool(context["attack"]))
		Cards.OPPORTUNITY_EXTRA_ENERGY:
			return int(context["total_cost"]) > int(context["max_energy"])
		Cards.OPPORTUNITY_ATTACK_WITH_COMBO:
			return bool(context["attack"]) and int(context["combo"]) > 0
	return bool(context["attack"])

static func lost(definition: Dictionary, combo: int) -> bool:
	return kind(definition) == Cards.OPPORTUNITY_ATTACK_WITH_COMBO and combo == 0

static func used_by_attack(definition: Dictionary, combo: int, companion_pending: bool, was_lost: bool) -> bool:
	return kind(definition) == Cards.OPPORTUNITY_ATTACK_WITH_COMBO and combo > 0 and not companion_pending and not was_lost

static func used_by_energy(definition: Dictionary, energy: int) -> bool:
	if kind(definition) != Cards.OPPORTUNITY_EXTRA_ENERGY:
		return false
	var key := str(definition["opportunity"]["energy_key"])
	return energy < int(definition[key])
