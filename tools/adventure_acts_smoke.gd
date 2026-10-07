extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	for index in range(5):
		for branch in range(2):
			state.player_hp = 30
			var scene = load("res://scenes/adventure.tscn").instantiate()
			scene.adventure_index = index
			scene.force_offline = true
			root.add_child(scene)
			for step in range(25):
				if scene.choices.visible:
					break
				scene._advance()
			assert(scene.story_page_index == 1 and scene.choices.visible)
			var choice: Dictionary = scene.current_adventure["choices"][branch]
			scene._resolve_choice(choice)
			assert(scene.story_page_index == 2 and scene.response_ready)
			assert(not scene.get_node("ResultUI/Card").visible)
			var hp: int = state.player_hp
			scene._resolve_choice(choice)
			assert(state.player_hp == hp)
			var page = scene.get_node("AdventureUI/Page")
			for step in range(8):
				page.reveal_next()
			assert(scene.get_node("ResultUI/Card").visible)
			assert(scene.get_node("ResultUI/Card/Story").text == choice["result"])
			assert(scene.get_node("ResultUI/Card/Effect").text.contains(scene.pending_effect_text))
			assert(not scene.story_label.visible)
			if index == 2 and branch == 0 and "--adventure-screenshot" in OS.get_cmdline_user_args():
				await create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://art/concepts/adventure_result_implemented.png")
			scene.free()
	print("ADVENTURE ACTS: PASS (5 events, 10 branches)")
	quit()
