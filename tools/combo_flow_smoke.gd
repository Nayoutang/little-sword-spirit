extends SceneTree

var failures := 0
var battle
var cards

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func setup(ids: Array, cloud := true, refunds := true) -> void:
	battle.start_battle()
	battle.companion_turn_pending = false
	battle.enemy_hps.assign([1000, 1000])
	battle.enemy_guards.assign([0, 0])
	battle.enemy_vulnerabilities.assign([0, 0])
	battle.energy = 3
	battle.combo = 0
	battle.flowing_cloud_active = cloud
	battle.flowing_cloud_refunds_energy = refunds
	battle._discard_remaining_hand()
	battle.discard_pile.clear()
	battle.draw_pile.assign([battle.CardType.ATTACK])
	for index in range(ids.size()):
		battle._show_card_in_slot(index, ids[index])
	battle._refresh_ui()

func play(id: int) -> void:
	for index in range(battle.hand.size()):
		if battle.hand[index] == id and battle.hand_buttons[index].visible:
			battle._play_hand_card(index)
			if battle.pending_attack_index >= 0:
				battle._resolve_targeted_attack(0)
			return
	check(false, "missing card %d" % id)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.bond_value = 100
	state.bond_stage = 3
	cards = root.get_node("CardDatabase")
	check(cards.FLOWING_CLOUD in cards.get_reward_card_ids(state.deck), "cloud offered before ownership")
	state.deck.append(cards.FLOWING_CLOUD)
	check(cards.FLOWING_CLOUD not in cards.get_reward_card_ids(state.deck), "owned cloud excluded")
	var owned_reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(owned_reward)
	for button in owned_reward.card_choices.get_children():
		check(button.get_child(0).player_card_id != cards.FLOWING_CLOUD, "battle reward excludes owned cloud")
	owned_reward.queue_free()
	state.pending_event = state.EventType.TREASURE
	var owned_event = load("res://scenes/event.tscn").instantiate()
	root.add_child(owned_event)
	owned_event._show_card_choices()
	for button in owned_event.card_choices.get_children():
		check(button.get_child(0).player_card_id != cards.FLOWING_CLOUD, "event reward excludes owned cloud")
	owned_event.queue_free()
	state.deck.erase(cards.FLOWING_CLOUD)
	check(cards.FLOWING_CLOUD in cards.get_reward_card_ids(state.deck), "removed cloud offered again")
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	battle.fixed_random_seed = 73
	root.add_child(battle)
	await process_frame
	check(not battle.companion_selection_records.is_empty(), "intent telemetry captured offline")
	check(battle.companion_selection_records[0].has("fallback_selected") and battle.companion_selection_records[0].has("candidates"), "same-context fallback reference captured")
	var hand_ids := [cards.ATTACK, cards.COMBO_BOOST, cards.CHASE_WIND, cards.ATTACK]
	setup(hand_ids)
	play(cards.ATTACK)
	check(battle.energy == 2 and battle.combo == 1 and battle.consecutive_attacks == 1, "first attack")
	play(cards.COMBO_BOOST)
	check(battle.energy == 1 and battle.combo == 3 and battle.consecutive_attacks == 2, "second attack")
	battle._use_special()
	battle._resolve_targeted_skill(0)
	check(battle.energy == 0 and battle.combo == 1 and battle.consecutive_attacks == 2, "special preserves count")
	check(battle._card_cost(battle.CardType.CHASE_WIND) == 0, "wind costs zero after special")
	var wind_face = battle.hand_buttons[2].get_node("PaintedFace")
	check(wind_face._card_info()["cost"] == "0", "live card cost")
	if "--combo-preview" in OS.get_cmdline_user_args():
		await create_timer(1.8).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/combo-flow-preview.png")
	play(cards.CHASE_WIND)
	check(battle.energy == 1 and battle.combo == 2 and battle.consecutive_attacks == 3 and battle.flowing_cloud_triggered, "third attack triggers cloud")
	play(cards.ATTACK)
	battle._use_ultimate()
	battle._resolve_targeted_skill(0)
	check(battle.enemy_hps[0] == 1000 - 88 - cards.get_number(cards.CHASE_WIND, "damage"), "88+D baseline")
	check(battle.consecutive_attacks == 4 and battle.combo == 0 and battle.energy == 0, "ultimate preserves count")
	check(battle.player_status.attack_chain == 4, "HUD separate count")
	check(battle.combo_telemetry.current["flowing_light"] == 1 and battle.combo_telemetry.current["brilliance"] == 1 and battle.combo_telemetry.current["wind_costs"][0] == 1, "actual battle telemetry captures dual skills and zero-cost wind")
	check(battle.combo_telemetry.intervals.size() == 2 and battle.combo_telemetry.intervals[1]["outcome"] == "brilliance", "actual eligibility intervals captured")

	setup(hand_ids, true, false)
	play(cards.ATTACK)
	play(cards.COMBO_BOOST)
	battle._use_special()
	battle._resolve_targeted_skill(0)
	play(cards.CHASE_WIND)
	check(battle.energy == 0 and battle.combo == 2, "draw-only stops before final paid attack")
	var combo_before: int = battle.combo
	play(cards.ATTACK)
	check(battle.combo == combo_before, "unaffordable card does not change count")
	battle._apply_companion_card({"card_id": "heart_resonance", "source": "replay"})
	battle._resolve_enemy_turn()
	check(battle.combo == 2 and battle.consecutive_attacks == 0 and not battle.flowing_cloud_triggered and battle.flowing_cloud_active, "heart resonance carries combo, round resets count")
	battle.companion_turn_pending = false
	play(cards.ATTACK)
	battle._use_ultimate()
	check(battle.pending_skill_target == 2, "next-round ultimate available")

	setup([cards.ATTACK, cards.COMBO_BOOST, cards.CHASE_WIND, cards.CHASE_WIND], true, false)
	play(cards.ATTACK)
	play(cards.COMBO_BOOST)
	battle._use_special()
	battle._resolve_targeted_skill(0)
	play(cards.CHASE_WIND)
	play(cards.CHASE_WIND)
	check(battle.combo == 3 and battle.energy == 0, "second free wind enables ultimate in draw-only version")

	for non_attack in [cards.DEFENSE, cards.STATUS, cards.HEAVY_DEFENSE, cards.TUNE_BREATH, cards.SHADOW_STEP, cards.UNLOAD_FORCE, cards.HIDE_EDGE, cards.FLOWING_CLOUD]:
		setup([non_attack, cards.CHASE_WIND], false)
		battle.consecutive_attacks = 2
		battle.combo = 4
		battle.cut_water_active = true
		play(non_attack)
		check(battle.consecutive_attacks == 0 and battle._card_cost(battle.CardType.CHASE_WIND) == 2, "non-attack resets discount %d" % non_attack)
		if non_attack in [cards.TUNE_BREATH, cards.SHADOW_STEP, cards.UNLOAD_FORCE, cards.HIDE_EDGE]:
			check(battle.combo == 4 and battle.cut_water_active, "no combo loss and no cut-water consumption %d" % non_attack)
		if non_attack == cards.FLOWING_CLOUD:
			check(not battle.flowing_cloud_triggered and cards.FLOWING_CLOUD not in battle.discard_pile, "ability enters without triggering and leaves deck")

	setup([cards.CHASE_WIND, cards.CHASE_WIND, cards.CHASE_WIND])
	battle.consecutive_attacks = 2
	play(cards.CHASE_WIND)
	var energy_after: int = battle.energy
	battle.consecutive_attacks = 2
	play(cards.CHASE_WIND)
	check(battle.energy == energy_after, "cloud triggers only once despite count reset")
	setup([cards.CHASE_WIND], false)
	battle.consecutive_attacks = 1
	play(cards.CHASE_WIND)
	check(battle.energy == 2 and battle.consecutive_attacks == 2, "wind reads pre-play count and costs one")
	setup([cards.CHASE_WIND], false)
	play(cards.CHASE_WIND)
	check(battle.energy == 1 and battle.consecutive_attacks == 1, "wind base cost two")
	setup([cards.CHASE_WIND])
	battle.consecutive_attacks = 2
	battle.enemy_hps.assign([1, 0])
	play(cards.CHASE_WIND)
	check(battle.battle_finished and not battle.flowing_cloud_active and battle.consecutive_attacks == 0, "lethal attack cleans state without cloud draw")
	battle.start_battle()
	check(not battle.flowing_cloud_active and not battle.flowing_cloud_triggered and battle.consecutive_attacks == 0, "restart clears abilities")
	var enemy_state_before: int = battle.enemy_rng.state
	battle.draw_pile.assign([battle.CardType.ATTACK, battle.CardType.DEFENSE, battle.CardType.SWEEP])
	battle._shuffle_draw_pile()
	check(battle.enemy_rng.state == enemy_state_before, "deck shuffle does not consume enemy RNG")
	print("COMBO_FLOW_SMOKE failures=%d" % failures)
	battle.queue_free()
	await process_frame
	quit(1 if failures else 0)
