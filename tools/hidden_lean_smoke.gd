extends SceneTree

# 暗线「信 / 执」：结算规则、心事入队与存档往返。
func _initialize() -> void:
	call_deferred("run")


func _run_trip(state, events, promise: String, won: bool, min_hp: int, used: int) -> void:
	events.reset()
	state.start_new_run()
	state.set_promise(promise, true)
	state.record_cooperation("opportunities_used", used)
	state.run_min_hp = min_hp
	if promise == "protect" and min_hp <= int(state.player_max_hp * 0.25):
		state.promise_broken = true
	if promise == "protect":
		state.settle_act_promise()
	state.finish_run(won)
	state.apply_settlement()


func run() -> void:
	assert(OS.get_environment("APPDATA").contains("hidden-lean-user"))
	var state = root.get_node("RunState")
	var events = root.get_node("SpecialEventManager")
	state.suppress_persistence = true
	state._reset_slot_state()
	assert(state.hidden_trust == 0 and state.hidden_attachment == 0)

	# 守约通关、血线稳、接住 4 次机会（单趟上限 3）：信 +4+3，执不低于 0。
	_run_trip(state, events, "finish", true, 80, 4)
	assert(state.hidden_trust == 7 and state.hidden_attachment == 0)
	# 第一次完整走完（优先级 70）排在「接住她的机会」（45）前面。
	assert(events.has_waiting_events() and events.activate_next() and events.get_active_event_id() == "first_full_run")
	events.validate_and_resolve({"event_id": "first_full_run", "resolved": true}, 1)
	assert(state.hidden_trust == 8)
	assert(events.activate_next() and events.get_active_event_id() == "caught_her_opening")

	# 约定完成远征却倒下：信 -3，执 +3，排入「第一次倒下」。
	_run_trip(state, events, "finish", false, 0, 0)
	assert(state.hidden_trust == 5 and state.hidden_attachment == 3)
	assert(events.activate_next() and events.get_active_event_id() == "first_fall")

	# 再次失约（保护约定、残血通关）：信 -3，执 +2，第二次失约排入心事，优先级高于其他。
	_run_trip(state, events, "protect", true, 10, 0)
	assert(state.hidden_trust == 2 and state.hidden_attachment == 5)
	assert(events.activate_next() and events.get_active_event_id() == "promise_broken_again")

	# 抉择影响：认真重新答应 = 信 +2，执 -1。
	var outcome: Dictionary = events.validate_and_resolve({"event_id": "promise_broken_again", "resolved": true}, 0)
	assert(outcome.resolved and state.hidden_trust == 4 and state.hidden_attachment == 4)

	# 给大模型的倾向描述不带数字。
	var prompt: String = state.get_relationship_prompt()
	assert(prompt.contains("她心里的分量"))
	for digit in "0123456789":
		assert(not prompt.contains(digit))

	# 存档往返。
	var codec = preload("res://scripts/data/relationship_profile.gd")
	var decoded: Dictionary = codec.decode(codec.encode(state))
	assert(decoded.hidden_trust == 4 and decoded.hidden_attachment == 4)
	var legacy := ConfigFile.new()
	legacy.set_value("relationship", "bond_value", 30)
	var old_profile: Dictionary = codec.decode(legacy)
	assert(old_profile.hidden_trust == 0 and old_profile.hidden_attachment == 0)
	_check_combat_lean()
	_check_homecoming_events(state, events)
	print("HIDDEN LEAN: PASS")
	quit(0)


# 战斗倾向：信让她更常留机会，执让她在你受伤时更常替你挡；都为 0 时与原逻辑一致。
func _check_combat_lean() -> void:
	var C = preload("res://scripts/data/companion_card_database.gd")
	var T = preload("res://scripts/battle/companion_tactics.gd")
	seed(7)
	var pool: Array[String] = [C.QUICK_SLASH, C.GUARD_ECHO, C.FOLLOW_UP, C.CLEAN_CUT, C.LEAD_MOMENTUM, C.OATH_GUARD, C.RETURN_GUARD, C.ESCORT, C.LONE_JUDGMENT, C.HEART_RESONANCE]
	var decisions := 0
	var invest := [0, 0]
	var guard := [0, 0]
	for i in 1500:
		var ctx := {"player_hp": randi_range(5, 50), "player_max_hp": 50, "block": randi_range(0, 6), "combo": randi_range(0, 3),
			"can_build_combo": randf() < 0.5, "living_enemies": randi_range(1, 3), "lowest_enemy_effective_hp": randi_range(5, 40),
			"highest_enemy_hp": 40, "incoming_damage": [0, 0, 4, 6, 8, 10, 14][randi_range(0, 6)],
			"cooperation": {"opportunities_used": randi_range(0, 10), "opportunities_wasted": randi_range(0, 10), "guards": randi_range(0, 10)}}
		var options: Array[String] = T.candidates(ctx, pool)
		if options.size() < 2:
			continue
		decisions += 1
		var base := str(T.choose(ctx, options).card_id)
		ctx.hidden_trust = 0
		ctx.hidden_attachment = 0
		assert(str(T.choose(ctx, options).card_id) == base)
		ctx.hidden_trust = 100
		var trusting := str(T.choose(ctx, options).card_id)
		ctx.hidden_trust = 0
		ctx.hidden_attachment = 100
		var clinging := str(T.choose(ctx, options).card_id)
		assert(trusting in options and clinging in options)
		invest[0] += int(C.is_investment(base))
		invest[1] += int(C.is_investment(trusting))
		guard[0] += int(C.TAG_GUARD in C.get_definition(base).get("tags", []))
		guard[1] += int(C.TAG_GUARD in C.get_definition(clinging).get("tags", []))
	print("combat lean: decisions=%d invest %d->%d guard %d->%d" % [decisions, invest[0], invest[1], guard[0], guard[1]])
	assert(decisions > 500)
	assert(invest[1] > invest[0] + decisions / 50)
	assert(guard[1] > guard[0] + decisions / 50)


# 回家小事件：由本趟真实事实触发，一次性。
func _check_homecoming_events(state, events) -> void:
	state._reset_slot_state()
	events.reset()
	state.start_new_run()
	state.record_moment("测试：她替你挡下", 4, "companion_save")
	state.record_moment("测试：精英战", 1, "elite_win")
	state.learned_sword_intents.append("frost_cold")
	state.finish_run(true)
	state.apply_settlement()
	var queued: Array[String] = []
	while events.activate_next():
		var event_id: String = events.get_active_event_id()
		queued.append(event_id)
		events.validate_and_resolve({"event_id": event_id, "resolved": true}, 0)
	assert(queued == ["she_saved_you", "first_full_run", "first_intent", "first_elite"], str(queued))
	# 谈过的不再出现。
	state.start_new_run()
	state.record_moment("测试：精英战", 1, "elite_win")
	state.finish_run(true)
	state.apply_settlement()
	assert(not events.activate_next())
	var dialogue = preload("res://scripts/data/offline_home_dialogue.gd")
	for event_id in events.DEFINITIONS:
		assert(dialogue.EVENTS.has(event_id) and dialogue.EVENT_OPENINGS.has(event_id), event_id)
	# 选题避开最近说过的话。
	var recent: Array[String] = []
	for i in 9:
		var topic: int = dialogue.pick_topic(2, recent)
		for line in dialogue.REPLIES[2][topic]:
			assert(not recent.has(line))
		recent.append(str(dialogue.REPLIES[2][topic][0]))
	for stage in 4:
		assert(dialogue.REPLIES[stage].size() == dialogue.TOPICS.size())
