extends SceneTree

# 保留原稿；统一敌人的透明画布和脚底基线。
func _initialize() -> void:
	for role in ["thread_puppet", "puppet_blade", "thread_master", "stand_in_box", "thread_blade_boss", "troupe_watcher"]:
		var source := Image.load_from_file("res://art/enemies/chapter_two/%s_source_v1.png" % role)
		if source == null or source.detect_alpha() == Image.ALPHA_NONE:
			printerr("Missing image or alpha: " + role)
			quit(1)
			return
		print("Source %s: %s alpha=%s corner=%s" % [role, source.get_size(), source.detect_alpha(), source.get_pixel(0, 0)])
		var cutout := source.get_region(source.get_used_rect())
		var factor := minf(672.0 / cutout.get_width(), 800.0 / cutout.get_height())
		cutout.resize(roundi(cutout.get_width() * factor), roundi(cutout.get_height() * factor), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(768, 896, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		output.blit_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), Vector2i((768 - cutout.get_width()) / 2, 848 - cutout.get_height()))
		if output.save_png("res://art/enemies/chapter_two/%s_sprite_v1.png" % role) != OK:
			quit(1)
			return
	quit(0)
