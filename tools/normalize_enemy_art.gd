extends SceneTree

func _initialize() -> void:
	for role in ["swordsman", "guardian", "hexer"]:
		var source := Image.load_from_file("res://art/enemies/ink_%s_v1.png" % role)
		if source == null:
			quit(1)
			return
		var bounds := source.get_used_rect()
		var cutout := source.get_region(bounds)
		var factor := minf(672.0 / cutout.get_width(), 800.0 / cutout.get_height())
		cutout.resize(roundi(cutout.get_width() * factor), roundi(cutout.get_height() * factor), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(768, 896, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		output.blit_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), Vector2i((768 - cutout.get_width()) / 2, 848 - cutout.get_height()))
		var error := output.save_png("res://art/enemies/ink_%s_sprite_v1.png" % role)
		if error != OK:
			quit(1)
			return
		print("Normalized %s: 768x896, bottom anchor y848" % role)
	quit()
