extends SceneTree

# 首先 --headless --script 本脚本 -- --normalize，之后有渲染器运行生成牌面联排。
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cards/expansion-20261015.json"))
	if "--normalize" in OS.get_cmdline_user_args():
		var report: Array = []
		for asset in manifest.assets:
			var source := Image.load_from_file("res://" + asset.source)
			if source == null or source.detect_alpha() == Image.ALPHA_NONE:
				printerr("Missing transparent source: " + str(asset.id))
				quit(1)
				return
			var factor := minf(496.0 / source.get_width(), 426.0 / source.get_height())
			var scaled := source.duplicate() as Image
			scaled.resize(roundi(source.get_width() * factor), roundi(source.get_height() * factor), Image.INTERPOLATE_LANCZOS)
			var output := Image.create(512, 442, false, Image.FORMAT_RGBA8)
			output.fill(Color.TRANSPARENT)
			output.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i((512 - scaled.get_width()) / 2, (442 - scaled.get_height()) / 2))
			if output.save_png("res://" + asset.runtime) != OK:
				quit(1)
				return
			report.append({"id": asset.id, "path": asset.runtime, "size": [512, 442], "source_size": [source.get_width(), source.get_height()], "alpha": output.detect_alpha(), "sha256": FileAccess.get_sha256("res://" + asset.runtime)})
		var file := FileAccess.open("res://art/cards/expansion-raster-qa.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		print("Normalized 14 new covers with transparent padding")
		quit(0)
		return
	root.get_node("RunState").suppress_persistence = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("e8e2d2")
	backdrop.size = Vector2(1920, 1080)
	layer.add_child(backdrop)
	for index in range(manifest.assets.size()):
		var face = load("res://scripts/ui/card_face.gd").new()
		face.position = Vector2(35 + index % 7 * 270, 45 + int(index / 7) * 500)
		face.size = Vector2(250, 350)
		layer.add_child(face)
		face.set_player_card(int(manifest.assets[index].id))
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/new-card-faces-20261015.png")
	print("New card art preview complete")
	quit(0)
