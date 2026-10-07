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
const FLOWING_CLOUD := 15
const CHASE_WIND := 16
const SHIELD_STRIKE := 17
const RETAIN_SHIELD := 18
const PARRY := 19

const DEFINITIONS := {
	PARRY: {"name": "回锋", "type": "防御", "cost": 1, "block": 5, "reaction_damage": 4, "reaction_limit": 2, "combo_limit": 2, "battle": "[回锋·防御]\n费1 格挡5 / 清空连击\n本轮每受一段攻击，存活后反击4伤\n反击至多2次；命中给下回合连击+1，至多+2", "reward": "回锋\n费1 / 格挡5 / 本轮反击4伤至多2次\n反击命中给下回合连击+1，至多+2"},
	RETAIN_SHIELD: {"name": "留盾", "type": "能力", "cost": 1, "battle": "[留盾·能力]\n费1 本场生效，同名不叠加\n剩余护盾跨回合保留\n包括小墨提供的护盾", "reward": "留盾\n费1 / 剩余护盾跨回合保留 / 能力"},
	SHIELD_STRIKE: {"name": "护盾攻击", "type": "攻击", "cost": 1, "shield_percent": 100, "combo": 1, "battle": "[护盾攻击·攻击]\n费1 造成当前护盾100%的伤害\n不消耗护盾 / 不吃连击加伤\n连击+1；享受第一张攻击牌增益", "reward": "护盾攻击\n费1 / 当前护盾100%伤害 / 不消耗盾 / 连击+1"},
	FLOWING_CLOUD: {"name": "行云", "type": "能力", "cost": 1, "trigger_count": 3, "draw": 1, "energy": 1, "battle": "[行云·能力]\n费1 本场生效，同名不叠加\n每回合首次连续打出3张攻击牌后\n抽1张，恢复1精力\n非攻击手牌中断连续计数", "reward": "行云\n费1 / 三连攻后抽1张、恢复1精力 / 每回合一次"},
	CHASE_WIND: {"name": "追风", "type": "攻击", "cost": 2, "damage": 6, "combo": 1, "battle": "[追风·攻击]\n原费2 基础伤害6 / 连击+1\n费用=2−当前连续攻击计数，最低0\n非攻击手牌会重置折扣", "reward": "追风\n原费2 / 基础伤害6 / 连击+1\n当前每连续攻击一次，费用-1，最低0"},
	ATTACK: {"name": "平刺", "type": "攻击", "cost": 1, "damage": 6, "combo": 1, "battle": "[平刺]\n费1 基础伤害6\n连击+1", "reward": "平刺\n费1 / 基础伤害6 / 连击+1"},
	DEFENSE: {"name": "横架", "type": "防御", "cost": 1, "block": 5, "battle": "[横架]\n费1 格挡5\n清空连击", "reward": "横架\n费1 / 格挡5 / 清空连击"},
	STATUS: {"name": "凝神", "type": "技巧", "cost": 1, "battle": "[凝神]\n费1 抽张牌\n清空连击", "reward": "凝神\n费1 / 抽1张 / 清空连击"},
	HEAVY_ATTACK: {"name": "劈山", "type": "攻击", "cost": 2, "damage": 16, "combo": 1, "battle": "[劈山]\n费2 基础伤害16\n连击+1", "reward": "劈山\n费2 / 基础伤害16 / 连击+1"},
	HEAVY_DEFENSE: {"name": "铁门闩", "type": "防御", "cost": 2, "block": 12, "battle": "[铁门闩]\n费2 格挡12\n清空连击", "reward": "铁门闩\n费2 / 格挡12 / 清空连击"},
	SWEEP: {"name": "扫叶", "type": "攻击", "cost": 1, "damage": 3, "combo": 1, "battle": "[扫叶]\n费1 全体基础伤害3\n连击+1", "reward": "扫叶\n费1 / 全体基础伤害3 / 连击+1"},
	COMBO_BOOST: {"name": "叠浪", "type": "攻击", "cost": 1, "damage": 6, "combo": 2, "battle": "[叠浪]\n费1 基础伤害6\n连击+2", "reward": "叠浪\n费1 / 基础伤害6 / 连击+2"},
	CURSE: {"name": "心魔", "type": "诅咒", "cost": 0, "battle": "[心魔]\n无法打出", "reward": "心魔\n无法打出"},
	TUNE_BREATH: {"name": "调息", "type": "技巧", "cost": 0, "battle": "[调息·技巧]\n费0 抽1张\n每回合限用一次", "reward": "调息\n费0 / 抽1张 / 每回合限用一次"},
	SHADOW_STEP: {"name": "掠影", "type": "技巧", "cost": 1, "battle": "[掠影·技巧]\n费1 抽2张", "reward": "掠影\n费1 / 抽2张"},
	BREAK_EDGE: {"name": "破锋", "type": "攻击", "cost": 1, "damage": 8, "combo": 1, "vulnerable": 2, "battle": "[破锋·攻击]\n费1 基础伤害8\n连击+1 / 结算后2层易伤\n易伤：每次命中加伤，敌方回合末-1层", "reward": "破锋\n费1 / 基础伤害8 / 连击+1 / 2层易伤\n敌方回合末易伤-1层"},
	UNLOAD_FORCE: {"name": "拨千斤", "type": "技巧", "cost": 1, "attack_reduction": 5, "battle": "[拨千斤·技巧]\n费1 指定敌人\n其下一段攻击伤害-5", "reward": "拨千斤\n费1 / 敌人下一段攻击伤害-5"},
	HIDE_EDGE: {"name": "藏锋", "type": "防御", "cost": 1, "block": 6, "battle": "[藏锋·防御]\n费1 格挡6\n本回合结束连击不清零", "reward": "藏锋\n费1 / 格挡6 / 回合结束保留连击"},
	FLOWING_LIGHT: {"name": "流光", "type": "特殊技", "cost": 1, "damage": 15, "combo_required": 2, "combo_cost": 2, "bond_stage": 1, "battle": "[特殊技·流光]\n费1 基础伤害15\n需2连击 / 消耗2连击 / 相识解锁", "reward": "流光\n羁绊特殊技"},
	BRILLIANCE: {"name": "华彩", "type": "终极技", "cost": 0, "damage": 35, "combo_required": 3, "combo_cost": -1, "bond_stage": 2, "battle": "[终极技·华彩]\n费0 基础伤害35\n需3连击 / 连击清零 / 交心解锁", "reward": "华彩\n羁绊终极技"},
}

const REWARD_CARD_IDS := [
	HEAVY_ATTACK, HEAVY_DEFENSE, SWEEP, COMBO_BOOST,
	TUNE_BREATH, SHADOW_STEP, BREAK_EDGE, UNLOAD_FORCE, HIDE_EDGE,
	FLOWING_CLOUD, CHASE_WIND, SHIELD_STRIKE, RETAIN_SHIELD, PARRY,
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


func get_reward_card_ids(owned_cards: Array[int] = []) -> Array[int]:
	var candidates: Array[int] = []
	candidates.assign(REWARD_CARD_IDS)
	for ability_card in [FLOWING_CLOUD, RETAIN_SHIELD]:
		if ability_card in owned_cards:
			candidates.erase(ability_card)
	return candidates
