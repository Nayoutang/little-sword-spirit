extends Node

const LIFE_GUARD := "life_guard"
const RESONANCE := "resonance"
const PERSEVERANCE := "perseverance"

const DEFINITIONS := {
	LIFE_GUARD: {"name": "灵剑护主", "description": "每场战斗首次受到致命伤害时保留1点生命。"},
	RESONANCE: {"name": "剑鸣余韵", "description": "每场战斗首次发动流光或华彩后，至少保留1层连击。"},
	PERSEVERANCE: {"name": "不屈剑意", "description": "回合结束清空连击后，新回合保留1层连击。"},
}

var unlocked: Array[String] = []


func reset() -> void:
	unlocked.clear()


func has_ability(ability_id: String) -> bool:
	return ability_id in unlocked


func unlock(ability_id: String) -> bool:
	if not DEFINITIONS.has(ability_id) or has_ability(ability_id):
		return false
	unlocked.append(ability_id)
	return true


func get_name_for(ability_id: String) -> String:
	return str(DEFINITIONS.get(ability_id, {}).get("name", ability_id))


func get_description(ability_id: String) -> String:
	return str(DEFINITIONS.get(ability_id, {}).get("description", ""))


func get_unlocked_names() -> String:
	if unlocked.is_empty():
		return "暂无"
	var names: Array[String] = []
	for ability_id in unlocked:
		names.append(get_name_for(ability_id))
	return "、".join(names)


func get_prompt_context() -> String:
	if unlocked.is_empty():
		return "【当前已掌握神通】\n暂无。"
	var lines: Array[String] = ["【当前已掌握神通与真实效果】"]
	for ability_id in unlocked:
		lines.append("- %s：%s" % [get_name_for(ability_id), get_description(ability_id)])
	lines.append("当玩家询问神通时，应依据以上真实效果回答，不得虚构、扩大或改变规则；可以用符合小墨人格的自然说法概括，不必像说明书一样逐项复述数值。")
	return "\n".join(lines)


func save_to_config(config: ConfigFile) -> void:
	config.set_value("abilities", "unlocked", unlocked)


func load_from_config(config: ConfigFile) -> void:
	reset()
	var saved: Variant = config.get_value("abilities", "unlocked", [])
	if saved is Array:
		for ability_id in saved:
			if DEFINITIONS.has(str(ability_id)):
				unlocked.append(str(ability_id))
