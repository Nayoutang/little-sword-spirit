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
# 2026-10-15 扩充：读小墨意向的配合牌、流派引擎、新动作、第二章紫线牌。
const BORROW_MOMENTUM := 20
const CLEAR_PATH := 21
const HAND_SWORD := 22
const YIELD_TURN := 23
const CLOSE_FORM := 24
const SIDE_BY_SIDE := 25
const INTENT_HOLD := 26
const UNMOVED := 27
const HEAR_WIND := 28
const ATTUNE := 29
const ALL_IN := 30
const LATE_STRIKE := 31
const PICK_THREAD := 32
const GUARD_HEART := 33
# 2026-10-19 构筑路线：守护流（背水、倚剑、托付）、让给你流（顺势、借花、心照）、收尾流（垫步、点睛、剑意相连）。
const BACK_TO_WATER := 34
const LEAN_ON_SWORD := 35
const ENTRUST := 36
const GO_WITH_FLOW := 37
const BORROW_BLOSSOM := 38
const HEART_SYNC := 39
const STEP_PAD := 40
const FINAL_TOUCH := 41
const LINKED_INTENT := 42
# 构筑路线（奖励权重用）
const ROUTE_GUARD := [BORROW_MOMENTUM, SIDE_BY_SIDE, UNMOVED, SHIELD_STRIKE, RETAIN_SHIELD, BACK_TO_WATER, LEAN_ON_SWORD, ENTRUST]
const ROUTE_INVEST := [YIELD_TURN, ATTUNE, HAND_SWORD, SHADOW_STEP, TUNE_BREATH, GO_WITH_FLOW, BORROW_BLOSSOM, HEART_SYNC]
const ROUTE_FINISHER := [CLEAR_PATH, CLOSE_FORM, INTENT_HOLD, COMBO_BOOST, BREAK_EDGE, HIDE_EDGE, ALL_IN, STEP_PAD, FINAL_TOUCH, LINKED_INTENT]
const ROUTE_ENGINES := {ENTRUST: ROUTE_GUARD, HEART_SYNC: ROUTE_INVEST, LINKED_INTENT: ROUTE_FINISHER}
# 磨剑：每张可升级牌只改数值（必要时连同牌面文字一起写）。心魔、流光、华彩不可升级。
const UPGRADE_OFFSET := 100
const UPGRADES := {
	ATTACK: {"damage": 9},
	DEFENSE: {"block": 8},
	STATUS: {"draw": 2},
	HEAVY_ATTACK: {"damage": 22},
	HEAVY_DEFENSE: {"block": 16},
	SWEEP: {"damage": 5},
	COMBO_BOOST: {"damage": 8},
	TUNE_BREATH: {"draw": 2},
	SHADOW_STEP: {"draw": 3},
	BREAK_EDGE: {"damage": 10, "vulnerable": 3,
		"battle": "[破锋+·攻击]\n费1 基础伤害10 / 连击+1\n给予3层易伤，敌方回合末易伤-1层",
		"reward": "破锋+\n费1 / 基础伤害10 / 连击+1 / 3层易伤\n敌方回合末易伤-1层"},
	UNLOAD_FORCE: {"attack_reduction": 8},
	HIDE_EDGE: {"block": 9},
	FLOWING_CLOUD: {"cost": 0},
	CHASE_WIND: {"damage": 9},
	SHIELD_STRIKE: {"shield_percent": 130,
		"face": ["当前护盾130%伤害", "不耗盾·连击+1·不吃连击加伤"],
		"battle": "[护盾攻击+·攻击]\n费1 造成当前护盾130%的伤害\n不消耗护盾 / 不吃连击加伤\n连击+1；享受第一张攻击牌增益",
		"reward": "护盾攻击+\n费1 / 当前护盾130%伤害 / 不耗盾 / 连击+1"},
	RETAIN_SHIELD: {"cost": 0},
	PARRY: {"block": 7, "reaction_damage": 6,
		"face": ["格挡7·反击6伤至多2次", "清空连击·反击积势至下回合"],
		"battle": "[回锋+·防御]\n费1 格挡7 / 清空连击\n本轮每受一段攻击，存活后反击6伤\n反击至多2次；命中给下回合连击+1，至多+2",
		"reward": "回锋+\n费1 / 格挡7 / 本轮反击6伤至多2次\n反击命中给下回合连击+1，至多+2"},
	BORROW_MOMENTUM: {"damage": 9},
	CLEAR_PATH: {"damage": 7, "companion_damage": 7,
		"face": ["基础伤害 7·连击+1", "她要攻击时：她这击+7"],
		"battle": "[开路+·攻击]\n费1 基础伤害7 / 连击+1\n小墨本回合要攻击时，她这一击伤害+7",
		"reward": "开路+\n费1 / 基础伤害7 / 连击+1\n她要攻击时，她这一击+7"},
	HAND_SWORD: {"block": 8},
	YIELD_TURN: {"draw": 3},
	CLOSE_FORM: {"damage": 14},
	SIDE_BY_SIDE: {"block": 11},
	INTENT_HOLD: {"cost": 1},
	UNMOVED: {"block": 5, "companion_block": 5,
		"face": ["每回合开始格挡 5", "她每次护你再+5"],
		"battle": "[不动+·能力]\n费1 本场生效，同名不叠加\n每回合开始获得5格挡\n小墨每次给你护盾，额外+5",
		"reward": "不动+\n费1 / 每回合开始格挡5\n她护你时再+5 / 能力"},
	HEAR_WIND: {"cost": 0},
	ATTUNE: {"cost": 1},
	ALL_IN: {"combo_scale": 7,
		"face": ["伤害 连击×7", "连击清零·本场移除"],
		"battle": "[孤注+·攻击]\n费0 伤害=连击×7 / 连击清零\n打出后本场移除",
		"reward": "孤注+\n费0 / 伤害=连击×7 / 连击清零\n打出后本场移除"},
	LATE_STRIKE: {"damage": 14},
	PICK_THREAD: {"damage": 7},
	GUARD_HEART: {"block": 9},
	BACK_TO_WATER: {"damage": 10},
	LEAN_ON_SWORD: {"damage": 12},
	ENTRUST: {"cost": 1},
	GO_WITH_FLOW: {"draw": 2},
	BORROW_BLOSSOM: {"damage": 9},
	HEART_SYNC: {"cost": 0},
	STEP_PAD: {"combo": 3},
	FINAL_TOUCH: {"combo_scale": 3, "finisher_scale": 4,
		"face": ["她这一击+连击×3", "她要收尾时：+连击×4"],
		"battle": "[点睛+·技巧]\n费1 小墨本回合的攻击伤害+连击×3\n她要收尾时改为+连击×4",
		"reward": "点睛+\n费1 / 她这一击+连击×3\n她要收尾时改为×4"},
	LINKED_INTENT: {"cost": 1},
}

