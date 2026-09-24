class_name MiniGameSession
extends RefCounted

# 小游戏共用约定：沿用小墨的人设提示，追加规则；每轮只读结构化 JSON；
# 结束时只向关键事实记忆写一条结果。字段和回合状态由各游戏负责。


func system_prompt(context: Array[String]) -> String:
	var sections := context.duplicate()
	sections.append(rules_prompt())
	return "\n\n".join(sections)


func rules_prompt() -> String:
	return ""


func round_request(_action: String, _player_text: String, _context: Dictionary = {}) -> String:
	return ""


func result_summary(_player_won: bool, _reason: String) -> String:
	return ""


func record_result(player_won: bool, reason: String) -> String:
	return result_summary(player_won, reason)


func parse_round_reply(content: String) -> Dictionary:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```json"):
		cleaned = cleaned.trim_prefix("```json").trim_suffix("```").strip_edges()
	elif cleaned.begins_with("```"):
		cleaned = cleaned.trim_prefix("```").trim_suffix("```").strip_edges()
	var parsed: Variant = JSON.parse_string(cleaned)
	if not parsed is Dictionary:
		return {}
	return parsed if validate_round_reply(parsed) else {}


func validate_round_reply(_reply: Dictionary) -> bool:
	return false
