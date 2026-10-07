extends Control

const FRAME_ART = preload("res://art/ui/battle/frame.png")
const Art = preload("res://scripts/ui/card_art_catalog.gd")
const FONT = preload("res://ui/shared/comic_font.tres")

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")

const PLAYER_MOTIFS := {
	0: "slash", 1: "shield", 2: "eye", 3: "cleave", 4: "gate",
	5: "leaves", 6: "waves", 7: "curse", 8: "breath", 9: "shadow",
	10: "break", 11: "deflect", 12: "sheath", 13: "beam", 14: "lotus",
	15: "wind", 16: "slash", 17: "shield", 18: "gate", 19: "deflect",
}
const COMPANION_MOTIFS := {
	"quick_slash": "slash", "guard_echo": "echo", "follow_up": "crossed",
	"clean_cut": "clean", "lead_momentum": "arrow", "oath_guard": "oath",
	"return_guard": "return", "escort": "escort", "heart_resonance": "resonance",
	"lone_judgment": "lone", "frost_cold": "frost", "ten_steps": "steps",
	"grind_sword": "grind", "cut_water": "water_cut", "long_wind": "wind",
	"behead_loulan": "behead", "yin_mountain": "yin", "few_return": "banner",
}

var player_card_id := -1
var effective_cost := -1
var companion_card_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func set_player_card(card_id: int) -> void:
	player_card_id = card_id
	effective_cost = -1
	companion_card_id = ""
	queue_redraw()


func set_companion_card(card_id: String) -> void:
	companion_card_id = card_id
	player_card_id = -1
	queue_redraw()


func set_effective_cost(value: int) -> void:
	if effective_cost != value:
		effective_cost = value
		queue_redraw()