# 小墨亮出的意向类别（battle.gd 的 _companion_intent_kind 给出）。
const INTENT_GUARD := "guard"
const INTENT_ATTACK := "attack"
const INTENT_INVEST := "invest"
const INTENT_FINISHER := "finisher"
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_WEIGHTS := {"common": 6, "uncommon": 3, "rare": 1}

# 可打出的手牌统一按效果顺序执行；数值与展示共用同条定义字段。
const TARGET_NONE := "none"
const TARGET_SELECTED_ENEMY := "selected_enemy"
const TARGET_ALL_ENEMIES := "all_enemies"
const EFFECT_DAMAGE := "damage"
const EFFECT_BLOCK := "block"
const EFFECT_COMBO := "combo"
const EFFECT_DRAW := "draw"
const EFFECT_BATTLE_STATE := "battle_state"
const EFFECT_REACTION := "reaction"
const EFFECT_VULNERABLE := "vulnerable"
const EFFECT_REDUCE_ATTACK := "reduce_attack"
const EFFECT_ENERGY := "energy"
const EFFECT_COMPANION_DAMAGE := "companion_damage"
const EFFECT_COMPANION_BLOCK := "companion_block"
const EFFECT_THREAD_PIERCE := "thread_pierce"
const COMBO_PRESERVE := "preserve"
const COMBO_ADD := "add"
const COMBO_CLEAR := "clear"
const DRAW_REPLACE_SLOT := "replace_slot"
const DRAW_EMPTY_SLOTS := "empty_slots"

