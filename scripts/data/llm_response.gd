extends RefCounted

# Shared transport envelope parsing; each game still validates its own reply schema.
static func from_body(body: PackedByteArray) -> Dictionary:
	return from_envelope(_parse(body.get_string_from_utf8()))


static func from_envelope(envelope: Variant) -> Dictionary:
	if not envelope is Dictionary:
		return {"error": "invalid_api_json", "content": ""}
	var choices: Variant = envelope.get("choices", [])
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		return {"error": "invalid_api_choices", "content": ""}
	var message: Variant = choices[0].get("message", {})
	if not message is Dictionary:
		return {"error": "invalid_api_message", "content": ""}
	var content: Variant = message.get("content", "")
	if not content is String:
		return {"error": "invalid_api_content", "content": ""}
	return {"error": "", "content": content}


static func json_object(content: String, any_fence_language: bool = false) -> Dictionary:
	var cleaned := content.strip_edges()
	if any_fence_language and cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		var last_fence := cleaned.rfind("```")
		if first_newline >= 0 and last_fence > first_newline:
			cleaned = cleaned.substr(first_newline + 1, last_fence - first_newline - 1).strip_edges()
	elif cleaned.begins_with("```json"):
		cleaned = cleaned.trim_prefix("```json").trim_suffix("```").strip_edges()
	elif cleaned.begins_with("```"):
		cleaned = cleaned.trim_prefix("```").trim_suffix("```").strip_edges()
	var value: Variant = _parse(cleaned)
	return value if value is Dictionary else {}


static func _parse(content: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(content) == OK else null
