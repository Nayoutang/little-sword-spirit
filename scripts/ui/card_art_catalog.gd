class_name CardArtCatalog
extends RefCounted

# Every card owns its cover; a shared frame is deliberately independent of art.
const PLAYER_FILES := {
	0: "res://art/ui/battle/thrust.png", 1: "res://art/ui/battle/guard.png",
	2: "res://art/ui/battle/gather.png", 3: "res://art/cards/player/03_mountain_cleave_v1.png",
	4: "res://art/cards/player/04_iron_gate_v1.png", 5: "res://art/cards/player/05_sweep_leaves_v1.png",
	6: "res://art/ui/battle/waves.png", 7: "res://art/cards/player/07_inner_demon_v1.png",
	8: "res://art/cards/player/08_breath_v1.png", 9: "res://art/cards/player/09_shadow_step_v1.png",
	10: "res://art/cards/player/10_break_edge_v1.png", 11: "res://art/cards/player/11_deflect_force_v1.png",
	12: "res://art/cards/player/12_hidden_edge_v1.png", 13: "res://art/cards/player/13_flowing_light_v1.png",
	14: "res://art/cards/player/14_brilliance_v1.png", 15: "res://art/cards/player/15_flowing_cloud_v1.png",
	16: "res://art/cards/player/16_chase_wind_v1.png", 17: "res://art/cards/player/17_shield_strike_v1.png",
	18: "res://art/cards/player/18_retain_shield_v1.png", 19: "res://art/cards/player/19_parry_v1.png",
}
const COMPANION_FILES := {
	"quick_slash": "res://art/cards/companion/quick_slash_v1.png",
	"guard_echo": "res://art/cards/companion/guard_echo_v1.png",
	"follow_up": "res://art/cards/companion/follow_up_v1.png",
	"clean_cut": "res://art/cards/companion/clean_cut_v1.png",
	"lead_momentum": "res://art/cards/companion/lead_momentum_v1.png",
	"oath_guard": "res://art/cards/companion/oath_guard_v1.png",
	"return_guard": "res://art/cards/companion/return_guard_v1.png",
	"escort": "res://art/cards/companion/escort_v1.png",
	"heart_resonance": "res://art/cards/companion/heart_resonance_v1.png",
	"lone_judgment": "res://art/cards/companion/lone_judgment_v1.png",
	"frost_cold": "res://art/cards/companion/frost_cold_v1.png",
	"ten_steps": "res://art/cards/companion/ten_steps_v1.png",
	"grind_sword": "res://art/cards/companion/grind_sword_v1.png",
	"cut_water": "res://art/cards/companion/cut_water_v1.png",
	"long_wind": "res://art/cards/companion/long_wind_v1.png",
	"behead_loulan": "res://art/cards/companion/behead_loulan_v1.png",
	"yin_mountain": "res://art/cards/companion/yin_mountain_v1.png",
	"few_return": "res://art/cards/companion/few_return_v1.png",
}
static var _textures: Dictionary = {}

static func player_path(card_id: int) -> String:
	return str(PLAYER_FILES.get(card_id, ""))

static func companion_path(card_id: String) -> String:
	return str(COMPANION_FILES.get(card_id, ""))

static func texture_for(player_id: int, companion_id: String = "") -> Texture2D:
	var path := player_path(player_id) if player_id >= 0 else companion_path(companion_id)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path] as Texture2D
