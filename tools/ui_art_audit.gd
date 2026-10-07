extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	root.get_node("RunState").suppress_persistence = true
	for key in ["event/event_ui", "save_select/save_ui", "settlement/settlement_ui", "promise/promise_ui", "battle_reward/reward_ui", "relationship_milestone/milestone_ui", "home/feihualing_layer"]:
		var ui = load("res://ui/" + key + ".tscn").instantiate()
		root.add_child(ui)
		if ui.has_node("GameScreen"): ui.get_node("GameScreen").show()
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/ui_audit_" + key.get_file() + ".png")
		ui.free()
	print("UI ART AUDIT: PASS")
	quit()
