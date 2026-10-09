class_name LLMConfig
extends RefCounted

# 公开客户端仅访问代理；上游密钥由 Cloudflare Secret 持有。
const API_URL := "https://little-sword-spirit-api.nayoutang3.workers.dev/v1/chat/completions"
const MODEL_NAME := "deepseek-chat"
const SYSTEM_PROMPT_PATH := "res://prompts/system_prompt.txt"


static func is_available() -> bool:
	return "--offline-tests" not in OS.get_cmdline_user_args() and not API_URL.is_empty() and not MODEL_NAME.is_empty()


static func request_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "X-Game-Client: little-sword-spirit"])


static func load_system_prompt() -> String:
	if not FileAccess.file_exists(SYSTEM_PROMPT_PATH):
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	var file := FileAccess.open(SYSTEM_PROMPT_PATH, FileAccess.READ)
	if file == null:
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	return file.get_as_text().strip_edges()
