extends Node

# 卡牌编号必须保持稳定，已有牌组与存档会直接保存这些整数。
const ATTACK := 0
const DEFENSE := 1
const STATUS := 2
const HEAVY_ATTACK := 3
const HEAVY_DEFENSE := 4
const SWEEP := 5
const COMBO_BOOST := 6
const CURSE := 7
const TUNE_BREATH := 8
const SHADOW_STEP := 9
const BREAK_EDGE := 10
const UNLOAD_FORCE := 11
const HIDE_EDGE := 12
const FLOWING_LIGHT := 13
const BRILLIANCE := 14

const DEFINITIONS := {
	ATTACK: {"name": "攻击", "type": "攻击", "cost": 1, "damage": 6, "combo": 1, "battle": "[攻击]\n费1 基础伤害6\n连击+1", "reward": "攻击\n费1 / 基础伤害6 / 连击+1"},
	DEFENSE: {"name": "防御", "type": "防御", "cost": 1, "block": 5, "battle": "[防御]\n费1 格挡5\n清空连击", "reward": "防御\n费1 / 格挡5 / 清空连击"},
	STATUS: {"name": "状态", "type": "技巧", "cost": 1, "battle": "[状态]\n费1 抽张牌\n清空连击", "reward": "状态\n费1 / 抽1张 / 清空连击"},
	HEAVY_ATTACK: {"name": "强攻", "type": "攻击", "cost": 2, "damage": 14, "combo": 1, "battle": "[强攻]\n费2 基础伤害14\n连击+1", "reward": "强攻\n费2 / 基础伤害14 / 连击+1"},
	HEAVY_DEFENSE: {"name": "铁壁", "type": "防御", "cost": 2, "block": 12, "battle": "[铁壁]\n费2 格挡12\n清空连击", "reward": "铁壁\n费2 / 格挡12 / 清空连击"},
	SWEEP: {"name": "横扫", "type": "攻击", "cost": 1, "damage": 3, "combo": 1, "battle": "[横扫]\n费1 全体基础伤害3\n连击+1", "reward": "横扫\n费1 / 全体基础伤害3 / 连击+1"},
	COMBO_BOOST: {"name": "叠浪", "type": "攻击", "cost": 1, "damage": 6, "combo": 2, "battle": "[叠浪]\n费1 基础伤害6\n连击+2", "reward": "叠浪\n费1 / 基础伤害6 / 连击+2"},
	CURSE: {"name": "诅咒", "type": "诅咒", "cost": 0, "battle": "[诅咒]\n无法打出", "reward": "诅咒\n无法打出"},
	TUNE_BREATH: {"name": "调息", "type": "技巧", "cost": 0, "battle": "[调息·技巧]\n费0 抽1张\n每回合限用一次", "reward": "调息\n费0 / 抽1张 / 每回合限用一次"},
	SHADOW_STEP: {"name": "掠影", "type": "技巧", "cost": 1, "battle": "[掠影·技巧]\n费1 抽2张", "reward": "掠影\n费1 / 抽2张"},
	BREAK_EDGE: {"name": "破锋", "type": "攻击", "cost": 1, "damage": 8, "combo": 1, "vulnerable": 2, "battle": "[破锋·攻击]\n费1 基础伤害8\n连击+1 / 结算后2层易伤", "reward": "破锋\n费1 / 基础伤害8 / 连击+1 / 2层易伤"},
	UNLOAD_FORCE: {"name": "卸力", "type": "技巧", "cost": 1, "attack_reduction": 5, "battle": "[卸力·技巧]\n费1 指定敌人\n其下一次攻击伤害-5", "reward": "卸力\n费1 / 敌人下一次攻击伤害-5"},
	HIDE_EDGE: {"name": "藏锋", "type": "防御", "cost": 1, "block": 6, "battle": "[藏锋·防御]\n费1 格挡6\n本回合结束连击不清零", "reward": "藏锋\n费1 / 格挡6 / 回合结束保留连击"},
	FLOWING_LIGHT: {"name": "流光", "type": "特殊技", "cost": 1, "damage": 15, "combo_required": 2, "combo_cost": 2, "bond_stage": 1, "battle": "[特殊技·流光]\n费1 基础伤害15\n需2连击 / 消耗2连击 / 相识解锁", "reward": "流光\n羁绊特殊技"},
	BRILLIANCE: {"name": "华彩", "type": "终极技", "cost": 0, "damage": 35, "combo_required": 3, "combo_cost": -1, "bond_stage": 2, "battle": "[终极技·华彩]\n费0 基础伤害35\n需3连击 / 连击清零 / 交心解锁", "reward": "华彩\n羁绊终极技"},
}

const REWARD_CARD_IDS := [
	ATTACK, DEFENSE, STATUS, HEAVY_ATTACK, HEAVY_DEFENSE, SWEEP, COMBO_BOOST,
	TUNE_BREATH, SHADOW_STEP, BREAK_EDGE, UNLOAD_FORCE, HIDE_EDGE,
]


func get_definition(card_id: int) -> Dictionary:
	return DEFINITIONS.get(card_id, DEFINITIONS[CURSE])


func get_battle_text(card_id: int) -> String:
	return str(get_definition(card_id)["battle"])


func get_reward_text(card_id: int) -> String:
	return str(get_definition(card_id)["reward"])


func get_card_name(card_id: int) -> String:
	return str(get_definition(card_id)["name"])


func get_cost(card_id: int) -> int:
	return int(get_definition(card_id)["cost"])


func get_number(card_id: int, field: String, fallback := 0) -> int:
	return int(get_definition(card_id).get(field, fallback))


func get_reward_card_ids() -> Array[int]:
	return REWARD_CARD_IDS.duplicate()
