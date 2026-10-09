extends RefCounted

# Stable IDs; persisted scene paths remain compatible with existing saves.
const PATHS := {
	"save_select": "res://scenes/save_select.tscn",
	"home": "res://scenes/home.tscn",
	"intro": "res://scenes/intro.tscn",
	"finale": "res://scenes/finale.tscn",
	"promise": "res://scenes/promise.tscn",
	"map": "res://scenes/map.tscn",
	"battle": "res://scenes/battle.tscn",
	"event": "res://scenes/event.tscn",
	"adventure": "res://scenes/adventure.tscn",
	"poetry": "res://scenes/expedition_poetry.tscn",
	"reward": "res://scenes/battle_reward.tscn",
	"settlement": "res://scenes/settlement.tscn",
}

static func resolve(destination: String) -> String:
	if PATHS.has(destination):
		return str(PATHS[destination])
	return destination if destination in PATHS.values() else ""
