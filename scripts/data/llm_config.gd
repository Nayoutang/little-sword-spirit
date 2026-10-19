class_name LLMConfig
extends RefCounted

# 公开客户端仅访问代理；上游密钥由 Cloudflare Secret 持有。
const API_URL := ""
const MODEL_NAME := ""
const SYSTEM_PROMPT_PATH := "res://prompts/system_prompt.txt"


static func is_available() -> bool:
	# 比赛版禁止一切联网，命令行参数也不能启用。
	return false


static func request_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "X-Game-Client: little-sword-spirit"])


static func load_system_prompt() -> String:
	if not FileAccess.file_exists(SYSTEM_PROMPT_PATH):
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	var file := FileAccess.open(SYSTEM_PROMPT_PATH, FileAccess.READ)
	if file == null:
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	return file.get_as_text().strip_edges()
