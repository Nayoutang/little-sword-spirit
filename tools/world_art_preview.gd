extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.chapter = 3
	state.chapter_trip = 1
	state.finale_state = "completed"
	state.finale_mode = "victory"
	state.run_relics.assign(["old_umbrella", "letter_envelope", "broken_string", "green_tassel", "heart_mirror"])
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := TextureRect.new()
	background.texture = load("res://art/backgrounds/ch3_sword_tomb_battle_v1.png")
	background.size = Vector2(1920,1080)
	layer.add_child(background)
	var relics = load("res://scripts/ui/relic_view.gd").install(layer, layer, Vector2(100,100))
	relics.open()
	await shot("res://art/previews/relic-inventory-v1.png")
	layer.free()
	state.pending_encounter = state.EncounterType.BOSS
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	await shot("res://art/previews/ch3-sword-tomb-battle-v1.png")
	quit(0)
