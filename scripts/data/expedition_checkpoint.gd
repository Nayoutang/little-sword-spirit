class_name ExpeditionCheckpoint
extends RefCounted

const VERSION := 1
const Routes = preload("res://scripts/data/scene_routes.gd")
const SCENES := {
	"promise": Routes.PATHS.promise,
	"map": Routes.PATHS.map,
	"battle": Routes.PATHS.battle,
	"event": Routes.PATHS.event,
	"adventure": Routes.PATHS.adventure,
	"poetry": Routes.PATHS.poetry,
	"story": Routes.PATHS.chapter_story,
	"reward": Routes.PATHS.reward,
	"settlement": Routes.PATHS.settlement,
}
const FIELDS := [
	"player_max_hp", "player_hp", "pending_encounter", "route_layer", "pending_event",
	"deck", "run_id", "run_adventures", "active_promise", "promise_broken", "run_won",
	"settlement_applied", "post_battle_scene", "pending_act_bond_gain", "current_run_journal",
	"run_journal_finished", "run_moments", "run_battle_index", "homecoming_pending",
	"promise_sincere", "run_min_hp", "map_seed", "map_layer", "map_node", "map_path", "battle_seed",
]
# 后加的字段：旧存档里没有时按默认值恢复，不判为无效。
const OPTIONAL_FIELDS := ["run_relics", "run_lean", "run_lean_spoken", "sword_realm", "free_boss"]
const INTS := ["player_max_hp", "player_hp", "pending_encounter", "route_layer", "pending_event", "run_id", "pending_act_bond_gain", "run_battle_index", "run_min_hp", "map_seed", "map_layer", "map_node", "battle_seed"]
const BOOLS := ["promise_broken", "run_won", "settlement_applied", "run_journal_finished", "homecoming_pending", "promise_sincere"]

static func capture(state: Node, phase: String, room: Dictionary, profile: String) -> Dictionary:
	var values := {}
	for field in FIELDS + OPTIONAL_FIELDS:
		var value: Variant = state.get(field)
		values[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"version": VERSION, "phase": phase, "state": values, "room": room.duplicate(true), "profile": profile}

static func valid(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.get("version") != VERSION or not SCENES.has(snapshot.get("phase", "")):
		return false
	var data: Variant = snapshot.get("state")
	if not data is Dictionary or not snapshot.get("room") is Dictionary or not snapshot.get("profile") is String:
		return false
	for field in FIELDS:
		if not data.has(field): return false
	for field in INTS:
		if not data[field] is int: return false
	for field in BOOLS:
		if not data[field] is bool: return false
	if data.player_max_hp < 1 or data.player_max_hp > 10000 or data.player_hp < 0 or data.player_hp > data.player_max_hp:
		return false
	if data.route_layer < 1 or data.route_layer >= BalanceConfig.ROUTE_TOTAL_LAYERS or data.map_layer < 0 or data.map_layer >= BalanceConfig.ROUTE_TOTAL_LAYERS:
		return false
	if data.map_node < 0 or data.map_node >= 5 or (data.map_layer in [0, BalanceConfig.ROUTE_TOTAL_LAYERS - 1] and data.map_node != 0):
		return false
	if data.map_seed < 0 or data.battle_seed < 0 or data.run_id < 0 or data.run_battle_index < 0:
		return false
	if data.run_min_hp < 0 or data.run_min_hp > data.player_max_hp: return false
	if data.pending_encounter not in [0,1,2] or data.pending_event not in [0,1] or data.pending_act_bond_gain < -1:
		return false
	if data.active_promise not in ["", "protect", "finish"] or data.post_battle_scene not in [SCENES.map, SCENES.settlement]:
		return false
	if not data.deck is Array or data.deck.size() > 2000:
		return false
	for id in data.deck:
		if not id is int or not (CardDatabase.DEFINITIONS.has(id) or (id >= CardDatabase.UPGRADE_OFFSET and CardDatabase.UPGRADES.has(id - CardDatabase.UPGRADE_OFFSET))): return false
	if not data.run_adventures is Array or data.run_adventures.size() > 5:
		return false
	for id in data.run_adventures:
		if not id is int or id < 0 or id >= 5: return false
	for field in ["current_run_journal", "run_moments"]:
		if not data[field] is Array or data[field].size() > 1000: return false
		for fact in data[field]:
			if not fact is Dictionary or not fact.get("summary") is String: return false
	if not data.map_path is Array or data.map_path.size() > BalanceConfig.ROUTE_TOTAL_LAYERS: return false
	for point in data.map_path:
		if not point is Array or point.size() != 2 or not point[0] is int or not point[1] is int or point[0] < 0 or point[0] >= BalanceConfig.ROUTE_TOTAL_LAYERS or point[1] < 0 or point[1] >= 5: return false
		if point[0] > data.map_layer or (point[0] in [0, BalanceConfig.ROUTE_TOTAL_LAYERS - 1] and point[1] != 0): return false
	if data.has("run_relics"):
		if not data.run_relics is Array or data.run_relics.size() > 64: return false
		for id in data.run_relics:
			if not id is String or RelicDatabase.get_definition(id).is_empty(): return false
	if data.has("run_lean"):
		if not data.run_lean is Dictionary: return false
		for key in data.run_lean:
			if not key in ["guard", "invest", "finisher"] or not data.run_lean[key] is int or data.run_lean[key] < 0: return false
	if data.has("sword_realm") and (not data.sword_realm is int or data.sword_realm < 0 or data.sword_realm > 5): return false
	if data.has("free_boss") and (not data.free_boss is String or data.free_boss.length() > 32): return false
	if data.has("run_lean_spoken"):
		if not data.run_lean_spoken is Array or data.run_lean_spoken.size() > 3: return false
	var room: Dictionary = snapshot.room
	if room.has("relic") and (not room.relic is String or (not room.relic.is_empty() and RelicDatabase.get_definition(room.relic).is_empty())): return false
	if room.has("cards"):
		if not room.cards is Array or room.cards.size() != 3: return false
		for id in room.cards:
			if not id is int or not CardDatabase.DEFINITIONS.has(id): return false
	if room.has("comic") and (not room.comic is int or room.comic < 0 or room.comic >= 5): return false
	if room.has("story") and room.story not in ["ch2_blacksmith", "ch2_troupe", "ch3_sword_tomb"]: return false
	if room.has("on_thread") and not room.on_thread is bool: return false
	if room.has("removing") and not room.removing is bool: return false
	if room.has("upgrading") and not room.upgrading is bool: return false
	if room.has("reward_message") and not room.reward_message is String: return false
	if room.has("card_choices") and not room.card_choices is bool: return false
	if room.has("settlement_result") and not room.settlement_result is Dictionary: return false
	if room.has("settlement_result") and not data.settlement_applied: return false
	if snapshot.phase == "battle" and data.battle_seed == 0: return false
	var profile := ConfigFile.new()
	return profile.parse(snapshot.profile) == OK and profile.has_section("relationship")

static func restore(state: Node, snapshot: Dictionary) -> void:
	for field in OPTIONAL_FIELDS:
		if not snapshot.state.has(field):
			var current: Variant = state.get(field)
			if current is Array or current is Dictionary:
				current.clear()
	for field in FIELDS + OPTIONAL_FIELDS:
		if not snapshot.state.has(field):
			continue
		var value: Variant = snapshot.state[field]
		if value is Array:
			var target: Array = state.get(field)
			target.assign(value.duplicate(true))
		else:
			state.set(field, value.duplicate(true) if value is Dictionary else value)
