extends RefCounted

const Types = preload("res://scripts/data/combat_types.gd")
const Intent = Types.EnemyIntent
const Segments = preload("res://scripts/battle/enemy_attack_segments.gd")

# Computes the next intents from values, leaving live battle state to its owner.
static func roll(context: Dictionary, random_roll: Callable) -> Dictionary:
	var intents: Array[Dictionary] = []
	var reductions: Array[int] = []
	reductions.assign(context.reductions)
	var result := {"intents": intents, "reductions": reductions,
		"boss_step": int(context.boss_step), "boss_hits": int(context.boss_hits),
		"role_step": int(context.role_step)}
	if context.fixed:
		intents.assign([{"type": Intent.ATTACK, "value": 6}, {"type": Intent.ATTACK, "value": 8}])
		return result
	if context.boss:
		result.boss_hits = 0
		var action: int = context.boss_step % 3
		result.boss_step += 1
		var config: Dictionary = EnemyDatabase.get_boss_config(context.layer)
		if action == 1:
			intents.append({"type": Intent.DEFEND, "value": int(config.guard)})
		else:
			var charging := action == 2
			var enraged: bool = context.hps[0] * 2 <= context.max_hps[0]
			var damage := int(config.attack)
			if charging:
				damage = int(config.enraged_heavy if enraged else config.heavy)
			damage = maxi(damage - reductions[0], 0)
			reductions[0] = 0
			intents.append({"type": Intent.ATTACK, "value": damage, "charging": charging})
		return result
	result.role_step += 1
	for index in range(context.hps.size()):
		if context.hps[index] <= 0:
			intents.append({"type": Intent.OTHER, "value": 0})
			continue
		if index < context.roles.size():
			var intent: Dictionary = EnemyDatabase.get_role_intent(context.roles[index], context.role_step, context.elite, context.layer)
			if intent.type == Intent.ATTACK:
				Segments.reduce_next(intent, reductions[index])
				reductions[index] = 0
			intents.append(intent)
			continue
		var choice: int = random_roll.call(0, 99)
		if choice < EnemyDatabase.INTENT_ATTACK_END:
			var damage: int = random_roll.call(EnemyDatabase.ATTACK_DAMAGE_MIN, EnemyDatabase.ATTACK_DAMAGE_MAX)
			intents.append({"type": Intent.ATTACK, "value": maxi(damage + context.strengths[index] - reductions[index], 0)})
			reductions[index] = 0
		elif choice < EnemyDatabase.INTENT_DEFEND_END:
			intents.append({"type": Intent.DEFEND, "value": random_roll.call(EnemyDatabase.DEFENSE_MIN, EnemyDatabase.DEFENSE_MAX)})
		elif choice < EnemyDatabase.INTENT_ENHANCE_END:
			intents.append({"type": Intent.ENHANCE, "value": EnemyDatabase.STRENGTH_GAIN})
		elif choice < EnemyDatabase.INTENT_CURSE_END:
			intents.append({"type": Intent.CURSE, "value": 1})
		else:
			intents.append({"type": Intent.OTHER, "value": 0})
	return result
