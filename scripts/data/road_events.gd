class_name RoadEvents
extends RefCounted

# 问号节点的「路遇」事件。每个事件 2～3 个选项，数值代价与收益写在按钮上；
# 羁绊和信/执不显示，只体现在她的反应里。
#
# 效果（按顺序结算）：
#   {"hp": n}           生命 ±n（扣血至少留 1）
#   {"max_hp": n}       生命上限与当前生命 +n
#   {"card": "any"}     三选一加牌；"rare" 只出罕见与稀有
#   {"remove": true}    从牌组移除一张（玩家自选）
#   {"upgrade": true}   磨剑：升级一张牌（玩家自选）
#   {"bond": n}         羁绊 +n（不显示）
#   {"hidden": [信, 执]} 暗线变化（不显示）
#   {"branch": {"if": "chance:0.5" | "trust:20", "then": [...], "else": [...], "then_line": "", "else_line": ""}}
# requires：{"hp_above": n} 当前生命须大于 n；{"deck_min": n} 牌组至少 n 张。

const EVENTS := {
	"ruined_shrine": {
		"title": "荒庙",
		"text": "山腰一座塌了半边的小庙，供桌上还摆着几个没人动过的果子。\n小墨：这地方，好久没人来了。",
		"options": [
			{"text": "上一炷香", "effects": [{"hp": 15}], "line": "小墨：你还挺讲究。走吧，愿这一路都顺。"},
			{"text": "拿走供果", "effects": [{"max_hp": 6}, {"hidden": [-1, 0]}], "line": "小墨：神仙的东西也拿？罢了，你饿着我也不放心。"},
			{"text": "不打扰，继续赶路", "effects": [], "line": "小墨：嗯。走吧。"},
		],
	},
	"broken_bridge": {
		"title": "断桥",
		"text": "过河的木桥断了一截，水不深，但很急。对岸隐约能看见有人落下的包袱。\n小墨：绕上游要多走半天。",
		"options": [
			{"text": "涉水过去", "requires": {"hp_above": 8}, "effects": [{"hp": -8}, {"card": "any"}], "line": "小墨：你的鞋都湿透了。包袱里倒是有点东西。"},
			{"text": "陪她绕上游走", "effects": [{"bond": 2}], "line": "小墨：慢点也好。这一路的风景，我还没好好看过。"},
		],
	},
	"tassel_seller": {
		"title": "卖剑穗的老人",
		"text": "路边一个老人摆着一摊剑穗，红的青的都有。他说不收钱，只换些用不上的旧物。\n小墨盯着那条青色的看了很久。",
		"options": [
			{"text": "拿一页旧剑谱换给她", "requires": {"deck_min": 6}, "effects": [{"remove": true}, {"bond": 3}, {"hidden": [1, 0]}], "line": "小墨：给我的？系上了。好看吗？", "moment": "路边那个卖剑穗的老人那里，你给她换了一条青色的剑穗。"},
			{"text": "看看就走", "effects": [], "line": "小墨：那条青的，挺好看的。走吧。"},
		],
	},
	"wounded_swordsman": {
		"title": "受伤的剑客",
		"text": "一个剑客靠在树下，肩上的伤还在渗血。他看见你腰间的剑，笑了一下：「好剑。」",
		"options": [
			{"text": "分他伤药，替他包扎", "requires": {"hp_above": 10}, "effects": [{"hp": -10}, {"card": "rare"}], "line": "他临走前比划了一招给你看。小墨：这一手，记住了。"},
			{"text": "不管闲事", "effects": [], "line": "小墨：江湖人有江湖人的命。走吧。"},
		],
	},
	"hot_spring": {
		"title": "山间温泉",
		"text": "石缝里冒着热气，是一眼野温泉。\n小墨：我泡了会生锈的。你别笑。",
		"options": [
			{"text": "好好泡一会儿", "effects": [{"hp": 25}], "line": "小墨：舒服了？那就该走了。"},
			{"text": "坐在岸边，陪她说会儿话", "effects": [{"hp": 10}, {"bond": 3}], "line": "小墨：其实我不怎么怕生锈。就是想有人陪着坐一会儿。", "moment": "山间温泉边，你没下水，坐在岸边陪她说了会儿话。"},
		],
	},
	"dice_stall": {
		"title": "路边骰局",
		"text": "茶棚底下有人在掷骰，赌注不是钱，是血契：输的人要挨对方一记。赢了，能挑他箱子里一样东西。",
		"options": [
			{"text": "押上一记（一半可能挨 12，一半可能得稀有牌）", "requires": {"hp_above": 12}, "effects": [{"branch": {"if": "chance:0.5",
				"then": [{"card": "rare"}], "then_line": "骰子停在了大。小墨：手气不错嘛。",
				"else": [{"hp": -12}], "else_line": "骰子停在了小。小墨：疼吧？下回让我来掷。"}}], "line": ""},
			{"text": "让小墨替你掷", "effects": [{"bond": 2}], "line": "她掷出了个四，不大不小。那人摆摆手说不算。小墨：下回我还要玩。"},
			{"text": "不赌", "effects": [], "line": "小墨：稳一点也好。"},
		],
	},
	"whetstone": {
		"title": "溪边磨剑石",
		"text": "溪边有块青石，被人磨出了一道浅槽，看得出很多剑客在这里停过。",
		"options": [
			{"text": "磨剑，顺便理一理招式", "requires": {"deck_min": 6}, "effects": [{"remove": true}], "line": "小墨：去掉不用的，剩下的才利。"},
			{"text": "让她自己泡泡溪水", "effects": [{"hp": 8}, {"bond": 2}, {"hidden": [1, 0]}], "line": "小墨：水是凉的。你也把手伸进来试试。"},
		],
	},
	"rainy_lodge": {
		"title": "夜雨借宿",
		"text": "雨下大了，你们在一间空屋里躲雨。屋子漏风，总得有一个人守着火。",
		"options": [
			{"text": "你睡吧，我守夜", "effects": [{"bond": 3}, {"hidden": [1, 0]}], "line": "第二天醒来，她靠在你肩上。小墨：我没睡。剑不用睡觉。", "moment": "躲雨的那晚，你守着火，让她先歇下。"},
			{"text": "让她守夜，自己睡个好觉", "effects": [{"hp": 20}, {"hidden": [0, 1]}], "line": "小墨：睡吧。有我在，什么都进不来。"},
		],
	},
	"roadside_smith": {
		"title": "路边铁匠",
		"text": "岔路口搭着个铁匠棚，炉子烧得正旺。老铁匠瞄了一眼小墨：「好剑。磨一磨？不收钱，看着顺眼。」\n小墨：……他跟镇口那个，长得有点像。",
		"options": [
			{"text": "请他磨一磨", "effects": [{"upgrade": true}], "line": "小墨：手艺不错。不过下回，还是你来磨。"},
			{"text": "谢过，继续赶路", "effects": [], "line": "小墨：嗯。别人的炉子，我不太习惯。"},
		],
	},
	"blank_stele": {
		"title": "无字剑碑",
		"text": "山坳里立着一块碑，一个字也没有，只有满面的剑痕，深深浅浅，像是很多人对着它练过剑。",
		"options": [
			{"text": "对着碑练一回剑", "requires": {"hp_above": 6}, "effects": [{"hp": -6}, {"upgrade": true}], "line": "小墨：最后那一下收得好。你自己感觉到了吗？"},
			{"text": "让小墨对着碑站一会儿", "effects": [{"bond": 2}, {"hidden": [1, 0]}], "line": "小墨：这里面有一道，是他的。我认得。……走吧。", "moment": "无字剑碑前，小墨认出了一道前主人留下的剑痕。"},
		],
	},
	"lost_child": {
		"title": "迷路的孩子",
		"text": "一个孩子蹲在路边哭，说跟着货郎出来，回不去村子了。\n小墨：别看我。我又不会哄小孩。",
		"options": [
			{"text": "送他回村", "requires": {"hp_above": 5}, "effects": [{"hp": -5}, {"card": "any"}, {"bond": 1}], "line": "村口的老人塞给你们一包东西。小墨：……你哄小孩倒是有一手。"},
			{"text": "给他指了路", "effects": [], "line": "小墨：他会走回去的。……大概吧。"},
		],
	},
	"tea_stall": {
		"title": "茶摊说书",
		"text": "路边茶摊上，说书人正讲到一个银发剑客，说他一人一剑，走遍了七州十三县。",
		"options": [
			{"text": "歇脚，喝碗茶", "effects": [{"hp": 12}], "line": "小墨：茶是凉的。你倒喝得挺香。"},
			{"text": "坐下来，听他讲完", "effects": [{"bond": 2}, {"hidden": [0, 1]}], "line": "小墨：七州十三县？他没去过那么多地方。……不过故事里，就让他去吧。", "moment": "茶摊上，你们听说书人讲了一个银发剑客的故事。"},
		],
	},
	"night_wolves": {
		"title": "夜狼",
		"text": "夜里林子边上亮起几双绿眼睛，绕着你们打转。\n小墨：别怕。它们比你更怕我。",
		"options": [
			{"text": "拔剑赶走它们（一半可能挨咬，一半可能捡到东西）", "requires": {"hp_above": 10}, "effects": [{"branch": {"if": "chance:0.5",
				"then": [{"card": "rare"}], "then_line": "狼群散了，林子里落着一个旧包袱。小墨：运气不错。",
				"else": [{"hp": -10}], "else_line": "有一只扑上来，咬了你一口。小墨：我说什么来着，站我后面。"}}], "line": ""},
			{"text": "生起火，守到天亮", "effects": [{"hp": 6}, {"bond": 1}], "line": "小墨：火别灭了。我替你看着。"},
		],
	},
	"poor_scholar": {
		"title": "落魄书生",
		"text": "破庙里缩着个书生，背着一箱子书，说要进京赶考，盘缠早花光了。",
		"options": [
			{"text": "和他对两句诗", "effects": [{"bond": 1}, {"card": "any"}], "line": "书生送了你们一页抄来的剑诀。小墨：他对得比你好。"},
			{"text": "分他些干粮", "effects": [{"max_hp": 4}], "line": "书生千恩万谢。小墨：做好事也会饿的，你多吃点。"},
		],
	},
	"foggy_fork": {
		"title": "雾中岔路",
		"text": "雾起得很快，两条岔路都看不清尽头。\n小墨：往左。我说不上来为什么，就是觉得该往左。",
		"options": [
			{"text": "信她，往左", "effects": [{"branch": {"if": "trust:20",
				"then": [{"hp": 15}, {"hidden": [1, 0]}], "then_line": "雾散的地方有一户人家，留你们吃了顿热饭。小墨：你看，我没说错吧。",
				"else": [{"hp": -8}], "else_line": "路越走越窄，最后被荆棘挡住了。小墨：是我看错了。对不起。"}}], "line": ""},
			{"text": "自己认路，往右", "effects": [{"hp": -4}], "line": "绕了点远路，总算出了雾。小墨：你不信我啊。下回再说。"},
		],
	},
}


