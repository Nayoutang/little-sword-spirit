extends Control

const HUD_ART = preload("res://art/ui/battle/hud.png")
var hud_style: StyleBoxTexture

var hp := 90
var max_hp := 90
var energy := 3
var max_energy := 3
var shield := 0
var combo := 0
var attack_chain := 0
var cloud_active := false
var cloud_triggered := false
var boon := ""
var hit_flash := 0.0:
	set(value):
		hit_flash = value
		queue_redraw()
var flash_tween: Tween

const BOXES := [Rect2(45, 0, 235, 88), Rect2(292, 0, 220, 88), Rect2(524, 0, 200, 88), Rect2(736, 0, 220, 88)]
const ACCENTS := [Color("#e89584"), Color("#9ed8ce"), Color("#74c7bd"), Color("#e6c17e")]

func update_values(health: int, health_max: int, points: int, points_max: int, guard: int, chain: int, next_boon: String) -> void:
	hp = health
	max_hp = health_max
	energy = points
	max_energy = points_max
	shield = guard
	combo = chain
	boon = next_boon
	queue_redraw()

func flash_damage() -> void:
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	hit_flash = 1.0
	flash_tween = create_tween()
	flash_tween.tween_property(self, "hit_flash", 0.0, 0.35)

func _get_tooltip(at: Vector2) -> String:
	if BOXES[0].has_point(at):
		return "生命：%d/%d。生命归零则本场失败。" % [hp, max_hp]
	if BOXES[1].has_point(at):
		return "精力：%d，基础上限%d。出牌消耗，新回合恢复；长风可额外增加。" % [energy, max_energy]
	if BOXES[2].has_point(at):
		return "护盾：%d。先吸收本轮敌人总伤害，敌方回合结算后清空剩余护盾。" % shield
	return "连击层数：%d，每层攻击+2。连续攻击：%d，非攻击手牌清零；特殊技保持但不增加。行云：%s。" % [combo, attack_chain, "本轮已触发" if cloud_triggered else ("生效" if cloud_active else "未生效")]

func update_attack_chain(count: int, active: bool, triggered: bool) -> void:
	attack_chain = count
	cloud_active = active
	cloud_triggered = triggered
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if hud_style == null:
		hud_style = StyleBoxTexture.new()
		hud_style.texture = HUD_ART
		hud_style.texture_margin_left = 74
		hud_style.texture_margin_right = 58
		hud_style.texture_margin_top = 24
		hud_style.texture_margin_bottom = 24
	draw_style_box(hud_style, Rect2(-12, -3, 980, 87))
	var titles := ["生命", "精力", "护盾", "连击"]
	var values := ["%d / %d" % [hp, max_hp], "%d / %d" % [energy, max_energy], str(shield), str(combo)]
	for index in range(4):
		var rect: Rect2 = BOXES[index]
		draw_string(font, rect.position + Vector2(20, 35), titles[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENTS[index])
		draw_string(font, rect.position + Vector2(78, 36), values[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#fff4dd"))
		if index == 0:
			var bar := Rect2(65, 48, 190, 7)
			draw_rect(bar, Color("#3c2526"))
			bar.size.x *= clampf(float(hp) / maxf(max_hp, 1), 0, 1)
			draw_rect(bar, ACCENTS[0].lerp(Color.WHITE, hit_flash))
		elif index == 1:
			for point in range(mini(maxi(energy, max_energy), 10)):
				draw_circle(rect.position + Vector2(25 + point * 16, 55), 5, ACCENTS[1] if point < energy else Color("#3d5356"))
		elif index == 2:
			draw_string(font, rect.position + Vector2(20, 56), "敌方回合末清空", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENTS[index])
		else:
			draw_string(font, rect.position + Vector2(20, 56), "连续攻击 %d%s" % [attack_chain, " · 云✓" if cloud_triggered else (" · 云" if cloud_active else "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENTS[index])
	if not boon.is_empty():
		draw_string(font, Vector2(20, 104), boon.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, 916, 18, Color("#f8e4bd"))
