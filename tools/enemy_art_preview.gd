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
	battle.companion_reason_label.text = "“影剑客正在蓄力，守卫有护盾，咒师打算塞入心魔。这回合我来接这一剑，你保留连击，下轮再一起出手。别急着把所有牌都打完，先看清楚他们的意图。”"
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/enemy-art-preview.png")
	battle._animate_enemy_action(0, "attack")
	battle._animate_enemy_action(1, "guard")
	battle._animate_enemy_action(2, "curse")
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/enemy-actions-preview.png")
	var action_effect = preload("res://scripts/ui/companion_action_effect.gd")
	for card_id in action_effect.PROFILES:
		battle._show_companion_flash(card_id)
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/companion-%s-preview.png" % card_id)
		await create_timer(0.5).timeout
	battle._damage_enemy_at(0, 999)
	battle._refresh_ui()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/enemy-death-preview.png")
	battle.companion_reason_label.text = "“影剑客正在蓄力，守卫有护盾，咒师打算塞入心魔。这回合我来接这一剑，你保留连击，下轮再一起出手。别急着把所有牌都打完，先看清楚他们的意图。”"
	battle._show_companion_dialogue()
	for index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/companion-dialogue-preview.png")
	quit()