func _draw() -> void:
	if player_card_id < 0 and companion_card_id.is_empty():
		return
	var info := _card_info()
	var compact := size.y < 145.0
	var base_size := Vector2(300.0, 76.0) if compact else Vector2(200.0, 280.0)
	var scale_factor: float = minf(size.x / base_size.x, size.y / base_size.y)
	draw_set_transform((size - base_size * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)
	if compact:
		_draw_compact(info)
	else:
		_draw_full(info)
	draw_set_transform(Vector2.ZERO)


func _card_info() -> Dictionary:
	if player_card_id >= 0:
		var definition: Dictionary = CardDatabase.get_definition(player_card_id)
		var card_type := str(definition.get("type", "技巧"))
		var accent := Color("#d66e62")
		match card_type:
			"防御": accent = Color("#74c7bd")
			"技巧": accent = Color("#d9c47f")
			"能力": accent = Color("#d9c47f")
			"诅咒": accent = Color("#ac83bd")
			"特殊技": accent = Color("#75d8df")
			"终极技": accent = Color("#f1bc75")
		var stats := _player_stats(player_card_id, definition)
		return {"name": str(definition["name"]), "cost": str(effective_cost if effective_cost >= 0 else definition["cost"]),
			"type": card_type, "accent": accent, "motif": PLAYER_MOTIFS.get(player_card_id, "slash"),
			"primary": stats[0], "secondary": stats[1]}
	var definition := CompanionCards.get_definition(companion_card_id)
	var category := "自保"
	var accent := Color("#83bce0")
	if definition.has("poem"):
		category = "剑意"
		accent = Color("#e37a70")
	elif definition.get("stance", "") == CompanionCards.STANCE_INVEST:
		category = "援护"
		accent = Color("#e7c879")
	var stats := _companion_stats(companion_card_id, definition)
	return {"name": str(definition.get("name", "小墨牌")), "cost": "墨",
		"type": category, "accent": accent,
		"motif": COMPANION_MOTIFS.get(companion_card_id, "slash"),
		"primary": stats[0], "secondary": stats[1]}


func _player_stats(card_id: int, definition: Dictionary) -> Array[String]:
	match card_id:
		CardDatabase.PARRY: return ["格挡5·反击4伤至多2次", "清空连击·反击积势至下回合"]
		CardDatabase.RETAIN_SHIELD: return ["剩余护盾跨回合保留", "能力·包括小墨护盾"]
		CardDatabase.SHIELD_STRIKE: return ["当前护盾100%伤害", "不耗盾·连击+1·不吃连击加伤"]
		CardDatabase.FLOWING_CLOUD: return ["三连攻：抽1 / 精力+1", "能力·每回合一次"]
		CardDatabase.CHASE_WIND: return ["基础伤害 %d" % int(definition["damage"]), "连续攻击减费·连击+1"]
		CardDatabase.STATUS: return ["抽牌 1", "连击清零"]
		CardDatabase.CURSE: return ["无法打出", "占据手牌"]
		CardDatabase.TUNE_BREATH: return ["抽牌 1", "每回合限 1 次"]
		CardDatabase.SHADOW_STEP: return ["抽牌 2", "技巧"]
		CardDatabase.UNLOAD_FORCE: return ["敌攻 -%d" % int(definition["attack_reduction"]), "下次攻击生效"]
		CardDatabase.HIDE_EDGE: return ["格挡 %d" % int(definition["block"]), "回合末保留连击"]
		CardDatabase.FLOWING_LIGHT: return ["基础伤害 %d" % int(definition["damage"]), "需/耗 %d 连击" % int(definition["combo_required"])]
		CardDatabase.BRILLIANCE: return ["基础伤害 %d" % int(definition["damage"]), "需 %d 连击·清零" % int(definition["combo_required"])]
	if definition.has("block"):
		return ["格挡 %d" % int(definition["block"]), "连击清零"]
	if card_id == CardDatabase.SWEEP:
		return ["全体基础 %d" % int(definition["damage"]), "连击 +1"]
	if card_id == CardDatabase.BREAK_EDGE:
		return ["基础伤害 %d" % int(definition["damage"]), "连击 +1·易伤 %d" % int(definition["vulnerable"])]
	return ["基础伤害 %d" % int(definition.get("damage", 0)), "连击 +%d" % int(definition.get("combo", 0))]


func _companion_stats(card_id: String, definition: Dictionary) -> Array[String]:
	match card_id:
		CompanionCards.LEAD_MOMENTUM: return ["下次攻击 ×2", "让给玩家"]
		CompanionCards.ESCORT: return ["格挡 6", "下次攻击 +4"]
		CompanionCards.FROST_COLD: return ["全体伤害 5", "敌攻 -2"]
		CompanionCards.GRIND_SWORD: return ["本回合不造成伤害", "连击保留到下回合"]
		CompanionCards.CUT_WATER: return ["下回合首次防御/状态", "不清空连击层数"]
		CompanionCards.LONG_WIND: return ["下回合精力 +1", "让给玩家"]
		CompanionCards.YIN_MOUNTAIN: return ["拦下一个敌人的全部攻击段", "按修正后总伤害选敌"]
		CompanionCards.FEW_RETURN: return ["格挡 5 / 16", "低血时取 16"]
		CompanionCards.OATH_GUARD: return ["格挡 10", "守约时 +3"]
		CompanionCards.HEART_RESONANCE: return ["伤害 12+连击×3", "保留连击"]
		CompanionCards.LONE_JUDGMENT: return ["伤害 12+连击×4", "连击清零"]
		CompanionCards.TEN_STEPS: return ["伤害 4+连击×4", "击杀连击 +1"]
		CompanionCards.BEHEAD_LOULAN: return ["伤害 14", "对最高血敌人"]
	if definition.has("damage") and definition.has("combo_scale"):
		return ["伤害 %d+连击×%d" % [int(definition["damage"]), int(definition["combo_scale"])], "连击 +1"]
	if definition.has("damage"):
		return ["伤害 %d" % int(definition["damage"]), "对低血敌人"]
	if definition.has("block"):
		return ["格挡 %d" % int(definition["block"]), "守护玩家"]
	return [str(definition.get("description", "")), "小墨出牌"]


func _draw_full(info: Dictionary) -> void:
	var font := FONT
	draw_texture_rect(FRAME_ART, Rect2(0, 0, 200, 280), false)
	_draw_cover(Rect2(12, 12, 176, 152))
	draw_circle(Vector2(25, 25), 20, Color("#163f3c"))
	draw_arc(Vector2(25, 25), 20, 0, TAU, 36, Color("#c9a569"), 2, true)
	draw_string(font, Vector2(6, 33), str(info["cost"]), HORIZONTAL_ALIGNMENT_CENTER, 38, 24, Color("#fff6e6"))
	draw_string(font, Vector2(13, 190), str(info["name"]), HORIZONTAL_ALIGNMENT_CENTER, 174, 23, Color("#182826"))
	_draw_fitted_text(str(info["primary"]), Vector2(15, 221), 170, 17, Color("#223531"))
	_draw_fitted_text(str(info["secondary"]), Vector2(15, 244), 170, 15, Color("#304941"))
	draw_string(font, Vector2(15, 265), str(info["type"]), HORIZONTAL_ALIGNMENT_CENTER, 170, 11, Color("#665433"))


func _draw_cover(rect: Rect2) -> void:
	var cover := Art.texture_for(player_card_id, companion_card_id)
	if cover == null:
		return
	var factor := minf(rect.size.x / cover.get_width(), rect.size.y / cover.get_height())
	var cover_size := cover.get_size() * factor
	draw_texture_rect(cover, Rect2(rect.position + (rect.size - cover_size) * 0.5, cover_size), false)


func _draw_fitted_text(value: String, origin: Vector2, width: float, preferred_size: int, color: Color) -> void:
	var font_size := preferred_size
	while font_size > 10 and FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	draw_string(FONT, origin, value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _short_stat(value: String) -> String:
	for prefix in ["全体基础 ", "全体伤害 ", "基础伤害 ", "伤害 ", "格挡 ", "抽牌 ", "敌攻 ", "下回合精力 "]:
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return value


func _draw_stat_icon(value: String, accent: Color) -> void:
	var center := Vector2(27, 169)
	if value.begins_with("格挡") or value.begins_with("挡一次"):
		_shield(accent, center, 0.28)
	elif value.begins_with("抽牌"):
		draw_rect(Rect2(19, 159, 14, 19), accent, false, 1.7)
		draw_line(Vector2(22, 164), Vector2(30, 164), accent, 1.3)
	elif value.begins_with("伤害") or value.begins_with("基础伤害") or value.begins_with("全体"):
		_sword(accent, center, 0.28)
	elif value.begins_with("无法"):
		draw_arc(center, 10, 0, TAU, 20, accent, 2)
		draw_line(Vector2(20, 176), Vector2(34, 162), accent, 2)
	else:
		draw_circle(center, 8, accent.darkened(0.4))
		draw_arc(center, 8, 0, TAU, 20, accent, 2)


func _draw_compact(info: Dictionary) -> void:
	var accent: Color = info["accent"]
	var font := FONT
	draw_rect(Rect2(0, 0, 300, 76), Color("#152427"))
	draw_rect(Rect2(2, 2, 296, 72), accent, false, 2.0)
	draw_circle(Vector2(27, 29), 20, accent.darkened(0.45))
	draw_arc(Vector2(27, 29), 20, 0, TAU, 28, accent, 2.0)
	draw_string(font, Vector2(7, 38), str(info["cost"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color("#fff7e5"))
	_draw_cover(Rect2(51, 6, 60, 64))
	draw_string(font, Vector2(112, 30), str(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, 178, 20, Color("#fff4dd"))
	draw_string(font, Vector2(112, 56), str(info["primary"]), HORIZONTAL_ALIGNMENT_LEFT, 178, 16, accent.lightened(0.3))


func _draw_ornaments(accent: Color, center: Vector2, factor: float) -> void:
	var faint := Color(accent.r, accent.g, accent.b, 0.22)
	draw_arc(center, 42.0 * factor, 0.15, PI - 0.15, 24, faint, 1.0)
	draw_arc(center, 42.0 * factor, PI + 0.15, TAU - 0.15, 24, faint, 1.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var point := center + Vector2.RIGHT.rotated(angle) * 45.0 * factor
		draw_circle(point, 2.0 * factor, accent)


func _line(a: Vector2, b: Vector2, color: Color, center: Vector2, factor: float, width := 3.0) -> void:
	draw_line(center + a * factor, center + b * factor, color, width * factor, true)


func _path(points: Array[Vector2], color: Color, center: Vector2, factor: float, width := 3.0) -> void:
	for index in range(points.size() - 1):
		_line(points[index], points[index + 1], color, center, factor, width)


func _sword(color: Color, center: Vector2, factor: float, angle := -0.68) -> void:
	var direction := Vector2.UP.rotated(angle)
	var cross := direction.orthogonal()
	_line(-direction * 24, direction * 30, color, center, factor, 5.0)
	_line(-direction * 12 - cross * 12, -direction * 12 + cross * 12, color, center, factor, 4.0)
	_line(-direction * 24 - cross * 5, -direction * 24 + cross * 5, color, center, factor, 3.0)


func _shield(color: Color, center: Vector2, factor: float) -> void:
	_path([Vector2(-25, -26), Vector2(25, -26), Vector2(22, 10), Vector2(0, 31), Vector2(-22, 10), Vector2(-25, -26)], color, center, factor, 3.2)
	_line(Vector2(0, -19), Vector2(0, 20), color.darkened(0.15), center, factor, 2.0)


func _draw_motif(motif: String, color: Color, center: Vector2, factor: float) -> void:
	match motif:
		"slash", "clean":
			_sword(color, center, factor)
			if motif == "slash": _path([Vector2(-35, 14), Vector2(0, -20), Vector2(34, -27)], color.lightened(0.3), center, factor, 2.0)
		"shield": _shield(color, center, factor)
		"eye":
			_path([Vector2(-35, 0), Vector2(-18, -13), Vector2(0, -18), Vector2(18, -13), Vector2(35, 0), Vector2(18, 13), Vector2(0, 18), Vector2(-18, 13), Vector2(-35, 0)], color, center, factor)
			draw_circle(center, 8 * factor, color)
		"cleave":
			_sword(color, center + Vector2(4, -5) * factor, factor, 0.12)
			_path([Vector2(-35, 30), Vector2(-15, 4), Vector2(0, 20), Vector2(17, -5), Vector2(36, 30)], color, center, factor)
		"gate":
			_path([Vector2(-31, 30), Vector2(-31, -25), Vector2(31, -25), Vector2(31, 30)], color, center, factor, 5)
			_line(Vector2(0, -24), Vector2(0, 30), color, center, factor)
		"leaves":
			for offset: Vector2 in [Vector2(-22, 13), Vector2(0, -12), Vector2(22, 8)]:
				var p := center + offset * factor
				draw_arc(p, 11 * factor, -1.0, 2.4, 12, color, 3 * factor)
		"waves", "water_cut":
			for row in range(3):
				var y := -19 + row * 18
				_path([Vector2(-34, y), Vector2(-15, y - 9), Vector2(4, y + 6), Vector2(22, y - 8), Vector2(35, y)], color, center, factor, 2.7)
			if motif == "water_cut": _sword(color.lightened(0.35), center, factor * 0.8, 0.8)
		"curse":
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				_line(direction * 16, direction * 36, color, center, factor, 3)
			draw_arc(center, 17 * factor, 0, TAU, 24, color, 3 * factor)
		"breath", "wind":
			for radius in [12.0, 24.0, 36.0]:
				draw_arc(center, radius * factor, -PI * 0.75, PI * 0.65, 26, color, 2.5 * factor)
			if motif == "breath": draw_circle(center, 5 * factor, color)
		"shadow", "steps":
			for index in range(3):
				var p := center + Vector2(-28 + index * 25, 19 - index * 18) * factor
				draw_circle(p, 7 * factor, color)
				_line(Vector2(-36 + index * 25, 30 - index * 18), Vector2(-44 + index * 25, 36 - index * 18), color, center, factor, 2)
		"break":
			_sword(color, center, factor, 0.15)
			_path([Vector2(-23, -8), Vector2(0, -2), Vector2(-9, 9), Vector2(20, 16)], color.lightened(0.35), center, factor, 2)
		"deflect":
			_sword(color, center, factor, 0.8)
			draw_arc(center, 31 * factor, PI * 0.1, PI * 1.5, 25, color.lightened(0.3), 3 * factor)
		"sheath":
			_line(Vector2(-27, 27), Vector2(22, -28), color, center, factor, 8)
			_line(Vector2(-30, 18), Vector2(-18, 29), color.lightened(0.3), center, factor, 3)
		"beam":
			_sword(color, center, factor, 0.0)
			for angle in range(0, 360, 60):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				_line(direction * 23, direction * 39, color.lightened(0.25), center, factor, 2)
		"lotus":
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				_line(direction * 8, direction * 34, color, center, factor, 6)
			draw_circle(center, 9 * factor, color.lightened(0.4))
		"echo", "oath", "return", "escort", "banner", "yin":
			_shield(color, center, factor * 0.85)
			match motif:
				"echo": draw_arc(center, 38 * factor, -PI * 0.8, PI * 0.25, 20, color, 2 * factor)
				"oath": draw_circle(center, 9 * factor, color.lightened(0.35))
				"return": _path([Vector2(-38, 10), Vector2(-28, 25), Vector2(-16, 21)], color, center, factor)
				"escort":
					_line(Vector2(-31, -8), Vector2(-42, -25), color, center, factor)
					_line(Vector2(31, -8), Vector2(42, -25), color, center, factor)
				"banner": _line(Vector2(0, -40), Vector2(0, -8), color.lightened(0.35), center, factor, 3)
				"yin": _path([Vector2(-20, 8), Vector2(0, -10), Vector2(20, 8)], color.lightened(0.35), center, factor)
		"crossed", "resonance":
			_sword(color, center + Vector2(-8, 0) * factor, factor * 0.85, -0.55)
			_sword(color.lightened(0.25), center + Vector2(8, 0) * factor, factor * 0.85, 0.55)
			if motif == "resonance": draw_circle(center, 9 * factor, color.lightened(0.5))
		"arrow":
			_line(Vector2(-35, 18), Vector2(25, -20), color, center, factor, 5)
			_path([Vector2(9, -28), Vector2(27, -20), Vector2(26, -2)], color, center, factor)
		"lone":
			_sword(color, center, factor, 0.0)
			draw_arc(center, 33 * factor, 0.4, PI * 1.6, 27, color.darkened(0.1), 2 * factor)
		"frost":
			for angle in range(0, 360, 60):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				_line(Vector2.ZERO, direction * 35, color, center, factor, 3)
		"grind":
			_sword(color, center, factor, 0.45)
			_line(Vector2(-30, 14), Vector2(31, 22), color.lightened(0.25), center, factor, 5)
		"behead":
			_sword(color, center + Vector2(9, -5) * factor, factor, 0.3)
			_path([Vector2(-35, 28), Vector2(-16, 0), Vector2(0, 18)], color, center, factor)
