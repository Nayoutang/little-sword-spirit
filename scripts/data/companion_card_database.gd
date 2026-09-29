class_name CompanionCardDatabase
extends RefCounted

# 小墨牌只保存稳定 id 与确定性效果。LLM 只能从当前授权列表中选择 id，
# 不得生成数值或直接改写战斗状态。
const QUICK_SLASH := "quick_slash"
const GUARD_ECHO := "guard_echo"
const FOLLOW_UP := "follow_up"
const OATH_GUARD := "oath_guard"
const HEART_RESONANCE := "heart_resonance"
const CLEAN_CUT := "clean_cut"
const LEAD_MOMENTUM := "lead_momentum"
const RETURN_GUARD := "return_guard"
const ESCORT := "escort"
const LONE_JUDGMENT := "lone_judgment"

# 剑意：飞花令里对出特定诗句时领悟，领悟后才进入她的牌池（不受境界限制）。
const FROST_COLD := "frost_cold"
const TEN_STEPS := "ten_steps"
const GRIND_SWORD := "grind_sword"
const CUT_WATER := "cut_water"
const LONG_WIND := "long_wind"
const BEHEAD_LOULAN := "behead_loulan"
const YIN_MOUNTAIN := "yin_mountain"
const FEW_RETURN := "few_return"

const STANCE_SELF := "self_preservation"
const STANCE_INVEST := "investment"

const DEFINITIONS := {
	QUICK_SLASH: {
		"name": "随手一斩",
		"min_bond_stage": 0,
		"stance": STANCE_SELF,
		"damage": 6,
		"description": "对生命最低的敌人造成6点伤害。",
	},
	GUARD_ECHO: {
		"name": "剑影回护",
		"min_bond_stage": 0,
		"stance": STANCE_SELF,
		"block": 6,
		"description": "为玩家获得6点格挡。",
	},
	FOLLOW_UP: {
		"name": "衔锋",
		"min_bond_stage": 1,
		"stance": STANCE_SELF,
		"damage": 7,
		"combo_scale": 2,
		"description": "承接玩家连击，对生命最低的敌人造成7+连击×2伤害，并令连击+1。",
	},
	CLEAN_CUT: {
		"name": "利落",
		"min_bond_stage": 1,
		"stance": STANCE_SELF,
		"damage": 8,
		"description": "对生命最低的敌人造成8点伤害。",
	},
	LEAD_MOMENTUM: {
		"name": "引势",
		"min_bond_stage": 1,
		"stance": STANCE_INVEST,
		"boon_type": "multiply",
		"boon_value": 2.0,
		"description": "不造成伤害；令玩家下回合第一张攻击牌的伤害×2。",
	},
	OATH_GUARD: {
		"name": "守诺",
		"min_bond_stage": 2,
		"stance": STANCE_SELF,
		"block": 10,
		"promise_bonus": 3,
		"description": "为玩家获得10点格挡；若本趟立下保护约定，额外获得3点。",
	},
	RETURN_GUARD: {
		"name": "回护",
		"min_bond_stage": 2,
		"stance": STANCE_SELF,
		"block": 10,
		"description": "为玩家获得10点格挡。",
	},
	ESCORT: {
		"name": "拱卫",
		"min_bond_stage": 2,
		"stance": STANCE_INVEST,
		"block": 6,
		"boon_type": "add",
		"boon_value": 4,
		"description": "为玩家获得6点格挡；令玩家下回合第一张攻击牌伤害+4。",
	},
	HEART_RESONANCE: {
		"name": "同心剑鸣",
		"min_bond_stage": 3,
		"stance": STANCE_INVEST,
		"damage": 12,
		"combo_scale": 3,
		"description": "对生命最低的敌人造成12+连击×3伤害，保留当前连击。",
	},
	LONE_JUDGMENT: {
		"name": "独断",
		"min_bond_stage": 3,
		"stance": STANCE_SELF,
		"damage": 12,
		"combo_scale": 4,
		"description": "对生命最低的敌人造成12+连击×4伤害，随后清空连击。",
	},
}

