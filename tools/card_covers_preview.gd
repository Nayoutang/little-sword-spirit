extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	root.get_node("RunState").suppress_persistence = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("#e4dfcf")
	background.size = Vector2(1920, 1080)
	layer.add_child(background)
	var face_script = load("res://scripts/ui/card_face.gd")
	var companion_script = load("res://scripts/data/companion_card_database.gd")
	var player_ids: Array = root.get_node("CardDatabase").DEFINITIONS.keys()
	player_ids.sort()
	var companion_ids: Array = companion_script.ORDERED_IDS.duplicate()
	companion_ids.append_array(companion_script.INTENT_DEFINITIONS.keys())
	for index in range(player_ids.size() + companion_ids.size()):
		var face = face_script.new()
		face.position = Vector2(20 + index % 10 * 190, 14 + index / 10 * 260)
		face.size = Vector2(180, 252)
		layer.add_child(face)
		if index < player_ids.size():
			face.set_player_card(int(player_ids[index]))
		else:
			face.set_companion_card(str(companion_ids[index - player_ids.size()]))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/all-card-faces-v1.png")
	print("ALL_CARD_FACES_PREVIEW saved")
	quit()
