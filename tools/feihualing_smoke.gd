extends SceneTree

# 每次修改飞花令后先运行：Godot --headless --path . --script res://tools/feihualing_smoke.gd
# 固定 JSON 走与游戏相同的状态机和对白组装；不联网、不写存档。

var game := FeihualingGame.new("剑")
var failed := false


func _initialize() -> void:
	print("=== 飞花令冒烟对白 ===")
	_step("opening", "", {
		"intent": "chat", "player_line_valid": true, "player_line_source": "",
		"comment": "", "my_line": "十年磨一剑，霜刃未曾试",
		"my_line_source": "贾岛《剑客》", "prompt_next": "接着来。", "give_up": false,
	})
	_step("turn", "宝剑锋从磨砺出，梅花香自苦寒来", {
		"intent": "line", "player_line_valid": true, "player_line_source": "",
		"comment": "……拿我说事？醉里挑灯看剑，梦回吹角连营",
		"my_line": "醉里挑灯看剑，梦回吹角连营",
		"my_line_source": "辛弃疾《破阵子》", "prompt_next": "这回看你怎么接。", "give_up": false,
	})
	_step("turn", "剑外忽传收蓟北，初闻涕泪满衣常", {
		"intent": "line", "player_line_valid": true, "player_line_source": "杜甫《闻官军收河南河北》",
		"comment": "（耳朵红了）‘常’？手快了吧。",
		"my_line": "一身转战三千里，一剑曾当百万师",
		"my_line_source": "王维《老将行》", "prompt_next": "别想太久。", "give_up": false,
	})
	_step("turn", "想不出来了，我投降", {
		"intent": "surrender", "player_line_valid": true, "player_line_source": "",
		"comment": "这么快就退？再想想。", "my_line": "", "my_line_source": "",
		"prompt_next": "", "give_up": false,
	})
	_step("turn", "你刚刚是不是笑了？", {
		"intent": "chat", "player_line_valid": true, "player_line_source": "",
		"comment": "我笑？你看错了。", "my_line": "", "my_line_source": "",
		"prompt_next": "这回看你怎么接。", "give_up": false,
	})
	_step("turn", "出处？", {
		"intent": "challenge", "player_line_valid": true,
		"player_line_source": "王维《老将行》", "comment": "王维《老将行》。这句我还认得。",
		"my_line": "", "my_line_source": "", "prompt_next": "", "give_up": false,
	})
	var vague_end := game.process_reply("turn", "我不会", "surrender", {
		"intent": "surrender", "player_line_valid": true, "player_line_source": "",
		"comment": "行吧，就这样。", "my_line": "", "my_line_source": "",
		"prompt_next": "", "give_up": false,
	})
	if not vague_end.get("retry_closure", false) or game.surrender_count != 1:
		_fail("含糊的结局未重试，或提前推进了状态")
	_step("turn", "我不会", {
		"intent": "surrender", "player_line_valid": true, "player_line_source": "",
		"comment": "好吧，这局归我。你也不算太差。", "my_line": "", "my_line_source": "",
		"prompt_next": "", "give_up": false,
	})
	if game.player_rounds != 2 or game.surrender_count != 1:
		_fail("本地轮数或认输状态错误")
	print("=== 结束：%s ===" % ("失败" if failed else "通过"))
	quit(1 if failed else 0)


func _step(action: String, player_text: String, data: Dictionary) -> void:
	if not player_text.is_empty():
		print("玩家：%s" % player_text)
	var parsed := game.parse_round_reply(JSON.stringify(data))
	if parsed.is_empty():
		_fail("JSON 解析失败")
		return
	var hint := game.classify_input(player_text) if action == "turn" else ""
	var result := game.process_reply(action, player_text, hint, parsed)
	if result.get("retry_line", false):
		_fail("固定出句未通过校验：%s" % result.get("reason", ""))
		return
	var speech := str(result.get("speech", ""))
	if speech.contains("（") or speech.contains("(") or speech.contains("耳朵红了"):
		_fail("对白含舞台说明：%s" % speech)
	if speech.is_empty():
		_fail("小墨对白为空")
	else:
		print("小墨：%s" % speech)
	if action == "turn" and player_text == "宝剑锋从磨砺出，梅花香自苦寒来":
		if speech.count("醉里挑灯看剑，梦回吹角连营") != 1:
			_fail("小墨出句重复")
	if player_text == "你刚刚是不是笑了？" and speech.contains("这回看你怎么接"):
		_fail("催促语重复")
	if player_text == "想不出来了，我投降" and (result.get("finished", false) or game.surrender_count != 1):
		_fail("同一条输入被累计为多次认输")
	if player_text == "我不会" and (not result.get("finished", false) or result.get("player_won", true)):
		_fail("第二次认输未以小墨获胜结束")


func _fail(message: String) -> void:
	failed = true
	push_error(message)
