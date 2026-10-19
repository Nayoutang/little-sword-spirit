class_name RelicDatabase
extends RefCounted

# 信物：单趟有效，开新的一趟清空。大多和小墨的意向、出牌、留下的机会联动，
# 让「你们怎么配合」也体现在收集上。数值首版，待试玩。

const OLD_SCABBARD := "old_scabbard"
const WHETSTONE_CHIP := "whetstone_chip"
const GREEN_TASSEL := "green_tassel"
const LOVERS_KNOT := "lovers_knot"
const HALF_JADE := "half_jade"
const HEART_MIRROR := "heart_mirror"
const BLADE_INSCRIPTION := "blade_inscription"
const WINE_GOURD := "wine_gourd"
const PEACE_CHARM := "peace_charm"
const BRONZE_BELL := "bronze_bell"
# 2026-10-19 构筑路线信物
const OLD_UMBRELLA := "old_umbrella"
const LETTER_ENVELOPE := "letter_envelope"
const BROKEN_STRING := "broken_string"

const DEFINITIONS := {
	OLD_SCABBARD: {"name": "旧剑鞘", "text": "每场战斗开始时，获得 6 格挡。", "flavor": "鞘口磨得发亮，不知道换过几任主人。", "block": 6},
	WHETSTONE_CHIP: {"name": "磨剑石片", "text": "每场战斗的第一回合，精力 +1。", "flavor": "揣在怀里，出门前摸一下，心里就稳了。", "energy": 1},
	GREEN_TASSEL: {"name": "青色剑穗", "text": "她亮出「守护」意向时，你抽 1 张牌。", "flavor": "她说青色好看。系上以后，就没再解下来过。", "draw": 1},
	LOVERS_KNOT: {"name": "同心结", "text": "她亮出「让给你」意向时，连击 +1。", "flavor": "两股红绳，打成一个解不开的结。", "combo": 1},
	HALF_JADE: {"name": "半块玉佩", "text": "每接住她留下的机会一次，回复 3 生命。", "flavor": "另一半在哪儿，她没说。", "heal": 3},
	HEART_MIRROR: {"name": "护心镜", "text": "她打出防护牌时，你额外获得 3 格挡。", "flavor": "镜面有道裂痕，正好挡过一剑。", "block": 3},
	BLADE_INSCRIPTION: {"name": "剑铭", "text": "她打出攻击牌时，伤害 +3。", "flavor": "剑脊上刻了两个字，她不肯念给你听。", "damage": 3},
	WINE_GOURD: {"name": "酒葫芦", "text": "战斗胜利后，回复 6 生命。", "flavor": "她不喝酒，但喜欢闻。", "heal": 6},
	PEACE_CHARM: {"name": "平安符", "text": "每场战斗第一次生命降到 1/4 以下时，获得 10 格挡。", "flavor": "荒庙里求的。她说灵不灵不要紧，带着就好。", "block": 10},
	BRONZE_BELL: {"name": "铜铃", "text": "她亮出「收尾」意向时，精力 +1。", "flavor": "她要出重剑之前，铃会先响。", "energy": 1},
	OLD_UMBRELLA: {"name": "旧伞", "text": "她亮出「守护」意向的回合，你打出的第一张攻击牌费用 -1。", "flavor": "雨夜借宿那晚，她一直撑着这把伞。", "discount": 1},
	LETTER_ENVELOPE: {"name": "信笺", "text": "每场战斗第一回合，她会先亮出「让给你」的意向。", "flavor": "一只空信封。信她收起来了，信封还带在身上。"},
	BROKEN_STRING: {"name": "断弦", "text": "她亮出「收尾」意向时，所有敌人获得 1 层易伤。", "flavor": "戏台上捡的一截弦，再也牵不动谁了。", "vulnerable": 1},
}


static func get_definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})


static func relic_name(id: String) -> String:
	return str(get_definition(id).get("name", id))


static func get_number(id: String, key: String) -> int:
	return int(get_definition(id).get(key, 0))


# 从未拥有的信物里随机抽一件；全拿过时返回空。
static func roll(owned: Array[String], rng: RandomNumberGenerator = null) -> String:
	var pool: Array[String] = []
	for id in DEFINITIONS:
		if not owned.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	var index := (randi() if rng == null else rng.randi()) % pool.size()
	return pool[index]


static func describe(id: String) -> String:
	var definition := get_definition(id)
	return "「%s」%s" % [str(definition.get("name", id)), str(definition.get("text", ""))]
