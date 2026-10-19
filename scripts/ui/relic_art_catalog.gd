extends RefCounted

static func path_for(id: String) -> String:
	if not preload("res://scripts/data/relic_database.gd").DEFINITIONS.has(id):
		return ""
	return "res://art/relics/%s_v1.png" % id
