extends Control
const PaintedVFX = preload("res://scripts/ui/painted_combat_vfx.gd")

var kind := "attack"
var tint := Color("#74c7bd")
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, 0.45)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var effect_kind := "slash" if kind == "attack" else ("shield" if kind == "guard" else "curse")
	PaintedVFX.paint(self, effect_kind, progress, tint)