const DEFINITIONS := {
	PARRY: {
		"effects": [
			{"kind": EFFECT_REACTION, "amount_key": "reaction_damage", "reaction_limit_key": "reaction_limit", "combo_limit_key": "combo_limit"},
			{"kind": EFFECT_BLOCK, "amount_key": "block"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense"},
		],
		"result_template": "获得 {block} 格挡，连击清零",
		"protected_result_template": "获得 {block} 格挡；断水生效，连击保留",
		"post_action_template": "；回锋：本轮反击至多{reaction_limit}次",
		"target": TARGET_NONE,
		"name": "回锋",
		"type": "防御",
		"cost": 1,
		"block": 5,
		"reaction_damage": 4,
		"reaction_limit": 2,
		"combo_limit": 2,
		"battle": "[回锋·防御]\n费1 格挡5 / 清空连击\n本轮每受一段攻击，存活后反击4伤\n反击至多2次；命中给下回合连击+1，至多+2",
		"reward": "回锋\n费1 / 格挡5 / 本轮反击4伤至多2次\n反击命中给下回合连击+1，至多+2",
	},
	RETAIN_SHIELD: {
		"effects": [
			{"kind": EFFECT_BATTLE_STATE, "flag": "retain_shield_active"},
		],
		"result_template": "留盾：剩余护盾跨回合保留",
		"active_flag": "retain_shield_active",
		"target": TARGET_NONE,
		"name": "留盾",
		"type": "能力",
		"cost": 1,
		"battle": "[留盾·能力]\n费1 本场生效，同名不叠加\n剩余护盾跨回合保留\n包括小墨提供的护盾",
		"reward": "留盾\n费1 / 剩余护盾跨回合保留 / 能力",
	},
	SHIELD_STRIKE: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "shield_percent_key": "shield_percent"},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "护盾攻击：以 {shield} 护盾攻击敌人{target}，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "护盾攻击",
		"type": "攻击",
		"cost": 1,
		"shield_percent": 100,
		"combo": 1,
		"battle": "[护盾攻击·攻击]\n费1 造成当前护盾100%的伤害\n不消耗护盾 / 不吃连击加伤\n连击+1；享受第一张攻击牌增益",
		"reward": "护盾攻击\n费1 / 当前护盾100%伤害 / 不消耗盾 / 连击+1",
	},
	FLOWING_CLOUD: {
		"effects": [
			{"kind": EFFECT_BATTLE_STATE, "flag": "flowing_cloud_active", "rule_slot": "flowing_cloud_rule"},
		],
		"result_template": "行云：本场每回合首次三连攻，抽1张并恢复1精力",
		"active_flag": "flowing_cloud_active",
		"target": TARGET_NONE,
		"name": "行云",
		"type": "能力",
		"cost": 1,
		"trigger_count": 3,
		"draw": 1,
		"energy": 1,
		"battle": "[行云·能力]\n费1 本场生效，同名不叠加\n每回合首次连续打出3张攻击牌后\n抽1张，恢复1精力\n非攻击手牌中断连续计数",
		"reward": "行云\n费1 / 三连攻后抽1张、恢复1精力 / 每回合一次",
	},
	CHASE_WIND: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"cost_rule": {"subtract_state": "consecutive_attacks", "minimum": 0},
		"target": TARGET_SELECTED_ENEMY,
		"name": "追风",
		"type": "攻击",
		"cost": 2,
		"damage": 6,
		"combo": 1,
		"battle": "[追风·攻击]\n原费2 基础伤害6 / 连击+1\n费用=2−当前连续攻击计数，最低0\n非攻击手牌会重置折扣",
		"reward": "追风\n原费2 / 基础伤害6 / 连击+1\n当前每连续攻击一次，费用-1，最低0",
	},
	ATTACK: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "平刺",
		"type": "攻击",
		"cost": 1,
		"damage": 6,
		"combo": 1,
		"battle": "[平刺]\n费1 基础伤害6\n连击+1",
		"reward": "平刺\n费1 / 基础伤害6 / 连击+1",
	},
	DEFENSE: {
		"combo_protection_candidate": true,
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense"},
		],
		"result_template": "获得 {block} 格挡，连击清零",
		"protected_result_template": "获得 {block} 格挡；断水生效，连击保留",
		"target": TARGET_NONE,
		"name": "横架",
		"type": "防御",
		"cost": 1,
		"block": 5,
		"battle": "[横架]\n费1 格挡5\n清空连击",
		"reward": "横架\n费1 / 格挡5 / 清空连击",
	},
	STATUS: {
		"effects": [
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "other"},
			{"kind": EFFECT_DRAW, "amount_key": "draw", "mode": DRAW_REPLACE_SLOT},
		],
		"result_template": "抽取 1 张牌，连击清零",
		"draw": 1,
		"protected_result_template": "抽取 1 张牌；断水生效，连击保留",
		"combo_protection_candidate": true,
		"target": TARGET_NONE,
		"name": "凝神",
		"type": "技巧",
		"cost": 1,
		"battle": "[凝神]\n费1 抽张牌\n清空连击",
		"reward": "凝神\n费1 / 抽1张 / 清空连击",
	},
	HEAVY_ATTACK: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "劈山",
		"type": "攻击",
		"cost": 2,
		"damage": 16,
		"combo": 1,
		"battle": "[劈山]\n费2 基础伤害16\n连击+1",
		"reward": "劈山\n费2 / 基础伤害16 / 连击+1",
	},
	HEAVY_DEFENSE: {
		"combo_protection_candidate": true,
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense"},
		],
		"result_template": "获得 {block} 格挡，连击清零",
		"protected_result_template": "获得 {block} 格挡；断水生效，连击保留",
		"target": TARGET_NONE,
		"name": "铁门闩",
		"type": "防御",
		"cost": 2,
		"block": 12,
		"battle": "[铁门闩]\n费2 格挡12\n清空连击",
		"reward": "铁门闩\n费2 / 格挡12 / 清空连击",
	},
	SWEEP: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "扫叶对所有敌人造成 {damage} 伤害，连击 +1",
		"target": TARGET_ALL_ENEMIES,
		"name": "扫叶",
		"type": "攻击",
		"cost": 1,
		"damage": 3,
		"combo": 1,
		"battle": "[扫叶]\n费1 全体基础伤害3\n连击+1",
		"reward": "扫叶\n费1 / 全体基础伤害3 / 连击+1",
	},
	COMBO_BOOST: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "叠浪攻击敌人{target}，造成 {damage} 伤害，连击 +2",
		"target": TARGET_SELECTED_ENEMY,
		"name": "叠浪",
		"type": "攻击",
		"cost": 1,
		"damage": 6,
		"combo": 2,
		"battle": "[叠浪]\n费1 基础伤害6\n连击+2",
		"reward": "叠浪\n费1 / 基础伤害6 / 连击+2",
	},
	CURSE: {
		"playable": false,
		"unplayable_text": "心魔无法打出",
		"target": TARGET_NONE,
		"name": "心魔",
		"type": "诅咒",
		"cost": 0,
		"battle": "[心魔]\n无法打出",
		"reward": "心魔\n无法打出",
	},
	TUNE_BREATH: {
		"effects": [
			{"kind": EFFECT_DRAW, "amount_key": "draw", "mode": DRAW_REPLACE_SLOT},
		],
		"result_template": "调息：抽取 1 张牌",
		"draw": 1,
		"once_per_turn_flag": "tune_breath_used_this_turn",
		"target": TARGET_NONE,
		"name": "调息",
		"type": "技巧",
		"cost": 0,
		"battle": "[调息·技巧]\n费0 抽1张\n每回合限用一次",
		"reward": "调息\n费0 / 抽1张 / 每回合限用一次",
	},
	SHADOW_STEP: {
		"effects": [
			{"kind": EFFECT_DRAW, "amount_key": "draw", "mode": DRAW_EMPTY_SLOTS},
		],
		"result_template": "掠影：抽取 {drawn} 张牌",
		"draw": 2,
		"target": TARGET_NONE,
		"name": "掠影",
		"type": "技巧",
		"cost": 1,
		"battle": "[掠影·技巧]\n费1 抽2张",
		"reward": "掠影\n费1 / 抽2张",
	},
	BREAK_EDGE: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_VULNERABLE, "amount_key": "vulnerable"},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "破锋攻击敌人{target}，造成 {damage} 伤害，施加 {vulnerable} 层易伤，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "破锋",
		"type": "攻击",
		"cost": 1,
		"damage": 8,
		"combo": 1,
		"vulnerable": 2,
		"battle": "[破锋·攻击]\n费1 基础伤害8\n连击+1 / 结算后2层易伤\n易伤：每次命中加伤，敌方回合末-1层",
		"reward": "破锋\n费1 / 基础伤害8 / 连击+1 / 2层易伤\n敌方回合末易伤-1层",
	},
	UNLOAD_FORCE: {
		"effects": [
			{"kind": EFFECT_REDUCE_ATTACK, "amount_key": "attack_reduction"},
		],
		"result_template": "拨千斤：敌人{target}下一段攻击伤害降低 {reduction}",
		"target": TARGET_SELECTED_ENEMY,
		"name": "拨千斤",
		"type": "技巧",
		"cost": 1,
		"attack_reduction": 5,
		"battle": "[拨千斤·技巧]\n费1 指定敌人\n其下一段攻击伤害-5",
		"reward": "拨千斤\n费1 / 敌人下一段攻击伤害-5",
	},
	HIDE_EDGE: {
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block"},
			{"kind": EFFECT_COMBO, "mode": COMBO_PRESERVE},
		],
		"result_template": "藏锋：获得 {block} 格挡，本回合结束保留连击",
		"target": TARGET_NONE,
		"name": "藏锋",
		"type": "防御",
		"cost": 1,
		"block": 6,
		"battle": "[藏锋·防御]\n费1 格挡6\n本回合结束连击不清零",
		"reward": "藏锋\n费1 / 格挡6 / 回合结束保留连击",
	},
	BORROW_MOMENTUM: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"cost_rule": {"free_when_intent": [INTENT_GUARD]},
		"result_template": "借势：攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "借势", "type": "攻击", "cost": 1, "rarity": RARITY_COMMON,
		"damage": 6, "combo": 1,
		"face": ["基础伤害 6·连击+1", "她要守护时：费用 0"],
		"battle": "[借势·攻击]\n费1 基础伤害6 / 连击+1\n小墨本回合意向为守护时，费用0",
		"reward": "借势\n费1 / 基础伤害6 / 连击+1\n她要守护时费用0",
	},
	CLEAR_PATH: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
			{"kind": EFFECT_COMPANION_DAMAGE, "amount_key": "companion_damage", "requires_intent": [INTENT_ATTACK, INTENT_FINISHER]},
		],
		"result_template": "开路：攻击敌人{target}，造成 {damage} 伤害，连击 +1{companion}",
		"target": TARGET_SELECTED_ENEMY,
		"name": "开路", "type": "攻击", "cost": 1, "rarity": RARITY_COMMON,
		"damage": 5, "combo": 1, "companion_damage": 5,
		"face": ["基础伤害 5·连击+1", "她要攻击时：她这击+5"],
		"battle": "[开路·攻击]\n费1 基础伤害5 / 连击+1\n小墨本回合要攻击时，她这一击伤害+5",
		"reward": "开路\n费1 / 基础伤害5 / 连击+1\n她要攻击时，她这一击+5",
	},
	HAND_SWORD: {
		"combo_protection_candidate": true,
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense", "unless_intent": [INTENT_ATTACK, INTENT_FINISHER]},
		],
		"result_template": "递剑：获得 {block} 格挡{combo_note}",
		"protected_result_template": "递剑：获得 {block} 格挡；断水生效，连击保留",
		"target": TARGET_NONE,
		"name": "递剑", "type": "防御", "cost": 1, "rarity": RARITY_COMMON,
		"block": 5,
		"face": ["格挡 5", "她要攻击时：不清连击"],
		"battle": "[递剑·防御]\n费1 格挡5 / 清空连击\n小墨本回合要攻击时，连击不清零",
		"reward": "递剑\n费1 / 格挡5\n她要攻击时连击不清零",
	},
	YIELD_TURN: {
		"effects": [
			{"kind": EFFECT_DRAW, "amount_key": "draw", "mode": DRAW_EMPTY_SLOTS},
			{"kind": EFFECT_ENERGY, "amount_key": "energy", "requires_intent": [INTENT_INVEST]},
		],
		"result_template": "承让：抽取 {drawn} 张牌{energy_note}",
		"target": TARGET_NONE,
		"name": "承让", "type": "技巧", "cost": 1, "rarity": RARITY_UNCOMMON,
		"draw": 2, "energy": 1,
		"face": ["抽牌 2", "她要让给你时：精力+1"],
		"battle": "[承让·技巧]\n费1 抽2张\n小墨本回合要把机会让给你时，再恢复1精力",
		"reward": "承让\n费1 / 抽2张\n她让给你时精力+1",
	},
	CLOSE_FORM: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scale_key": "combo_scale"},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "finisher_combo", "requires_intent": [INTENT_FINISHER]},
		],
		"result_template": "收势：攻击敌人{target}，造成 {damage} 伤害{combo_note}",
		"target": TARGET_SELECTED_ENEMY,
		"name": "收势", "type": "攻击", "cost": 2, "rarity": RARITY_RARE,
		"damage": 10, "combo_scale": 3, "finisher_combo": 2,
		"face": ["伤害 10+连击×3", "她要收尾时：连击+2留给她"],
		"battle": "[收势·攻击]\n费2 伤害10+连击×3 / 不清连击\n小墨本回合要收尾时，再给连击+2留给她",
		"reward": "收势\n费2 / 伤害10+连击×3\n她要收尾时连击+2",
	},
	SIDE_BY_SIDE: {
		"combo_protection_candidate": true,
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block", "intent_bonus_key": "together_bonus", "bonus_intent": [INTENT_GUARD]},
			{"kind": EFFECT_COMPANION_BLOCK, "amount_key": "together_bonus", "requires_intent": [INTENT_GUARD]},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense"},
		],
		"result_template": "并肩：获得 {block} 格挡，连击清零{companion}",
		"protected_result_template": "并肩：获得 {block} 格挡；断水生效，连击保留{companion}",
		"target": TARGET_NONE,
		"name": "并肩", "type": "防御", "cost": 1, "rarity": RARITY_COMMON,
		"block": 8, "together_bonus": 3,
		"face": ["格挡 8·清连击", "她也守护时：两人护盾+3"],
		"battle": "[并肩·防御]\n费1 格挡8 / 清空连击\n小墨本回合也守护时，你和她的护盾都+3",
		"reward": "并肩\n费1 / 格挡8\n她也守护时两人护盾各+3",
	},
	INTENT_HOLD: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "intent_hold_active"}],
		"result_template": "蓄意：本场回合末连击只减半",
		"active_flag": "intent_hold_active",
		"target": TARGET_NONE,
		"name": "蓄意", "type": "能力", "cost": 2, "rarity": RARITY_RARE,
		"face": ["回合末连击只减半", "能力·主动连击核心"],
		"battle": "[蓄意·能力]\n费2 本场生效，同名不叠加\n回合末连击不清零，只减半",
		"reward": "蓄意\n费2 / 回合末连击只减半 / 能力",
	},
	UNMOVED: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "unmoved_active"}],
		"result_template": "不动：每回合开始获得格挡，她护你时再加",
		"active_flag": "unmoved_active",
		"target": TARGET_NONE,
		"name": "不动", "type": "能力", "cost": 1, "rarity": RARITY_UNCOMMON,
		"block": 3, "companion_block": 3,
		"face": ["每回合开始格挡 3", "她每次护你再+3"],
		"battle": "[不动·能力]\n费1 本场生效，同名不叠加\n每回合开始获得3格挡\n小墨每次给你护盾，额外+3",
		"reward": "不动\n费1 / 每回合开始格挡3\n她护你时再+3 / 能力",
	},
	HEAR_WIND: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "hear_wind_active"}],
		"result_template": "听风：回锋多反击一次，反击给她蓄力",
		"active_flag": "hear_wind_active",
		"target": TARGET_NONE,
		"name": "听风", "type": "能力", "cost": 1, "rarity": RARITY_UNCOMMON,
		"reaction_bonus": 1, "companion_damage": 2,
		"face": ["回锋反击上限+1", "每次反击：她下击+2"],
		"battle": "[听风·能力]\n费1 本场生效，同名不叠加\n回锋反击上限+1\n每次反击让小墨下次出手伤害+2",
		"reward": "听风\n费1 / 回锋反击上限+1\n反击让她下次伤害+2 / 能力",
	},
	ATTUNE: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "attune_active"}],
		"result_template": "同调：接住她留下的机会时抽牌回精力",
		"active_flag": "attune_active",
		"target": TARGET_NONE,
		"name": "同调", "type": "能力", "cost": 2, "rarity": RARITY_RARE,
		"draw": 1, "energy": 1,
		"face": ["接住她的机会：抽1", "精力+1·能力"],
		"battle": "[同调·能力]\n费2 本场生效，同名不叠加\n每当你用掉小墨留下的机会\n抽1张，恢复1精力",
		"reward": "同调\n费2 / 用掉她留的机会时抽1张、精力+1 / 能力",
	},
	ALL_IN: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scale_key": "combo_scale"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "consume_reason": "skill"},
		],
		"exhaust": true,
		"result_template": "孤注：攻击敌人{target}，造成 {damage} 伤害，连击清零；本场移除",
		"target": TARGET_SELECTED_ENEMY,
		"name": "孤注", "type": "攻击", "cost": 0, "rarity": RARITY_UNCOMMON,
		"damage": 0, "combo_scale": 5,
		"face": ["伤害 连击×5", "连击清零·本场移除"],
		"battle": "[孤注·攻击]\n费0 伤害=连击×5 / 连击清零\n打出后本场移除",
		"reward": "孤注\n费0 / 伤害=连击×5 / 连击清零\n打出后本场移除",
	},
	LATE_STRIKE: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true, "defense_scale_key": "per_defense"},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "后发：攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "后发", "type": "攻击", "cost": 2, "rarity": RARITY_UNCOMMON,
		"damage": 10, "per_defense": 5, "combo": 1,
		"face": ["基础伤害 10·连击+1", "本回合每张防御+5"],
		"battle": "[后发·攻击]\n费2 基础伤害10 / 连击+1\n本回合每打出过一张防御牌，伤害+5",
		"reward": "后发\n费2 / 基础伤害10 / 连击+1\n本回合每张防御牌+5",
	},
	PICK_THREAD: {
		"chapter": 2,
		"effects": [
			{"kind": EFFECT_THREAD_PIERCE},
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "挑丝：攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "挑丝", "type": "攻击", "cost": 1, "rarity": RARITY_COMMON,
		"damage": 4, "combo": 1,
		"face": ["基础伤害 4·连击+1", "打持线者算两次命中"],
		"battle": "[挑丝·攻击]\n费1 基础伤害4 / 连击+1\n打中持线者时算2次命中",
		"reward": "挑丝\n费1 / 基础伤害4 / 连击+1\n打持线者算2次命中",
	},
	GUARD_HEART: {
		"chapter": 2,
		"combo_protection_candidate": true,
		"effects": [
			{"kind": EFFECT_BLOCK, "amount_key": "block", "thread_bonus_key": "thread_bonus"},
			{"kind": EFFECT_COMBO, "mode": COMBO_CLEAR, "respect_combo_protection": true, "consume_protection": true, "consume_reason": "defense"},
		],
		"result_template": "护心：获得 {block} 格挡，连击清零",
		"protected_result_template": "护心：获得 {block} 格挡；断水生效，连击保留",
		"target": TARGET_NONE,
		"name": "护心", "type": "防御", "cost": 1, "rarity": RARITY_COMMON,
		"block": 6, "thread_bonus": 6,
		"face": ["格挡 6·清连击", "她被线缠住时再+6"],
		"battle": "[护心·防御]\n费1 格挡6 / 清空连击\n小墨被紫线缠住时，再+6格挡",
		"reward": "护心\n费1 / 格挡6\n她被缠住时再+6",
	},
	BACK_TO_WATER: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
			{"kind": EFFECT_COMPANION_BLOCK, "amount_key": "companion_block", "requires_intent": [INTENT_GUARD], "requires_no_defense": true},
		],
		"result_template": "背水：攻击敌人{target}，造成 {damage} 伤害，连击 +1{companion}",
		"target": TARGET_SELECTED_ENEMY,
		"name": "背水", "type": "攻击", "cost": 1, "rarity": RARITY_COMMON,
		"damage": 7, "combo": 1, "companion_block": 4,
		"face": ["基础伤害 7·连击+1", "无防御·她守护：盾+4"],
		"battle": "[背水·攻击]\n费1 基础伤害7 / 连击+1\n本回合还没打过防御牌、小墨要守护时，她给你的护盾+4",
		"reward": "背水\n费1 / 基础伤害7 / 连击+1\n没出防御、她守护时，她的护盾+4",
	},
	LEAN_ON_SWORD: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "context_add_key": "last_companion_block", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "倚剑：攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "倚剑", "type": "攻击", "cost": 2, "rarity": RARITY_UNCOMMON,
		"damage": 8, "combo": 1,
		"face": ["伤害 8+她上回合的盾", "连击+1"],
		"battle": "[倚剑·攻击]\n费2 伤害8 + 小墨上回合给你的护盾\n连击+1",
		"reward": "倚剑\n费2 / 伤害8+她上回合给你的护盾\n连击+1",
	},
	ENTRUST: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "entrust_active"}],
		"result_template": "托付：她给你的护盾，会变成你下一剑的力道",
		"active_flag": "entrust_active",
		"target": TARGET_NONE,
		"name": "托付", "type": "能力", "cost": 2, "rarity": RARITY_RARE,
		"face": ["她每次给你护盾", "下一剑+盾的一半·能力"],
		"battle": "[托付·能力]\n费2 本场生效，同名不叠加\n小墨每次给你护盾，你下一张攻击牌伤害+该护盾的一半",
		"reward": "托付\n费2 / 她给你护盾时，你下一剑+护盾一半 / 能力",
	},
	GO_WITH_FLOW: {
		"effects": [
			{"kind": EFFECT_DRAW, "amount_key": "draw", "mode": DRAW_EMPTY_SLOTS},
			{"kind": EFFECT_DRAW, "amount_key": "bonus_draw", "mode": DRAW_EMPTY_SLOTS, "requires_intent": [INTENT_INVEST]},
			{"kind": EFFECT_ENERGY, "amount_key": "energy", "requires_intent": [INTENT_INVEST]},
		],
		"result_template": "顺势：抽取 {drawn} 张牌{energy_note}",
		"target": TARGET_NONE,
		"name": "顺势", "type": "技巧", "cost": 0, "rarity": RARITY_COMMON,
		"draw": 1, "bonus_draw": 1, "energy": 1,
		"face": ["抽牌 1", "她让给你：抽1·精力+1"],
		"battle": "[顺势·技巧]\n费0 抽1张\n小墨本回合要让给你时，再抽1张、精力+1",
		"reward": "顺势\n费0 / 抽1张\n她让给你时再抽1、精力+1",
	},
	BORROW_BLOSSOM: {
		"effects": [
			{"kind": EFFECT_DAMAGE, "amount_key": "damage", "per_context_key": "opportunities_used", "per_amount_key": "per_opportunity", "combo_scaled": true},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
		],
		"result_template": "借花：攻击敌人{target}，造成 {damage} 伤害，连击 +1",
		"target": TARGET_SELECTED_ENEMY,
		"name": "借花", "type": "攻击", "cost": 1, "rarity": RARITY_UNCOMMON,
		"damage": 6, "combo": 1, "per_opportunity": 2,
		"face": ["基础伤害 6·连击+1", "每接住一次机会+2"],
		"battle": "[借花·攻击]\n费1 基础伤害6 / 连击+1\n本场你每用掉一次小墨留下的机会，伤害+2",
		"reward": "借花\n费1 / 基础伤害6 / 连击+1\n本场每接住她一次机会+2",
	},
	HEART_SYNC: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "heart_sync_active"}],
		"result_template": "心照：接住她的机会时，你也站得更稳",
		"active_flag": "heart_sync_active",
		"target": TARGET_NONE,
		"name": "心照", "type": "能力", "cost": 1, "rarity": RARITY_RARE,
		"block": 4, "combo": 1,
		"face": ["接住她的机会：格挡4", "连击+1·能力"],
		"battle": "[心照·能力]\n费1 本场生效，同名不叠加\n每当你用掉小墨留下的机会，获得4格挡、连击+1\n她也会更愿意把机会让给你",
		"reward": "心照\n费1 / 接住她的机会时格挡4、连击+1 / 能力",
	},
	STEP_PAD: {
		"effects": [
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "combo"},
			{"kind": EFFECT_COMBO, "mode": COMBO_ADD, "amount_key": "finisher_combo", "requires_intent": [INTENT_FINISHER]},
		],
		"result_template": "垫步：连击 +2{combo_note}",
		"target": TARGET_NONE,
		"name": "垫步", "type": "技巧", "cost": 1, "rarity": RARITY_COMMON,
		"combo": 2, "finisher_combo": 1,
		"face": ["连击+2", "她要收尾时：再+1"],
		"battle": "[垫步·技巧]\n费1 连击+2，不造成伤害\n小墨本回合要收尾时，再+1",
		"reward": "垫步\n费1 / 连击+2\n她要收尾时再+1",
	},
	FINAL_TOUCH: {
		"effects": [
			{"kind": EFFECT_COMPANION_DAMAGE, "combo_scale_key": "combo_scale", "intent_combo_scale_key": "finisher_scale", "bonus_intent": [INTENT_FINISHER]},
		],
		"result_template": "点睛：把剑势交给她{companion}",
		"target": TARGET_NONE,
		"name": "点睛", "type": "技巧", "cost": 1, "rarity": RARITY_UNCOMMON,
		"combo_scale": 2, "finisher_scale": 3,
		"face": ["她这一击+连击×2", "她要收尾时：+连击×3"],
		"battle": "[点睛·技巧]\n费1 小墨本回合的攻击伤害+连击×2\n她要收尾时改为+连击×3",
		"reward": "点睛\n费1 / 她这一击+连击×2\n她要收尾时改为×3",
	},
	LINKED_INTENT: {
		"effects": [{"kind": EFFECT_BATTLE_STATE, "flag": "linked_intent_active"}],
		"result_template": "剑意相连：她每击倒一个敌人，下回合你接着来",
		"active_flag": "linked_intent_active",
		"target": TARGET_NONE,
		"name": "剑意相连", "type": "能力", "cost": 2, "rarity": RARITY_RARE,
		"energy": 1, "draw": 1,
		"face": ["她击杀：下回合精力+1", "抽1·连击保留·能力"],
		"battle": "[剑意相连·能力]\n费2 本场生效，同名不叠加\n小墨每次击倒敌人：你下回合精力+1、多抽1张，且连击不清零",
		"reward": "剑意相连\n费2 / 她击倒敌人时，你下回合精力+1、抽1、连击不清零 / 能力",
	},
	FLOWING_LIGHT: {
		"target": TARGET_NONE,
		"name": "流光",
		"type": "特殊技",
		"cost": 1,
		"damage": 15,
		"combo_required": 2,
		"combo_cost": 2,
		"bond_stage": 0,
		"bond_required": 15,
		"battle": "[特殊技·流光]\n费1 基础伤害15\n需2连击 / 消耗2连击 / 羁绊15解锁",
		"reward": "流光\n羁绊特殊技",
	},
	BRILLIANCE: {
		"target": TARGET_NONE,
		"name": "华彩",
		"type": "终极技",
		"cost": 0,
		"damage": 35,
		"combo_required": 3,
		"combo_cost": -1,
		"bond_stage": 1,
		"bond_required": 30,
		"battle": "[终极技·华彩]\n费0 基础伤害35\n需3连击 / 连击清零 / 羁绊30解锁",
		"reward": "华彩\n羁绊终极技",
	},
}

