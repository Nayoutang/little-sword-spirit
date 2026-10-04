extends SceneTree

func _initialize() -> void:
	for pose in ["idle", "swing", "heavy", "guard", "gather", "intent"]:
		var path := "res://art/character/sword_spirit_chibi_cutout.png" if pose == "idle" else "res://art/character/xiaomo_%s_source_v1.png" % pose
		var source := Image.load_from_file(path)
		if source == null:
			quit(1)
			return
		var cutout := source.get_region(source.get_used_rect())
		var scale_factor := minf(720.0 / cutout.get_width(), 800.0 / cutout.get_height())
		cutout.resize(roundi(cutout.get_width() * scale_factor), roundi(cutout.get_height() * scale_factor), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(768, 896, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		output.blit_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), Vector2i((768 - cutout.get_width()) / 2, 848 - cutout.get_height()))
		if output.save_png("res://art/character/xiaomo_%s_pose_v1.png" % pose) != OK:
			quit(1)
			return
		print("Normalized pose: ", pose)
	quit()
