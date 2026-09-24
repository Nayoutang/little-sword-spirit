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
	return DEFINITIONS.get(card_id, {})


static func get_allowed_card_ids(bond_stage: int) -> Array[String]:
	var allowed: Array[String] = []
	for card_id in ORDERED_IDS:
		if int(DEFINITIONS[card_id]["min_bond_stage"]) <= bond_stage:
			allowed.append(card_id)
	return allowed


static func is_investment(card_id: String) -> bool:
	return str(DEFINITIONS.get(card_id, {}).get("stance", STANCE_SELF)) == STANCE_INVEST


static func get_prompt_catalog(card_ids: Array[String]) -> String:
	var lines: Array[String] = []
	for card_id in card_ids:
		var definition: Dictionary = DEFINITIONS[card_id]
		var stance := "投资玩家" if is_investment(card_id) else "当场兑现/自保"
		lines.append("- %s | %s | %s | %s" % [
			card_id,
			definition["name"],
			stance,
			definition["description"],
		])
	return "\n".join(lines)