const REWARD_CARD_IDS := [
	HEAVY_ATTACK, HEAVY_DEFENSE, SWEEP, COMBO_BOOST,
	TUNE_BREATH, SHADOW_STEP, BREAK_EDGE, UNLOAD_FORCE, HIDE_EDGE,
	FLOWING_CLOUD, CHASE_WIND, SHIELD_STRIKE, RETAIN_SHIELD, PARRY,
	BORROW_MOMENTUM, CLEAR_PATH, HAND_SWORD, YIELD_TURN, CLOSE_FORM, SIDE_BY_SIDE,
	INTENT_HOLD, UNMOVED, HEAR_WIND, ATTUNE, ALL_IN, LATE_STRIKE, PICK_THREAD, GUARD_HEART,
	BACK_TO_WATER, LEAN_ON_SWORD, ENTRUST, GO_WITH_FLOW, BORROW_BLOSSOM, HEART_SYNC, STEP_PAD, FINAL_TOUCH, LINKED_INTENT,
]
# 旧牌的稀有度；新牌写在定义里。
const LEGACY_RARITY := {
	HEAVY_ATTACK: RARITY_COMMON, HEAVY_DEFENSE: RARITY_COMMON, SWEEP: RARITY_COMMON, COMBO_BOOST: RARITY_COMMON,
	TUNE_BREATH: RARITY_COMMON, SHADOW_STEP: RARITY_COMMON, BREAK_EDGE: RARITY_UNCOMMON, UNLOAD_FORCE: RARITY_COMMON,
	HIDE_EDGE: RARITY_UNCOMMON, FLOWING_CLOUD: RARITY_RARE, CHASE_WIND: RARITY_UNCOMMON, SHIELD_STRIKE: RARITY_UNCOMMON,
	RETAIN_SHIELD: RARITY_RARE, PARRY: RARITY_UNCOMMON,
}


