from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / "scripts/ui/card_face.gd"
text = path.read_text(encoding="utf-8")
start = text.index("func _draw_full(")
end = text.index("\n\nfunc _short_stat", start)
text = text[:start] + '''func _draw_full(info: Dictionary) -> void:
	var font := get_theme_default_font()
	var frame: Texture2D = load("res://art/ui/battle/frame.png")
	draw_texture_rect(frame, Rect2(0, 0, 200, 220), false)
	var image_name := "thrust"
	match str(info["motif"]):
		"shield", "gate", "deflect", "sheath", "echo", "oath", "return", "escort", "banner", "yin": image_name = "guard"
		"eye", "breath", "shadow", "lotus", "resonance", "wind", "grind": image_name = "gather"
		"waves", "water_cut", "leaves", "frost": image_name = "waves"
	var art: Texture2D = load("res://art/ui/battle/" + image_name + ".png")
	draw_texture_rect(art, Rect2(12, 12, 176, 112), false)
	draw_circle(Vector2(25, 25), 20, Color("#163f3c"))
	draw_arc(Vector2(25, 25), 20, 0, TAU, 36, Color("#c9a569"), 2, true)
	draw_string(font, Vector2(6, 33), str(info["cost"]), HORIZONTAL_ALIGNMENT_CENTER, 38, 24, Color("#fff6e6"))
	draw_string(font, Vector2(13, 150), str(info["name"]), HORIZONTAL_ALIGNMENT_CENTER, 174, 23, Color("#182826"))
	draw_string(font, Vector2(15, 174), str(info["primary"]), HORIZONTAL_ALIGNMENT_CENTER, 170, 17, Color("#223531"))
	draw_string(font, Vector2(15, 195), str(info["secondary"]), HORIZONTAL_ALIGNMENT_CENTER, 170, 15, Color("#304941"))
	draw_string(font, Vector2(15, 211), str(info["type"]), HORIZONTAL_ALIGNMENT_CENTER, 170, 11, Color("#665433"))
''' + text[end:]
path.write_text(text, encoding="utf-8")
path = root / "scripts/ui/player_combat_status.gd"
text = path.read_text(encoding="utf-8")
start = text.index("func _draw()")
text = text[:start] + '''func _draw() -> void:
	var font := ThemeDB.fallback_font
	var hud: Texture2D = load("res://art/ui/battle/hud.png")
	draw_texture_rect(hud, Rect2(-12, -3, 980, 87), false)
	var titles := ["生命", "精力", "护盾", "连击"]
	var values := ["%d / %d" % [hp, max_hp], "%d / %d" % [energy, max_energy], str(shield), str(combo)]
	for index in range(4):
		var rect: Rect2 = BOXES[index]
		draw_string(font, rect.position + Vector2(20, 35), titles[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENTS[index])
		draw_string(font, rect.position + Vector2(78, 36), values[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#fff4dd"))
		if index == 0:
			var bar := Rect2(20, 48, 240, 7)
			draw_rect(bar, Color("#3c2526"))
			bar.size.x *= clampf(float(hp) / maxf(max_hp, 1), 0, 1)
			draw_rect(bar, ACCENTS[0].lerp(Color.WHITE, hit_flash))
		elif index == 1:
			for point in range(mini(maxi(energy, max_energy), 10)):
				draw_circle(rect.position + Vector2(25 + point * 16, 55), 5, ACCENTS[1] if point < energy else Color("#3d5356"))
		elif index == 2:
			draw_string(font, rect.position + Vector2(20, 56), "敌方回合末清空", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENTS[index])
		else:
			draw_string(font, rect.position + Vector2(20, 56), "每层攻击 +2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENTS[index])
	if not boon.is_empty():
		draw_string(font, Vector2(20, 104), boon.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, 916, 18, Color("#f8e4bd"))
'''
path.write_text(text, encoding="utf-8")
'''
'''
