extends Node

# 全局平衡参数。这里只放跨系统通用的静态数值，不保存运行状态。
const PLAYER_START_MAX_HP := 90
const ROUTE_TOTAL_LAYERS := 20
const PLAYER_START_ENERGY := 3
const HAND_DRAW_COUNT := 4
const ATTACK_COMBO_BONUS := 2

const BOND_MIN := 0
const BOND_MAX := 100
const BOND_STAGE_THRESHOLDS := [0, 25, 50, 75]
const BOND_STAGE_NAMES := ["初遇", "相识", "交心", "生死之交"]

const BATTLE_BOND_GAIN := 2

# 暗线「信 / 执」：不显示给玩家，只由本地结算和回家心事的抉择改动。
# 信 = 她信你会回来、信你们能并肩；执 = 她放不下你、宁可自己挡在前面。
const HIDDEN_MIN := 0
const HIDDEN_MAX := 100
const HIDDEN_PROMISE_KEPT_TRUST := 4
const HIDDEN_PROMISE_BROKEN_TRUST := -3
# 本趟每接住一次她留的机会 +1 信，单趟上限。
const HIDDEN_OPPORTUNITY_TRUST_CAP := 3
const HIDDEN_FELL_ATTACHMENT := 3
const HIDDEN_RECKLESS_ATTACHMENT := 2
# 本趟最低血量一直在一半以上：她稍微放心。
const HIDDEN_SAFE_ATTACHMENT := -1
const EVENT_HEAL_AMOUNT := 30
const EVENT_MAX_HP_INCREASE := 10

# 第二章 · 紫线（数值首版，待试玩）
const THREAD_HITS_BASE := 3
const THREAD_HITS_TRAINED := 2
const THREAD_TRAINED_AT := 6
const THREAD_SELF_BREAK_AT := 15
const THREAD_MAX_ON_XIAOMO := 2
# 两根线时「被牵」：持线者获得的护甲。
const THREAD_DRAGGED_GUARD := 6
# 木偶刀手在她被缠时的借力加伤。
const THREAD_BLADE_BONUS := 4
# 线上战斗胜利的额外回复。
const THREAD_ROUTE_HEAL := 6
# 剑谱·收剑：本回合没出攻击牌时，她的防护多给的格挡（攻击伤害另翻倍）。
const SHOUJIAN_BLOCK := 6
