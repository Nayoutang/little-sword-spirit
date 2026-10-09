extends SceneTree

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const FIELDS := ["enemy_hps", "enemy_guards", "enemy_vulnerabilities", "energy", "combo", "block", "pending_boon", "hand", "draw_pile", "discard_pile", "consecutive_attacks", "flowing_cloud_active", "flowing_cloud_triggered", "flowing_cloud_refunds_energy", "cut_water_active", "tune_breath_used_this_turn", "parry_injected_remaining", "resolving_hand_card", "telemetry_action", "battle_player_card_counts", "battle_damage_dealt", "battle_finished", "pending_attack_index", "pending_skill_target", "last_target_index", "cooperation_windows", "random_call_counts", "boon_moment_recorded", "preserve_combo_this_turn", "retain_shield_active", "parry_active", "parry_reactions", "parry_combo_awards", "parry_pending_combo", "parry_reaction_limit", "parry_combo_limit", "battle_parry_damage", "player_hp", "battle_damage_taken", "enemy_intents", "enemy_attack_reductions"]
var fixtures := {}
var baselines := {}
var failures := 0
var cases := 0

func _initialize() -> void:
	call_deferred("run")

func snapshot(battle, state) -> Dictionary:
	var result := {}
	for field in FIELDS:
		result[field] = battle.get(field)
	result["message"] = battle.message_label.text
	result["telemetry"] = battle.combo_telemetry.current
	result["facts"] = state.relationship_facts
	result["visible"] = []
	for index in range(battle.hand.size()):
		result["visible"].append(battle.hand_buttons[index].visible)
	return result.duplicate(true)

func settle(legacy: bool, card: int, combo_value: int, boon: Dictionary, profile: Dictionary, layout: Array) -> Dictionary:
	var state = root.get_node("RunState")
	state.relationship_facts = {}
	state.run_moments.clear()
	if not fixtures.has(legacy):
		var created = load("res://scenes/battle.tscn").instantiate()
		if legacy:
			var legacy_script = load("res://tools/fixtures/legacy_player_card_stage2_battle.gd")
			if legacy_script == null or not legacy_script.can_instantiate():
				created.free()
				push_error("legacy fixture could not compile")
				return {}
			created.set_script(legacy_script)
		created.fixed_cooperation_test = true
		created.force_offline_companion = true
		created.fixed_random_seed = 829
		created.selection_logging_enabled = false
		root.add_child(created)
		fixtures[legacy] = created
		baselines[legacy] = snapshot(created, state)
	var battle = fixtures[legacy]
	var baseline: Dictionary = baselines[legacy].duplicate(true)
	for field in FIELDS:
		battle.set(field, baseline[field])
	battle.combo_telemetry.current = baseline["telemetry"]
	battle.deck_rng.seed = 829
	battle.enemy_hps.assign(layout)
	battle.enemy_guards.assign([3, 2])
	battle.enemy_vulnerabilities.assign([1, 2])
	battle.combo = combo_value
	battle.parry_injected_remaining = mini(combo_value, 2)
	battle.energy = int(profile.get("energy", 3))
	battle.block = int(profile.get("block", 4))
	battle.player_hp = int(profile.get("hp", 90))
	battle.pending_boon = boon.duplicate(true)
	battle.flowing_cloud_active = bool(profile.get("cloud", false))
	battle.flowing_cloud_triggered = false
	battle.consecutive_attacks = int(profile.get("chain", 2))
	battle.retain_shield_active = bool(profile.get("active", false))
	if bool(profile.get("active", false)):
		battle.flowing_cloud_active = true
	if bool(profile.get("defending", false)):
		battle.enemy_intents.assign([{ "type": 1, "value": 6 }, { "type": 1, "value": 6 }])
	battle.cut_water_active = bool(profile.get("protection", false))
	battle.tune_breath_used_this_turn = bool(profile.get("used", false))
	battle.cooperation_windows = {"resource": {"source": CompanionCards.CUT_WATER if battle.cut_water_active else CompanionCards.LEAD_MOMENTUM, "used": false, "combo": combo_value}}
	battle.hand.clear()
	for button in battle.hand_buttons:
		button.hide()
	for id in [card, 0, 1, 0, 1]:
		battle._show_card_in_slot(battle.hand.size(), id)
	battle.draw_pile.clear()
	for _index in range(int(profile.get("deck", 4))):
		battle.draw_pile.append(battle.CardType.DEFENSE)
	battle.discard_pile.clear()
	battle._refresh_ui()
	battle._play_hand_card(0)
	var selection := {"pending": battle.pending_attack_index, "energy": battle.energy, "discard": battle.discard_pile.duplicate(), "combo": battle.combo}
	if battle.pending_attack_index >= 0:
		for index in range(battle.enemy_hps.size()):
			if battle.enemy_hps[index] > 0:
				battle._resolve_targeted_attack(index)
				break
	if bool(profile.get("segments", false)):
		for index in range(3):
			battle._resolve_enemy_attack_segment(0, index, index)
	var result := snapshot(battle, state)
	result["selection"] = selection
	return result

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	var profiles := [{}, {"cloud": true}, {"cloud": true, "protection": true}, {"deck": 0}, {"deck": 1}, {"energy": 0}, {"used": true}, {"active": true}, {"chain": 0}, {"chain": 4}, {"segments": true}, {"defending": true}, {"block": 13}, {"segments": true, "hp": 1, "block": 0}]
	var boons := [{}, {"type": "add", "value": 4, "source": "拱卫"}, {"type": "multiply", "value": 2.0, "source": "引势"}]
	for card in [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19]:
		for combo_value in [0, 2, 7]:
			for boon in boons:
				for profile in profiles:
					for layout in [[100, 40], [1, 0]]:
						var expected := settle(true, card, combo_value, boon, profile, layout)
						var actual := settle(false, card, combo_value, boon, profile, layout)
						if expected.is_empty() or actual.is_empty():
							quit(1)
							return
						cases += 1
						for field in expected:
							if expected[field] != actual[field]:
								failures += 1
								push_error("card=%d combo=%d boon=%s profile=%s layout=%s field=%s expected=%s actual=%s" % [card, combo_value, boon, profile, layout, field, expected[field], actual[field]])
	# 新反击牌只调整定义参数，验证逐段回调不重新读固定牌 ID。
	settle(false, 0, 0, {}, {}, [100, 100])
	var custom = fixtures[false]
	var definition: Dictionary = root.get_node("CardDatabase").get_definition(19).duplicate(true)
	definition["reaction_damage"] = 7
	definition["reaction_limit"] = 1
	definition["combo_limit"] = 1
	custom.parry_active = false
	custom._execute_player_card(definition, 0, -1)
	custom.enemy_hps.assign([100, 100])
	custom.enemy_guards.fill(0)
	custom.enemy_vulnerabilities.fill(0)
	custom._resolve_enemy_attack_segment(0, 0, 0)
	custom._resolve_enemy_attack_segment(0, 1, 0)
	if custom.enemy_hps[0] != 93 or custom.parry_pending_combo != 1 or custom.parry_reactions != 1:
		failures += 1
		push_error("new reaction definition must control damage and phase limits")
	for fixture in fixtures.values():
		fixture.free()
	await process_frame
	print("PLAYER STAGE TWO: %s (%d legacy comparisons, target/cost/combo/boon/cloud/draw/death/limits)" % ["PASS" if failures == 0 else "FAIL", cases])
	quit(0 if failures == 0 else 1)
