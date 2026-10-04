extends Control
const PaintedVFX = preload("res://scripts/ui/painted_combat_vfx.gd")

const POSES := {
	"quick_slash": "swing", "clean_cut": "swing", "follow_up": "swing",
	"guard_echo": "guard", "oath_guard": "guard", "return_guard": "guard", "escort": "guard", "few_return": "guard", "yin_mountain": "guard",
	"lead_momentum": "gather", "grind_sword": "gather",
	"heart_resonance": "intent", "frost_cold": "intent", "cut_water": "intent", "long_wind": "intent",
	"lone_judgment": "heavy", "ten_steps": "heavy", "behead_loulan": "heavy",
}

const PROFILES := {
	"quick_slash": ["slash", "#e6c17e", 1],
	"clean_cut": ["slash", "#f4e4bd", 2],
	"follow_up": ["slash", "#74c7bd", 3],
	"guard_echo": ["shield", "#74c7bd", 1],
	"oath_guard": ["shield", "#e6c17e", 2],
	"return_guard": ["shield", "#9ed8ce", 2],
	"escort": ["shield", "#74c7bd", 3],
	"lead_momentum": ["gather", "#e6c17e", 2],
	"heart_resonance": ["resonance", "#74c7bd", 3],
	"lone_judgment": ["slash", "#e89584", 4],
	"frost_cold": ["frost", "#b9e9fa", 3],
	"ten_steps": ["dash", "#e6c17e", 3],
	"grind_sword": ["gather", "#c3d9db", 1],
	"cut_water": ["water", "#74c7bd", 3],
	"long_wind": ["wind", "#9ed8ce", 3],
	"behead_loulan": ["slash", "#edb666", 5],
	"yin_mountain": ["mountain", "#9ed8ce", 3],
	"few_return": ["shield", "#e89584", 4],
}

var card_id := "quick_slash"
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, 0.7)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var profile: Array = PROFILES[card_id]
	PaintedVFX.paint(self, str(profile[0]), progress, Color(profile[1]), int(profile[2]))
