extends SceneTree

const Response = preload("res://scripts/data/llm_response.gd")

func _initialize() -> void:
	assert(Response.from_body("bad".to_utf8_buffer()).error == "invalid_api_json")
	for envelope in [{}, {"choices": []}, {"choices": [42]}]:
		assert(Response.from_envelope(envelope).error == "invalid_api_choices")
	assert(Response.from_envelope({"choices": [{"message": []}]}).error == "invalid_api_message")
	assert(Response.from_envelope({"choices": [{"message": {"content": null}}]}).error == "invalid_api_content")
	var valid := {"choices": [{"message": {"content": "千里不留行"}}]}
	assert(Response.from_body(JSON.stringify(valid).to_utf8_buffer()).content == "千里不留行")
	assert(Response.json_object("```json\n{\"reply\":\"你好\"}\n```").reply == "你好")
	assert(Response.json_object("```custom\n{\"card_id\":\"ten_steps\"}\n```", true).card_id == "ten_steps")
	assert(Response.json_object("[]").is_empty())
	assert(Response.json_object("bad").is_empty())
	print("LLM RESPONSE: PASS (invalid envelopes, text validation, fenced JSON, no network)")
	quit(0)
