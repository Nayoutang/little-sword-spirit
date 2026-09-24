extends Node

# 敌人基础数值与行动权重。战斗脚本只负责使用这些配置。
const NORMAL := {
	"count_min": 1,
	"count_max": 4,
	"hp_min": 20,
	"hp_max": 40,
}
const ELITE := {
	"count_min": 1,
	"count_max": 4,
	"hp_min": 40,
	"hp_max": 60,
}
const BOSS := {
	"count_min": 1,
	"count_max": 1,
	"hp_min": 200,
	"hp_max": 200,
}

const ATTACK_DAMAGE_MIN := 6
const ATTACK_DAMAGE_MAX := 10
const DEFENSE_MIN := 5
const DEFENSE_MAX := 9
const STRENGTH_GAIN := 2

# 累计概率上限：攻击40%、防御20%、强化15%、诅咒15%、其他10%。
const INTENT_ATTACK_END := 40
const INTENT_DEFEND_END := 60
const INTENT_ENHANCE_END := 75
const INTENT_CURSE_END := 90