func get_definition(card_id: int) -> Dictionary:
	if card_id >= UPGRADE_OFFSET and UPGRADES.has(card_id - UPGRADE_OFFSET):
		return _upgraded_definition(card_id - UPGRADE_OFFSET)
	return DEFINITIONS.get(card_id, DEFINITIONS[CURSE])


# ---- 磨剑（卡牌升级）----
# 升级后的牌 id = 原 id + UPGRADE_OFFSET，牌组和存档仍然只存整数。

func base_id(card_id: int) -> int:
	return card_id - UPGRADE_OFFSET if card_id >= UPGRADE_OFFSET else card_id


func is_upgraded(card_id: int) -> bool:
	return card_id >= UPGRADE_OFFSET


func can_upgrade(card_id: int) -> bool:
	return card_id < UPGRADE_OFFSET and UPGRADES.has(card_id)


func upgraded_id(card_id: int) -> int:
	return card_id + UPGRADE_OFFSET if can_upgrade(card_id) else card_id


func is_valid_card(card_id: int) -> bool:
	return DEFINITIONS.has(card_id) or (card_id >= UPGRADE_OFFSET and UPGRADES.has(card_id - UPGRADE_OFFSET))


var _upgrade_cache := {}
# 文字里跟着数字的说法（只换第一处，避免改到"她要……时再+1"之类的附加条件）。
const UPGRADE_TEXT_LABELS := {
	"damage": "(伤害|全体基础)", "block": "(格挡)", "draw": "(抽牌|抽)", "cost": "(费)",
	"combo": "(连击)", "attack_reduction": "(伤害|敌攻)",
}


