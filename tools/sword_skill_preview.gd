extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("#e4dfcf")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var cards = load("res://scripts/data/companion_card_database.gd")
	var ids: Array = cards.INTENT_DEFINITIONS.keys()
	for index in range(ids.size()):
		var face = load("res://scripts/ui/card_face.gd").new()
		face.position = Vector2(150 + index % 4 * 420, 120 + index / 4 * 430)
		face.size = Vector2(240, 336)
		layer.add_child(face)
		face.set_companion_card(ids[index])
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/sword-skills.png")
	print("SWORD SKILL PREVIEW: saved")
	quit()
