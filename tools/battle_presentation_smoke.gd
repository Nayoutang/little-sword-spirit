extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	var battle = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await create_timer(0.4).timeout
	battle.pending_attack_index = 0
	battle._refresh_ui()
	await create_timer(0.3).timeout
	assert(battle.hand_buttons[0].get_node("PaintedFace").scale.x > 1.09)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/concepts/battle_selection_implemented.png")
	battle._show_pile_contents(true)
	await create_timer(0.3).timeout
	assert(battle.pile_grid.get_child_count() == battle.draw_pile.size())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/concepts/battle_pile_implemented.png")
	battle.pile_popup.hide()
	battle._show_pile_contents(false)
	assert(battle.pile_grid.get_child_count() == battle.discard_pile.size())
	battle.pile_popup.hide()
	print("BATTLE PRESENTATION: PASS")
	quit()
