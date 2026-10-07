extends SceneTree

func _initialize() -> void:
	var game := FeihualingGame.new("春")
	var reply := {
		"intent": "line", "player_line_valid": true, "player_line_source": "孟浩然《春晓》",
		"comment": "怎么只回了半句，另一半想不起来了吗？",
		"my_line": "春眠不觉晓，处处闻啼鸟", "my_line_source": "孟浩然《春晓》",
		"prompt_next": "这一轮我拿下了。接着来，下一句轮到你。", "give_up": false,
	}
	var bad: Dictionary = reply.duplicate()
	bad["my_line"] = "春风又绿江南岸，明月何时照我还"
	var result := game.process_reply("turn", "春眠不觉晓", "line", bad)
	assert(result.get("retry_line", false) and game.lines.is_empty())
	bad = reply.duplicate()
	bad["prompt_next"] = "这局归我，下回再比。"
	result = game.process_reply("turn", "春眠不觉晓", "line", bad)
	assert(result.get("retry_line", false) and game.completed_partial_rounds == 0)
	result = game.process_reply("turn", "春眠不觉晓", "line", reply)
	assert(not result.get("finished", true) and not result.get("retry_line", true))
	assert(game.player_rounds == 0 and game.completed_partial_rounds == 1)
	assert(game.lines.size() == 1 and game.lines[0]["speaker"] == "小墨")
	assert(result["speech"].contains("春眠不觉晓，处处闻啼鸟") and result["speech"].contains("这一轮我拿下"))
	assert(game.has_line("处处闻啼鸟"))
	reply["comment"] = ""
	reply["my_line"] = "春色满园关不住，一枝红杏出墙来"
	reply["prompt_next"] = ""
	result = game.process_reply("turn", "春风又绿江南岸，明月何时照我还", "line", reply)
	assert(not result.get("finished", true) and game.player_rounds == 1)
	assert(game.completed_partial_rounds == 1)
	result = game.incomplete_preflight("如梦令")
	assert(result.get("finished", false) and not result.get("player_won", true))
	var title_first := FeihualingGame.new("梦")
	result = title_first.incomplete_preflight("《如梦令》")
	assert(not result.get("finished", true) and title_first.incomplete_answer_count == 1)
	result = title_first.incomplete_preflight("梦啼妆泪红阑干")
	assert(result.get("finished", false) and title_first.incomplete_answer_count == 2)
	var two_halves := FeihualingGame.new("春")
	result = two_halves.incomplete_fallback("春眠不觉晓")
	assert(not result.get("finished", true) and two_halves.incomplete_answer_count == 1)
	result = two_halves.incomplete_preflight("春风又绿江南岸")
	assert(result.get("finished", false))
	var two_titles := FeihualingGame.new("梦")
	two_titles.incomplete_preflight("如梦令")
	assert(two_titles.incomplete_preflight("水调歌头").get("finished", false))
	var short_first := FeihualingGame.new("水")
	result = short_first.incomplete_preflight("水花")
	assert(not result.get("finished", true) and short_first.incomplete_answer_count == 1)
	assert(short_first.player_rounds == 0 and short_first.lines.is_empty())
	assert(short_first.incomplete_preflight("水花").get("finished", false))
	var model_reject := FeihualingGame.new("水")
	var rejected: Dictionary = reply.duplicate()
	rejected["player_line_valid"] = false
	rejected["comment"] = "这局归我。"
	result = model_reject.process_reply("turn", "水水水水", "unknown", rejected)
	assert(not result.get("finished", true) and not result["speech"].contains("这局归我"))
	assert(model_reject.process_reply("turn", "水水水水", "unknown", rejected).get("finished", false))
	var casual := FeihualingGame.new("水")
	assert(casual.incomplete_preflight("水？").is_empty() and casual.incomplete_answer_count == 0)
	print("FEIHUALING PARTIAL: PASS")
	quit()
