extends SceneTree

const Cards = preload("res://scripts/data/companion_card_database.gd")
const Resolver = preload("res://scripts/battle/companion_effect_resolver.gd")
const STATE_FIELDS := [
	"enemy_hps", "enemy_guards", "enemy_vulnerabilities", "combo", "block",
	"pending_boon", "preserve_combo_this_turn", "parry_injected_remaining",
	"companion_block_this_turn", "companion_damage_multiplier", "grind_sword_ready",
	"last_target_index", "companion_bonus_action", "cooperation_windows",
	"battle_damage_dealt", "battle_finished", "energy", "player_hp",
	"companion_last_card_id", "companion_last_reason", "companion_last_source",
	"battle_companion_card_counts", "random_call_counts",
	"enemy_intents", "cut_water_active", "long_wind_bonus", "few_return_active", "few_return_used",
]
var fixtures: Dictionary = {}
var baselines: Dictionary = {}
var cases := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func snapshot(battle, state) -> Dictionary:
	var result := {}
	for field in STATE_FIELDS:
		result[field] = battle.get(field)
	result["effect_text"] = battle.get_node("BattleUI/CompanionPanel/Effect").text
	result["message"] = battle.message_label.text
	result["status"] = battle.companion_status_label.text
	result["reason"] = battle.companion_reason_label.text
	result["facts"] = state.relationship_facts
	result["telemetry"] = battle.combo_telemetry.current
	return result.duplicate(true)

func settle(legacy: bool, card_id: String, combo_value: int, promise: String, charged: bool, layout: Array) -> Dictionary:
	var state = root.get_node("RunState")
	state.active_promise = promise
	state.relationship_facts = {}
	if not fixtures.has(legacy):
		var created = load("res://scenes/battle.tscn").instantiate()
		if legacy:
			created.set_script(load("res://tools/fixtures/legacy_companion_card_battle.gd"))
		created.fixed_cooperation_test = true
		created.force_offline_companion = true
		created.offline_experiment = true
		created.fixed_random_seed = 713
		created.selection_logging_enabled = false
		root.add_child(created)
		fixtures[legacy] = created
		baselines[legacy] = snapshot(created, state)
	var battle = fixtures[legacy]
	var baseline: Dictionary = baselines[legacy].duplicate(true)
	for field in STATE_FIELDS:
		battle.set(field, baseline[field])
	battle.combo_telemetry.current = baseline["telemetry"]
	battle.enemy_hps.assign(layout)
	battle.enemy_guards.assign([5, 3])
	battle.enemy_vulnerabilities.assign([2, 1])
	battle.combo = combo_value
	battle.parry_injected_remaining = mini(combo_value, 2)
	battle.block = 4
	battle.companion_block_this_turn = 2
	battle.pending_boon = {"type": "add", "value": 9, "source": "旧增益"}
	battle.grind_sword_ready = charged
	battle.cooperation_windows = {"resource": {"source": Cards.HEART_RESONANCE, "used": false, "combo": combo_value}}
	battle._apply_companion_card({"card_id": card_id, "source": "fallback", "reason": "对照测试"})
	var result := snapshot(battle, state)
	return result

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	var ids := Cards.ORDERED_IDS.duplicate()
	ids.append_array(Cards.INTENT_DEFINITIONS.keys())
	ids.append("unknown_card")
	for card_id in ids:
		for combo_value in [0, 2, 7]:
			for promise in ["", "protect"]:
				for charged in [false, true]:
					for layout in [[100, 40], [0, 1], [0, 0]]:
						var expected := settle(true, card_id, combo_value, promise, charged, layout)
						if expected.is_empty():
							push_error("legacy fixture did not run")
							quit(1)
							return
						var actual := settle(false, card_id, combo_value, promise, charged, layout)
						cases += 1
						for field in expected:
							if expected[field] != actual[field]:
								failures += 1
								push_error("%s combo=%d promise=%s charged=%s hp=%s field=%s expected=%s actual=%s" % [card_id, combo_value, promise, charged, layout, field, expected[field], actual[field]])
	# 无牌 ID 的新定义直接组合已有效果，连击先增加再计算伤害。
	settle(false, Cards.QUICK_SLASH, 1, "", false, [100, 100])
	var composed = fixtures[false]
	composed.enemy_hps.assign([100, 100])
	composed.enemy_guards.fill(0)
	composed.enemy_vulnerabilities.fill(0)
	var before_block: int = composed.block
	var text: String = composed._execute_companion_effects({
		"name": "组合测试", "target": Cards.TARGET_LOWEST_HP,
		"damage": 3, "combo_scale": 2, "block": 4, "boon_type": "add", "boon_value": 6,
		"effects": [
			{"kind": Cards.EFFECT_COMBO, "mode": Cards.COMBO_ADD, "amount": 2},
			{"kind": Cards.EFFECT_DAMAGE, "amount_key": "damage", "combo_scale_key": "combo_scale"},
			{"kind": Cards.EFFECT_BLOCK, "amount_key": "block"},
			{"kind": Cards.EFFECT_BOON},
		],
		"result_template": "{damage}/{block}/{boon}",
	})
	if composed.combo != 3 or composed.enemy_hps[0] != 91 or composed.block != before_block + 4 or text != "9/4/6" or typeof(composed.pending_boon["value"]) != TYPE_INT:
		failures += 1
		push_error("composed effects must use current state in array order without card ID branches")
	state.relationship_facts = {}
	composed._record_companion_effect_tags("synthetic_finisher", {"tags": [Cards.TAG_FINISHER, Cards.TAG_OPENS_WINDOW]}, 5, 0, composed.block)
	var stats: Dictionary = state.relationship_facts.get("cooperation", {})
	if int(stats.get("finishers", 0)) != 1 or int(stats.get("finisher_combo_total", 0)) != 5 or composed.cooperation_windows["resource"]["source"] != "synthetic_finisher":
		failures += 1
		push_error("new tagged card must record without existing card ID")
	for fixture in fixtures.values():
		fixture.free()
	await process_frame
	# 新牌用已有效果组合，无需修改按牌 ID 分支。同时验证解析不修改定义。
	var authored := {"kind": Cards.EFFECT_DAMAGE, "amount_key": "damage", "combo_scale_key": "combo_scale"}
	var definition := {"damage": 3, "combo_scale": 2}
	var definition_before := definition.duplicate(true)
	var authored_before := authored.duplicate(true)
	var effect := Resolver.resolve(authored, definition, {"combo": 4, "promise": "", "damage_multiplier": 2})
	if int(effect["amount"]) != 22 or definition != definition_before or authored != authored_before:
		failures += 1
		push_error("resolver must calculate without mutating definitions")
	print("COMPANION EFFECTS: %s (%d legacy comparisons, state/telemetry/text/target/death/charge/promise)" % ["PASS" if failures == 0 else "FAIL", cases])
	quit(0 if failures == 0 else 1)