func _upgraded_definition(base: int) -> Dictionary:
	if _upgrade_cache.has(base):
		return _upgrade_cache[base]
	var definition: Dictionary = DEFINITIONS[base].duplicate(true)
	var spec: Dictionary = UPGRADES[base]
	var changes: Array = []
	for key in spec:
		if key in ["face", "battle", "reward"]:
			continue
		changes.append([key, int(definition.get(key, 0)), int(spec[key])])
		definition[key] = spec[key]
	definition["name"] = str(definition["name"]) + "+"
	definition["upgraded"] = true
	for field in ["battle", "reward"]:
		if spec.has(field):
			definition[field] = spec[field]
		else:
			definition[field] = _retext(str(definition.get(field, "")), changes).replace(str(DEFINITIONS[base]["name"]), str(definition["name"]))
	if spec.has("face"):
		definition["face"] = spec["face"]
	elif definition.has("face"):
		var face: Array = definition["face"].duplicate()
		for change in changes:
			for index in range(face.size()):
				var replaced := _retext(str(face[index]), [change])
				if replaced != str(face[index]):
					face[index] = replaced
					break
		definition["face"] = face
	_upgrade_cache[base] = definition
	return definition


func _retext(text: String, changes: Array) -> String:
	for change in changes:
		if not UPGRADE_TEXT_LABELS.has(change[0]):
			continue
		var regex := RegEx.new()
		regex.compile("(%s\\s?[+-]?)%d(?![0-9])" % [UPGRADE_TEXT_LABELS[change[0]], int(change[1])])
		text = regex.sub(text, "${1}%d" % int(change[2]))
	return text


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


