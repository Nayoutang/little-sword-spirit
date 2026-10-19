extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	var backdrop := ColorRect.new()
	backdrop.color = Color("e8e2d2")
	backdrop.size = Vector2(1920, 1080)
	root.add_child(backdrop)
	for index in range(9):
		var face = load("res://scripts/ui/card_face.gd").new()
		face.position = Vector2(65 + index % 5 * 365, 35 + int(index / 5) * 515)
		face.size = Vector2(300, 440)
		root.add_child(face)
		face.set_player_card(34 + index)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/build-routes-card-faces-v1.png")
	print("Build route card preview complete")
	quit(0)
