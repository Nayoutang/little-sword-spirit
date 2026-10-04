extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for step in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	battle.companion_reason_label.text = "“这一手，我来。”"
	await capture("res://.godot/battle-ui-art-normal.png")
	battle.enemy_count = 3
	battle.enemy_roles.assign(["swordsman", "guardian", "hexer"])
	battle.enemy_hps.assign([40, 48, 34])
	battle.enemy_max_hps.assign([40, 48, 34])
	battle.enemy_guards.assign([0, 8, 0])
	battle.enemy_strengths.assign([0, 0, 0])
	battle.enemy_attack_reductions.assign([0, 0, 0])
	battle.enemy_vulnerabilities.assign([2, 0, 0])
	battle._build_enemy_display()
	battle._roll_enemy_intents()
	battle._refresh_ui()
	battle.companion_reason_label.text = "“先看清他们的动作，别急着把所有牌都打完。这一剑我来接，你留住连击，下轮我们再一起出手。”"
	for card in range(8):
		battle._show_card_in_slot(battle.hand.size(), card)
	battle._refresh_ui()
	await capture("res://.godot/battle-ui-art-many.png")
	print("Battle UI artwork preview completed.")
	quit()
