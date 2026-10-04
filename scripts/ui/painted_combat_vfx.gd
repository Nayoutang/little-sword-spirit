extends RefCounted

const SLASH = preload("res://art/effects/ink_slash_vfx_v1.png")
const HEAVY = preload("res://art/effects/ink_heavy_vfx_v1.png")
const FROST = preload("res://art/effects/ink_frost_vfx_v1.png")
const SUPPORT := {
	"shield": preload("res://art/effects/ink_shield_vfx_v1.png"),
	"gather": preload("res://art/effects/ink_gather_vfx_v1.png"),
	"water": preload("res://art/effects/ink_water_vfx_v1.png"),
	"wind": preload("res://art/effects/ink_wind_vfx_v1.png"),
	"mountain": preload("res://art/effects/ink_mountain_vfx_v1.png"),
	"curse": preload("res://art/effects/ink_curse_vfx_v1.png"),
}

static func paint(canvas: Control, kind: String, progress: float, tint: Color, strength: int = 1) -> void:
	var texture: Texture2D = FROST if kind == "frost" else (HEAVY if strength >= 4 else SLASH)
	if SUPPORT.has(kind):
		texture = SUPPORT[kind]
	# Fast emergence and a longer trailing fade, with hand-painted transparent edges.
	var emergence := clampf(progress / 0.16, 0, 1)
	var opacity := emergence * pow(1 - progress, 0.65)
	var extent := minf(canvas.size.x, canvas.size.y) * (0.82 + emergence * 0.2 + progress * 0.12)
	if kind == "gather":
		extent *= 1.1 - progress * 0.35
	elif kind == "wind":
		extent *= 0.9 + progress * 0.25
	var center := canvas.size * 0.5
	var color := Color.WHITE.lerp(tint, 0.18)
	color.a = opacity * (0.8 if kind == "frost" else 1.0)
	var angle := -0.12 + progress * 0.22
	if kind in ["shield", "mountain", "water"]:
		angle = 0
	elif kind == "curse":
		angle = progress * 0.3
	canvas.draw_set_transform(center, angle, Vector2.ONE)
	canvas.draw_texture_rect(texture, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), false, color)
	if kind in ["dash", "resonance"]:
		color.a *= 0.45
		canvas.draw_set_transform(center + Vector2(12, -8), angle + 0.65, Vector2.ONE)
		canvas.draw_texture_rect(SLASH, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), false, color)
	canvas.draw_set_transform(Vector2.ZERO)