func get_reward_card_ids(owned_cards: Array[int] = [], chapter: int = 1) -> Array[int]:
	var candidates: Array[int] = []
	for card_id in REWARD_CARD_IDS:
		var definition := get_definition(card_id)
		# 能力牌同名不叠加，拿过就不再出；第二章紫线牌只在第二章出现。
		if definition.get("type", "") == "能力" and (card_id in owned_cards or upgraded_id(card_id) in owned_cards):
			continue
		if int(definition.get("chapter", 1)) > chapter:
			continue
		candidates.append(card_id)
	return candidates


func get_rarity(card_id: int) -> String:
	card_id = base_id(card_id)
	return str(get_definition(card_id).get("rarity", LEGACY_RARITY.get(card_id, RARITY_COMMON)))


# 抽奖权重（整数，放大 2 倍以表示 ×1.5）：稀有度；拿到某条路线的引擎牌后，同路线的牌 ×1.5；
# 剑境二起罕见、稀有各 +1。
func reward_weight(card_id: int, owned_cards: Array[int], realm: int = 0) -> int:
	var rarity := get_rarity(card_id)
	var weight := int(RARITY_WEIGHTS[rarity]) * 2
	if rarity != RARITY_COMMON and realm >= 2:
		weight += 2
	for engine in ROUTE_ENGINES:
		if (engine in owned_cards or upgraded_id(engine) in owned_cards) and card_id in ROUTE_ENGINES[engine]:
			weight = int(weight * 1.5)
			break
	return weight


# 按稀有度加权、不重复地抽奖励牌。
func roll_reward_cards(owned_cards: Array[int], count: int, chapter: int, rng: RandomNumberGenerator = null, realm: int = 0) -> Array[int]:
	var pool := get_reward_card_ids(owned_cards, chapter)
	var result: Array[int] = []
	while result.size() < count and not pool.is_empty():
		var total := 0
		for card_id in pool:
			total += reward_weight(card_id, owned_cards, realm)
		var roll := (randi() if rng == null else rng.randi()) % total
		for card_id in pool:
			roll -= reward_weight(card_id, owned_cards, realm)
			if roll < 0:
				result.append(card_id)
				pool.erase(card_id)
				break
	return result
