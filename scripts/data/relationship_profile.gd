extends RefCounted

# Converts profile data without disk I/O or mutating live state.
const VERSION := 2

static func encode(state: Node) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("relationship", "version", VERSION)
	config.set_value("relationship", "bond_value", state.bond_value)
	config.set_value("relationship", "bond_stage", state.bond_stage)
	config.set_value("relationship", "pending_bond_stage", state.pending_bond_stage)
	config.set_value("progress", "consecutive_run_failures", state.consecutive_run_failures)
	config.set_value("progress", "expedition_count", state.expedition_count)
	config.set_value("progress", "pending_concern", state.pending_concern)
	config.set_value("progress", "intro_done", state.intro_done)
	config.set_value("profile", "player_name", state.player_name)
	config.set_value("finale", "state", state.finale_state)
	config.set_value("finale", "mode", state.finale_mode)
	config.set_value("memory", "recent_lines", state.recent_lines)
	config.set_value("memory", "recent_adventures", state.recent_adventures)
	config.set_value("memory", "sword_intents", state.learned_sword_intents)
	config.set_value("memory", "cooperation", state.relationship_facts.get("cooperation", {}))
	config.set_value("memory", "shared_history", state.shared_history)
	config.set_value("memory", "battles_won", int(state.relationship_facts.get("battles_won", 0)))
	config.set_value("memory", "battles_lost", int(state.relationship_facts.get("battles_lost", 0)))
	config.set_value("memory", "promise_kept", int(state.relationship_facts.get("promise_kept", 0)))
	config.set_value("memory", "promise_broken", int(state.relationship_facts.get("promise_broken", 0)))
	config.set_value("memory", "companion_card_counts", state.relationship_facts.get("companion_card_counts", {}))
	config.set_value("memory", "minigame_results", state.relationship_facts.get("minigame_results", []))
	config.set_value("run_journal", "last_completed", state.last_run_journal)
	return config


static func stage_index(value: int) -> int:
	var result := 0
	for index in range(BalanceConfig.BOND_STAGE_THRESHOLDS.size()):
		if value >= BalanceConfig.BOND_STAGE_THRESHOLDS[index]:
			result = index
	return result


static func empty_facts() -> Dictionary:
	return {"battles_won": 0, "battles_lost": 0, "promise_kept": 0, "promise_broken": 0,
		"companion_card_counts": {}, "minigame_results": [], "cooperation": {}}


static func decode(config: ConfigFile) -> Dictionary:
	var bond := clampi(_number(config, "relationship", "bond_value", BalanceConfig.BOND_MIN), BalanceConfig.BOND_MIN, BalanceConfig.BOND_MAX)
	var stage := clampi(_number(config, "relationship", "bond_stage", stage_index(bond)), 0, BalanceConfig.BOND_STAGE_NAMES.size() - 1)
	var facts := empty_facts()
	for key in ["battles_won", "battles_lost", "promise_kept", "promise_broken"]:
		facts[key] = maxi(_number(config, "memory", key), 0)
	var cooperation := _dictionary(config, "memory", "cooperation")
	for key in ["opportunities_used", "opportunities_wasted", "finisher_combo_total", "finishers", "guards"]:
		facts.cooperation[key] = maxi(_integer(cooperation.get(key, 0)), 0)
	var card_counts := _dictionary(config, "memory", "companion_card_counts")
	for card_id in card_counts:
		facts.companion_card_counts[str(card_id)] = maxi(_integer(card_counts[card_id]), 0)
	var results := _memories(config, "memory", "minigame_results", "minigame_result")
	while results.size() > 12:
		results.pop_front()
	facts.minigame_results = results
	var adventures: Array[int] = []
	for index in _array(config, "memory", "recent_adventures"):
		if index is int and index >= 0 and index < 5 and not adventures.has(index):
			adventures.append(index)
	var lines: Array[String] = []
	for line in _array(config, "memory", "recent_lines"):
		lines.append(str(line))
	var intents: Array[String] = []
	for card_id in _array(config, "memory", "sword_intents"):
		if not CompanionCardDatabase.get_definition(str(card_id)).is_empty():
			intents.append(str(card_id))
	var finale := str(config.get_value("finale", "state", "locked"))
	var mode := str(config.get_value("finale", "mode", "arrival"))
	var intro: Variant = config.get_value("progress", "intro_done", false)
	return {
		"bond_value": bond, "bond_stage": maxi(stage, stage_index(bond)), "pending_bond_stage": -1,
		"consecutive_run_failures": maxi(_number(config, "progress", "consecutive_run_failures"), 0),
		"expedition_count": maxi(_number(config, "progress", "expedition_count"), 0),
		"intro_done": bool(intro) if intro is bool or intro is int or intro is float else false,
		"player_name": str(config.get_value("profile", "player_name", "")),
		"finale_state": finale if finale in ["locked", "invited", "accepted", "story", "battle", "ended"] else "locked",
		"finale_mode": mode if mode in ["arrival", "refusal", "victory", "sacrifice"] else "arrival",
		"pending_concern": _dictionary(config, "progress", "pending_concern"),
		"recent_adventures": adventures, "recent_lines": lines, "learned_sword_intents": intents,
		"shared_history": _memories(config, "memory", "shared_history"),
		"last_run_journal": _memories(config, "run_journal", "last_completed"),
		"relationship_facts": facts,
	}


static func _integer(value: Variant, fallback: int = 0) -> int:
	if value is int or value is float or value is bool or value is String:
		return int(value)
	return fallback


static func _number(config: ConfigFile, section: String, key: String, fallback: int = 0) -> int:
	return _integer(config.get_value(section, key, fallback), fallback)


static func _array(config: ConfigFile, section: String, key: String) -> Array:
	var value: Variant = config.get_value(section, key, [])
	return value if value is Array else []


static func _dictionary(config: ConfigFile, section: String, key: String) -> Dictionary:
	var value: Variant = config.get_value(section, key, {})
	return value.duplicate(true) if value is Dictionary else {}


static func _memories(config: ConfigFile, section: String, key: String, category: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fact in _array(config, section, key):
		if fact is Dictionary and not str(fact.get("summary", "")).is_empty():
			if category.is_empty() or fact.get("category", "") == category:
				result.append(fact.duplicate(true))
	return result
