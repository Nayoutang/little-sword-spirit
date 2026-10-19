extends SceneTree

var spoken: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.finale_state = "locked"
	state.bond_value = 0
	state.bond_stage = 0
	state.feihualing_state = "unlocked"
	root.get_node("SpecialEventManager").reset()
	assert(not LLMConfig.is_available() and LLMConfig.API_URL.is_empty())
	OfflinePoetry.load_library()
	assert(OfflinePoetry.entries.size() > 2000)
	assert(OfflinePoetry.find("十年磨一劍，霜刃未曾試。").line == "十年磨一剑，霜刃未曾试")
	for keyword in OfflinePoetry.keywords():
		var game := FeihualingGame.new(keyword)
		var outcome := OfflinePoetry.play(game, "opening", "")
		assert(not outcome.get("unsupported", false) and not game.last_my_line.is_empty())
		assert(game.last_my_line.contains(keyword))
	var controller = load("res://scripts/home/feihualing_controller.gd").new()
	root.add_child(controller)
	controller.spoken.connect(func(text: String): spoken.append(text))
	for card_id in CompanionCardDatabase.INTENT_DEFINITIONS:
		state.learned_sword_intents.clear()
		controller.cancel()
		var definition: Dictionary = CompanionCardDatabase.INTENT_DEFINITIONS[card_id]
		var poem := str(definition.poem)
		var keyword := str(definition.trigger).substr(0, 1)
		controller.start(keyword)
		assert(controller.game != null)
		assert(not controller.game.has_line(poem))
		controller.submit(poem)
		assert(card_id in state.learned_sword_intents)
		assert(state.learned_sword_intents.size() == 1)
		controller.submit("认输")
		controller.submit("认输")
		assert(controller.game == null)
	controller.start("龘")
	assert(controller.game == null and not controller.busy)
	controller.start("月")
	var rounds: int = controller.game.player_rounds
	controller.submit("月亮喜欢吃饼干，饼干喜欢看月亮")
	assert(controller.game.player_rounds == rounds and spoken.back().contains("暂未收录"))
	controller.submit("提示")
	assert(controller.game.player_rounds == rounds and spoken.back().contains("提示不算出句"))
	controller.cancel()
	state.learned_sword_intents.clear()
	controller.start("剑")
	controller.submit("十年磨一剑，霜刃未曾试")
	controller.submit("满堂花醉三千客，一剑霜寒十四州")
	assert(state.learned_sword_intents == [CompanionCardDatabase.GRIND_SWORD])
	controller.cancel()
	# Known couplets are checked for keyword and repeated use, not model opinion.
	var game := FeihualingGame.new("月")
	OfflinePoetry.play(game, "opening", "")
	var wrong := OfflinePoetry.play(game, "turn", "十年磨一剑，霜刃未曾试")
	assert(wrong.finished and not wrong.player_won)
	game = FeihualingGame.new("剑")
	OfflinePoetry.play(game, "opening", "")
	var half := OfflinePoetry.play(game, "turn", "十年磨一剑")
	assert(not half.finished and game.player_rounds == 0 and game.completed_partial_rounds == 1)
	game = FeihualingGame.new("剑")
	OfflinePoetry.play(game, "opening", "")
	OfflinePoetry.play(game, "turn", "十年磨一剑，霜刃未曾试")
	var repeated := OfflinePoetry.play(game, "turn", "十年磨一劍 霜刃未曾試")
	assert(repeated.finished and not repeated.player_won)
	# Homecoming uses only recorded facts, including promise failure.
	var greeting := OfflineHomeDialogue.homecoming([{"category": "run_result", "summary": "本趟远征最终失败"}, {"category": "promise_result", "summary": "保护约定未兑现"}])
	assert(greeting.contains("没走到最后") and greeting.contains("没做到"))
	# 历练中遇到对诗后，归家时由小墨引出飞花令并开放按钮。
	state.feihualing_state = "pending"
	state.homecoming_pending = true
	var reveal_home = load("res://scenes/home.tscn").instantiate()
	root.add_child(reveal_home)
	assert(state.feihualing_state == "unlocked" and reveal_home.feihualing_button.visible)
	assert(reveal_home.chat_log.get_parsed_text().contains("飞花令"))
	reveal_home.free()
	state.homecoming_pending = false
	var home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	assert(not home.offline_choices.visible and home.offline_choices.get_child_count() == 0 and not home.input.visible)
	assert(home.get_node("ChatUI/ChatPanel").visible)
	home.free()
	state.homecoming_pending = true
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	assert(home.offline_choices.visible and home.offline_choices.get_child_count() == 2)
	assert(home.offline_topic >= 0 and home.offline_topic < OfflineHomeDialogue.TOPICS.size())
	assert(not state.homecoming_pending)
	home._choose_offline_topic(0)
	assert(not home.offline_choices.visible and home.offline_choices.get_child_count() == 0)
	var history: String = home.chat_log.text
	home._choose_offline_topic(1)
	assert(home.chat_log.text == history)
	home._start_feihualing("剑")
	home._on_game_leave()
	assert(not home.offline_choices.visible)
	home.free()
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	assert(not home.offline_choices.visible)
	home.free()
	var events = root.get_node("SpecialEventManager")
	for event_id in events.DEFINITIONS:
		events.reset()
		events.enqueue(event_id)
		state.homecoming_pending = true
		home = load("res://scenes/home.tscn").instantiate()
		root.add_child(home)
		assert(home.offline_event_id == event_id and home.offline_choices.visible)
		var both_resolve: bool = events.DEFINITIONS[event_id].get("both_resolve", false)
		var effects: Array = events.DEFINITIONS[event_id].get("effects", [])
		var trust_before: int = state.hidden_trust
		var attachment_before: int = state.hidden_attachment
		home._choose_offline_topic(1)
		assert(not home.offline_choices.visible)
		if both_resolve:
			# 带抉择的心事：乙也算谈完，并按乙的影响改动信/执。
			assert(not events.has_active_event() and event_id in events.completed_events)
			assert(state.hidden_trust == clampi(trust_before + int(effects[1][0]), 0, 100))
			assert(state.hidden_attachment == clampi(attachment_before + int(effects[1][1]), 0, 100))
			events.reset()
			events.enqueue(event_id)
		else:
			assert(events.has_active_event())
			assert(state.hidden_trust == trust_before and state.hidden_attachment == attachment_before)
		home.free()
		state.homecoming_pending = true
		home = load("res://scenes/home.tscn").instantiate()
		root.add_child(home)
		trust_before = state.hidden_trust
		attachment_before = state.hidden_attachment
		home._choose_offline_topic(0)
		assert(not events.has_active_event() and event_id in events.completed_events and not home.offline_choices.visible)
		assert(state.hidden_trust == clampi(trust_before + int(effects[0][0]), 0, 100))
		assert(state.hidden_attachment == clampi(attachment_before + int(effects[0][1]), 0, 100))
		var event_config := ConfigFile.new()
		events.save_to_config(event_config)
		var serialized := event_config.encode_to_text()
		events.reset()
		assert(event_config.parse(serialized) == OK)
		events.load_from_config(event_config)
		assert(event_id in events.completed_events)
		events.activate_next()
		assert(not events.has_active_event())
		home.free()
	# Multiple queued concerns do not chain within one homecoming.
	events.reset()
	events.enqueue("near_death_clear")
	events.enqueue("bond_skill_comeback")
	state.homecoming_pending = true
	home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	home._choose_offline_topic(0)
	assert(not events.has_active_event() and events.pending_events.size() == 1 and not home.offline_choices.visible)
	home._start_feihualing("剑")
	assert(home.game_controller.game != null and home.game_input.editable)
	home._on_game_leave()
	assert(not home.offline_choices.visible)
	home.free()
	var poetry = load("res://scenes/expedition_poetry.tscn").instantiate()
	root.add_child(poetry)
	poetry.input.text = "剑"
	poetry._submit()
	assert(poetry.controller.game != null and poetry.input.editable)
	poetry.free()
	controller.free()
	print("COMPETITION OFFLINE: PASS (poetry, 8 intents, one random homecoming topic, no repeat on reload/poetry exit, 3 events, queued concern, expedition)")
	quit()
