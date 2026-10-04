extends SceneTree

func _initialize() -> void:
	for kind in ["slash", "heavy", "frost", "shield", "gather", "water", "wind", "mountain", "curse"]:
		var source := Image.load_from_file("res://art/effects/ink_%s_source_v1.png" % kind)
		if source == null:
			quit(1)
			return
		var cutout := source.get_region(source.get_used_rect())
		var factor := minf(688.0 / cutout.get_width(), 688.0 / cutout.get_height())
		cutout.resize(roundi(cutout.get_width() * factor), roundi(cutout.get_height() * factor), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(768, 768, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		output.blit_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), Vector2i((768 - cutout.get_width()) / 2, (768 - cutout.get_height()) / 2))
		if output.save_png("res://art/effects/ink_%s_vfx_v1.png" % kind) != OK:
			quit(1)
			return
	quit()
