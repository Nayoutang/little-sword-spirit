extends Node


func _ready() -> void:
	var failed := false
	var controller := FeihualingController.new()
	var seen := {}
	var previous := ""
	for index in range(FeihualingGame.CHARACTERS.size()):
		var keyword := controller._draw_keyword()
		if seen.has(keyword):
			push_error("令字池尚未抽完就重复：%s" % keyword)
			failed = true
		seen[keyword] = true
		previous = keyword
	controller.last_keyword = previous
	if controller._draw_keyword() == controller.last_keyword:
		push_error("新一轮令字与上一局重复")
		failed = true
	var chat = load("res://scripts/home/home_chat.gd").new()
	for sample in [
		["来玩飞花令，以柳为令", "柳"],
		["对诗吧，令字：梅", "梅"],
		["飞花令：竹", "竹"],
		["飞花令", ""],
	]:
		var actual: String = chat._requested_feihualing_keyword(sample[0])
		if actual != sample[1]:
			push_error("指定令字解析失败：%s -> %s" % [sample[0], actual])
			failed = true
	if FeihualingGame.new("柳").keyword != "柳" or FeihualingGame.is_valid_keyword("柳花"):
		push_error("自选令字校验失败")
		failed = true
	controller.free()
	chat.free()
	print("飞花令令字测试：%s" % ("失败" if failed else "通过"))
	get_tree().quit(1 if failed else 0)
