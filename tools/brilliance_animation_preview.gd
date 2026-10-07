extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	root.get_node("RunState").suppress_persistence = true
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	root.add_child(battle)
	await create_timer(0.2).timeout
	battle._show_ink_event()
	battle.ink_event.animation.pause()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/brilliance-frames"))
	for index in range(21):
		if index > 0:
			battle.ink_event.animation.custom_step(0.08)
		battle.ink_event.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/brilliance-frames/%02d.png" % index)
	print("BRILLIANCE_ANIMATION_PREVIEW saved")
	quit()
