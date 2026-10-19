extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/dice-ui-%s.png" % label)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var table = load("res://scripts/home/liar_dice_table.gd").new()
	table.seed_value = 42
	root.add_child(table)
	await shot("opening")
	table.rules_panel.show()
	await shot("rules")
	table.rules_panel.hide()
	table._choose_face(4)
	table._on_bid()
	await shot("thinking")
	await create_timer(1.6).timeout
	await shot("response")
	if not table.revealed:
		table._on_open()
	await shot("reveal")
	table.start_game()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await shot("compact")
	table._on_leave()
	await process_frame
	print("Dice UI preview complete")
	quit()
