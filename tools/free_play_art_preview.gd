extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	battle.enemy_count = 3
	battle.enemy_roles.assign(["blood_blade", "ink_healer", "swordsman"])
	battle.enemy_hps.assign([40, 48, 34])
	battle.enemy_max_hps.assign([40, 48, 34])
	battle.enemy_guards.assign([0, 8, 0])
	battle.enemy_strengths.assign([0, 0, 0])
	battle.enemy_attack_reductions.assign([0, 0, 0])
	battle.enemy_vulnerabilities.assign([2, 0, 0])
	battle._build_enemy_display()
	battle._roll_enemy_intents()
	battle._refresh_ui()
	battle.companion_reason_label.text = "“血衣刀客越战越凶，墨医会替同伴回春，影剑客正在蓄力。这回合我来接这一剑，你保留连击，下轮再一起出手。别急着把所有牌都打完，先看清楚他们的意图。”"
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/free-play-art-preview.png")
	quit()
