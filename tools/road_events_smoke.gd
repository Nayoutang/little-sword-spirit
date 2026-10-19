extends SceneTree

# 问号节点「路遇」：每个事件每个选项都能结算；选牌/移除可断点恢复且不重复领取；本趟不重复抽到。
const Road = preload("res://scripts/data/road_events.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func _fresh_run(state) -> void:
	state._reset_slot_state()
	state.intro_done = true
	state.start_new_run()
	state.set_player_hp(60)
	state.pending_event = state.EventType.UNKNOWN


func _open(state, event_id: String):
	state.checkpoint("event", {"road_event": event_id})
	var event = load("res://scenes/event.tscn").instantiate()
	root.add_child(event)
	return event


func run() -> void:
	assert(OS.get_environment("APPDATA").contains("road-events-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var total := 0
	for event_id in Road.EVENTS:
		var options: Array = Road.EVENTS[event_id].options
		check(options.size() >= 2 and options.size() <= 3, event_id + " 选项数")
		for index in range(options.size()):
			_fresh_run(state)
			var event = _open(state, event_id)
			check(event.road_event_id == event_id and event.road_buttons.size() == options.size(), event_id + " 按钮")
			var deck_before: int = state.deck.size()
			event._choose_road_option(index)
			if event.card_choices.visible:
				var cards: Array = state.room_checkpoint("event").cards
				check(cards.size() == 3, event_id + " 三选一")
				if str(options[index].effects[0].get("card", "")) == "rare" or event_id == "wounded_swordsman":
					var db = root.get_node("CardDatabase")
					for card_id in cards:
						check(db.get_rarity(card_id) != db.RARITY_COMMON, event_id + " 只出罕见以上")
				event._choose_card(cards[0])
				check(state.deck.size() == deck_before + 1, event_id + " 加牌")
			elif event.removal_scroll != null and event.removal_scroll.visible:
				event._remove_card(0)
				check(state.deck.size() == deck_before - 1, event_id + " 移除")
			check(event.finishing and event.continue_button != null, "%s/%d 结算并等待继续" % [event_id, index])
			check(state.expedition_checkpoint.phase == "map", event_id + " 回到地图存档点")
			var last: Dictionary = state.current_run_journal.back()
			check(last.category == "event" and last.details.get("road_event", "") == event_id, event_id + " 记录事实")
			check(state.player_hp >= 1 and state.player_hp <= state.player_max_hp, event_id + " 生命范围")
			event.free()
			total += 1

	# 数值：涉水扣 8；温泉回 25。
	_fresh_run(state)
	var bridge = _open(state, "broken_bridge")
	bridge._choose_road_option(0)
	check(state.player_hp == 52, "涉水扣 8")
	# 断点恢复：同一组候选，不重复扣血。
	var cards: Array = state.room_checkpoint("event").cards.duplicate()
	bridge.free()
	var resumed = load("res://scenes/event.tscn").instantiate()
	root.add_child(resumed)
	check(resumed.card_choices.visible and state.room_checkpoint("event").cards == cards, "选牌恢复同一组候选")
	check(state.player_hp == 52 and resumed.road_event_id == "broken_bridge", "恢复后不重复扣血")
	resumed._choose_card(cards[0])
	resumed.free()
	# 移除可恢复。
	_fresh_run(state)
	var stone = _open(state, "whetstone")
	stone._choose_road_option(0)
	stone.free()
	var resumed_stone = load("res://scenes/event.tscn").instantiate()
	root.add_child(resumed_stone)
	check(resumed_stone.removal_scroll != null and resumed_stone.removal_scroll.visible, "移除界面恢复")
	resumed_stone.free()
	# 条件不足时禁用。
	_fresh_run(state)
	state.set_player_hp(5)
	var weak = _open(state, "broken_bridge")
	check(weak.road_buttons[0].disabled and not weak.road_buttons[1].disabled, "生命不足不能涉水")
	weak._choose_road_option(0)
	check(not weak.finishing, "禁用选项点不动")
	weak.free()
	# 雾中岔路读信：信够时往左是好结果。
	_fresh_run(state)
	state.hidden_trust = 30
	var fog = _open(state, "foggy_fork")
	fog._choose_road_option(0)
	check(state.player_hp == 75 and state.hidden_trust == 31, "信她往左：回 15 血并 +1 信")
	fog.free()
	_fresh_run(state)
	state.hidden_trust = 0
	fog = _open(state, "foggy_fork")
	fog._choose_road_option(0)
	check(state.player_hp == 52, "信不够：往左扣 8")
	fog.free()
	# 本趟不重复抽到。
	_fresh_run(state)
	var seen: Array[String] = []
	for i in Road.EVENTS.size():
		state.pending_event = state.EventType.UNKNOWN
		state.checkpoint("event")
		var event = load("res://scenes/event.tscn").instantiate()
		root.add_child(event)
		check(not seen.has(event.road_event_id), "本趟不重复：" + event.road_event_id)
		seen.append(event.road_event_id)
		event._choose_road_option(event.road_buttons.size() - 1)
		event.free()
	# 宝箱照旧。
	_fresh_run(state)
	state.pending_event = state.EventType.TREASURE
	state.checkpoint("event")
	var chest = load("res://scenes/event.tscn").instantiate()
	root.add_child(chest)
	check(chest.road_event_id.is_empty() and chest.main_choices.visible, "宝箱不走路遇")
	chest.free()
	print("ROAD EVENTS: %s (%d options, failures=%d)" % ["PASS" if failures == 0 else "FAIL", total, failures])
	quit(1 if failures > 0 else 0)
