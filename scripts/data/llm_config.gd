class_name LLMConfig
extends RefCounted

# 所有 LLM 功能共用这一份配置。
# 接口需兼容 OpenAI 的 POST /chat/completions 请求与响应格式。
const API_URL := "https://api.deepseek.com/chat/completions"
const MODEL_NAME := "deepseek-chat"
const API_KEY_ENV := "LITTLE_SWORD_SPIRIT_API_KEY"
# 密钥不进版本库：先读环境变量，再读 secrets/llm_api_key.txt（已被 .gitignore 排除；
# 导出预设包含 *.txt，所以试玩包仍会带上它）。正式发布时建议改由自己的代理服务器签发请求。
const API_KEY_FILE := "res://secrets/llm_api_key.txt"
const SYSTEM_PROMPT_PATH := "res://prompts/system_prompt.txt"


static func get_api_key() -> String:
	var api_key := OS.get_environment(API_KEY_ENV).strip_edges()
	if api_key.is_empty() and FileAccess.file_exists(API_KEY_FILE):
		api_key = FileAccess.get_file_as_string(API_KEY_FILE).strip_edges()
	return api_key


static func load_system_prompt() -> String:
	if not FileAccess.file_exists(SYSTEM_PROMPT_PATH):
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	var file := FileAccess.open(SYSTEM_PROMPT_PATH, FileAccess.READ)
	if file == null:
		return "你是小墨，一把嘴硬心软的古剑剑灵。始终以角色身份简短回应。"
	return file.get_as_text().strip_edges()
