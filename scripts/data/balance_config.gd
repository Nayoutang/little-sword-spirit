extends Node

# 全局平衡参数。这里只放跨系统通用的静态数值，不保存运行状态。
const PLAYER_START_MAX_HP := 90
const PLAYER_START_ENERGY := 3
const HAND_DRAW_COUNT := 4
const ATTACK_COMBO_BONUS := 2

const BOND_MIN := 0
const BOND_MAX := 100
const BOND_STAGE_THRESHOLDS := [0, 25, 50, 75]
const BOND_STAGE_NAMES := ["初遇", "相识", "交心", "生死之交"]

const BATTLE_BOND_GAIN := 2
const EVENT_HEAL_AMOUNT := 30
const EVENT_MAX_HP_INCREASE := 10
const REWARD_HEAL_AMOUNT := 10