const INTENT_DEFINITIONS := {
	FROST_COLD: {
		"name": "霜寒", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"damage": 5, "weaken": 2,
		"poem": "满堂花醉三千客，一剑霜寒十四州", "source": "贯休《献钱尚父》", "trigger": "一剑霜寒十四州",
		"hint": "这句写一剑之寒压住十四州。",
		"description": "对全体敌人各造成5点伤害，并令它们本回合的攻击 -2。",
	},
	TEN_STEPS: {
		"name": "十步", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"damage": 4, "combo_scale": 4,
		"poem": "十步杀一人，千里不留行", "source": "李白《侠客行》", "trigger": "十步杀一人",
		"hint": "这句写侠客十步之内取人，千里不留行迹。",
		"description": "对生命最低的敌人造成4+连击×4伤害；若将其击杀，连击+1。",
	},
	GRIND_SWORD: {
		"name": "磨剑", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"damage": 6, "turn_scale": 3,
		"poem": "十年磨一剑，霜刃未曾试", "source": "贾岛《剑客》", "trigger": "十年磨一剑",
		"hint": "这句写十年磨一剑、霜刃还没出过鞘。你自己就是一把剑。",
		"description": "对生命最低的敌人造成6+已过回合数×3伤害，越晚出越狠。",
	},
	CUT_WATER: {
		"name": "断水", "min_bond_stage": 0, "stance": STANCE_INVEST, "requires_intent": true,
		"poem": "抽刀断水水更流，举杯销愁愁更愁", "source": "李白《宣州谢朓楼饯别校书叔云》", "trigger": "抽刀断水水更流",
		"hint": "这句写抽刀断水、水却更流，斩不断的东西。",
		"description": "不造成伤害；玩家下回合打出的第一张防御或状态牌不会清空连击。",
	},
	LONG_WIND: {
		"name": "长风", "min_bond_stage": 0, "stance": STANCE_INVEST, "requires_intent": true,
		"energy": 1,
		"poem": "长风破浪会有时，直挂云帆济沧海", "source": "李白《行路难·其一》", "trigger": "长风破浪会有时",
		"hint": "这句写总有乘风破浪的一天，是往后看的底气。",
		"description": "不造成伤害；玩家下回合多1点精力。",
	},
	BEHEAD_LOULAN: {
		"name": "斩楼兰", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"damage": 14,
		"poem": "愿将腰下剑，直为斩楼兰", "source": "李白《塞下曲六首·其一》", "trigger": "直为斩楼兰",
		"hint": "这句写愿以腰间剑直取楼兰。",
		"description": "对生命最高的敌人造成14点伤害。",
	},
	YIN_MOUNTAIN: {
		"name": "阴山", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"poem": "但使龙城飞将在，不教胡马度阴山", "source": "王昌龄《出塞·其一》", "trigger": "不教胡马度阴山",
		"hint": "这句写只要有人守着，就不让敌骑越过阴山。",
		"description": "挡下本回合攻击最高的那一个敌人的攻击。",
	},
	FEW_RETURN: {
		"name": "几人回", "min_bond_stage": 0, "stance": STANCE_SELF, "requires_intent": true,
		"block": 5, "block_low": 16,
		"poem": "醉卧沙场君莫笑，古来征战几人回", "source": "王翰《凉州词》", "trigger": "古来征战几人回",
		"hint": "这句写征战的人少有回来的——你偏要带他回去。",
		"description": "玩家生命不高于1/4时获得16点格挡，否则获得5点。",
	},
}

const ORDERED_IDS: Array[String] = [
	QUICK_SLASH,
	GUARD_ECHO,
	FOLLOW_UP,
	CLEAN_CUT,
	LEAD_MOMENTUM,
	OATH_GUARD,
	RETURN_GUARD,
	ESCORT,
	LONE_JUDGMENT,
	HEART_RESONANCE,
]


static func get_definition(card_id: String) -> Dictionary:
	if INTENT_DEFINITIONS.has(card_id):
		return INTENT_DEFINITIONS[card_id]
	return DEFINITIONS.get(card_id, {})


static func get_allowed_card_ids(bond_stage: int, learned_intents: Array = []) -> Array[String]:
	var allowed: Array[String] = []
	for card_id in ORDERED_IDS:
		if int(DEFINITIONS[card_id]["min_bond_stage"]) <= bond_stage:
			allowed.append(card_id)
	for card_id in INTENT_DEFINITIONS:
		if card_id in learned_intents:
			allowed.append(card_id)
	return allowed


static func _normalize(text: String) -> String:
	var clean := text
	for mark in [" ", "\t", "\n", "，", "。", "！", "？", "；", "：", "、", ",", ".", "!", "?", ";", ":", "“", "”", "‘", "’", "《", "》"]:
		clean = clean.replace(mark, "")
	return clean


# 玩家这句诗若含某句剑意诗的关键半联，返回对应剑意 id；否则返回空串。
static func match_sword_intent(player_text: String) -> String:
	var clean := _normalize(player_text)
	for card_id in INTENT_DEFINITIONS:
		if clean.contains(str(INTENT_DEFINITIONS[card_id]["trigger"])):
			return card_id
	return ""


static func is_investment(card_id: String) -> bool:
	return str(get_definition(card_id).get("stance", STANCE_SELF)) == STANCE_INVEST


static func get_prompt_catalog(card_ids: Array[String]) -> String:
	var lines: Array[String] = []
	for card_id in card_ids:
		var definition: Dictionary = get_definition(card_id)
		var stance := "投资玩家" if is_investment(card_id) else "当场兑现/自保"
		var origin := ""
		if definition.get("requires_intent", false):
			origin = "（剑意：你从他在飞花令里对出的「%s」中领悟的）" % str(definition.get("poem", ""))
		lines.append("- %s | %s | %s | %s%s" % [
			card_id,
			definition["name"],
			stance,
			definition["description"],
			origin,
		])
	return "\n".join(lines)
