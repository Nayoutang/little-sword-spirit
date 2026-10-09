extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	state.pending_encounter = state.EncounterType.NORMAL
	for path in ["res://scenes/map.tscn", "res://scenes/battle_reward.tscn", "res://scenes/event.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		var library = scene.get_node("CardLibrary")
		var before: Array = state.deck.duplicate()
		library.open_deck()
		assert(library.shown_entries.size() == 7 and state.deck.size() == 15)
		assert(library.heading.text == "本趟牌组")
		assert(not library.shown_entries.any(func(entry: Dictionary): return entry.owner == "小墨" or entry.id == 13 or entry.id == 14))
		assert(library.detail_text.text.contains("本趟持有：5 张"))
		assert(state.deck == before)
		library.close()
		state.deck.append(CardDatabase.RETAIN_SHIELD)
		library.open_deck()
		assert(library.shown_entries.size() == 8)
		library.search.text = "留盾"
		library._refresh()
		assert(library.shown_entries.size() == 1)
		assert(library.detail_text.text.contains("本趟持有：1 张"))
		state.deck.erase(CardDatabase.RETAIN_SHIELD)
		library._refresh()
		assert(library.shown_entries.is_empty())
		library.close()
		if path.ends_with("map.tscn"):
			assert(not scene.get_node("MapContent").get_children().any(func(node: Node): return node.has_meta("depth_label")))
			assert(scene.get_node("MapUI/Title").text.begins_with("山行图卷 · "))
			assert(scene.get_node("MapUI/DeckButton").text == "查看牌组")
		if "--deck-screenshot" in OS.get_cmdline_user_args() and path.ends_with("map.tscn"):
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/map-no-depth-labels.png")
			library.open_deck()
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/current-deck.png")
		scene.free()
	print("DECK VIEW: PASS (map/rewards/events, counts, acquire/remove refresh, read-only, map labels)")
	quit()