static func pick(exclude: Array[String] = []) -> String:
	var ids: Array[String] = []
	for id in EVENTS:
		if not exclude.has(id):
			ids.append(id)
	if ids.is_empty():
		for id in EVENTS:
			ids.append(id)
	return ids[randi_range(0, ids.size() - 1)]


static func get_event(id: String) -> Dictionary:
	return EVENTS.get(id, {})


static func option_available(option: Dictionary, hp: int, deck_size: int) -> bool:
	var requires: Dictionary = option.get("requires", {})
	if hp <= int(requires.get("hp_above", 0)):
		return false
	if deck_size < int(requires.get("deck_min", 0)):
		return false
	return true


# 按钮上的数值说明：只写看得见的代价与收益。
static func describe(option: Dictionary, halved_heal: bool = false) -> String:
	var parts: Array[String] = []
	for effect: Dictionary in option.get("effects", []):
		if effect.has("hp"):
			var amount := int(effect.hp)
			if halved_heal and amount > 0:
				amount = maxi(int(amount / 2), 1)
			parts.append("恢复 %d 生命" % amount if amount > 0 else "失去 %d 生命" % -amount)
		elif effect.has("max_hp"):
			parts.append("生命上限 +%d" % int(effect.max_hp))
		elif effect.has("card"):
			parts.append("选一张罕见以上的牌" if str(effect.card) == "rare" else "选一张牌")
		elif effect.has("remove"):
			parts.append("移除一张牌")
		elif effect.has("upgrade"):
			parts.append("升级一张牌")
	var label := str(option.get("text", ""))
	if parts.is_empty() or label.contains("（"):
		return label
	return "%s · %s" % [label, "，".join(parts)]
