extends Node

# 仅用于随机消耗差分检查，不改变抽样。
var role_random_calls := 0

# 敌人基础数值与行动权重。战斗脚本只负责使用这些配置。
const NORMAL := {
	"count_min": 2,
	"count_max": 2,
	"hp_min": 40,
	"hp_max": 48,
}
const ELITE := {
	"count_min": 2,
	"count_max": 2,
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

const BOSS_ATTACK := 8
const BOSS_GUARD := 8
const BOSS_HEAVY := 18
const BOSS_ENRAGED_HEAVY := 22
const BOSS_INTERRUPT_HITS := 3

const SWORDSMAN := "swordsman"
const GUARDIAN := "guardian"
const HEXER := "hexer"
const ROLES := {
	SWORDSMAN: {"name": "影剑客", "attack": 6, "heavy": 12, "hp_offset": 0, "rule": "普攻与蓄力重击交替"},
	GUARDIAN: {"name": "墨甲守卫", "attack": 6, "guard": 8, "hp_offset": 0, "rule": "护卫与普攻交替；护卫优先保护同伴"},
	HEXER: {"name": "咒师", "attack": 4, "hp_offset": -6, "rule": "普攻与塞入心魔交替；心魔仅本场战斗有效"},
	# 第二章 · 戏班
	PUPPET: {"name": "提线木偶", "attack": 6, "fallback": 6, "hp_offset": 0, "rule": "抛线与普攻交替；抛线会缠住小墨"},
	BLADE: {"name": "木偶刀手", "attack": 6, "heavy": 12, "hp_offset": 0, "rule": "普攻与重击交替；小墨被缠时攻击 +4"},
	THREADER: {"name": "线师", "attack": 3, "fallback": 3, "hp_offset": -10, "rule": "每回合抛线；她身上线满时改为出手 3"},
	BOX: {"name": "替身箱偶", "attack": 6, "guard": 8, "hp_offset": 4, "rule": "护卫与普攻交替；同伴抛出的线由它替持，持线时只护自己"},
	WATCHER: {"name": "戏班的看台人", "attack": 0, "hp_offset": 0, "rule": "不出手，每回合抛线；线满时给刀手各加 6 护盾"},
}
const PUPPET := "thread_puppet"
const BLADE := "puppet_blade"
const THREADER := "thread_master"
const BOX := "stand_in_box"
const WATCHER := "troupe_watcher"
const THREAD_BOSS_NAME := "牵线的刀客"
# 第三章首领（RunState.chapter_boss() 的 id）
const BOUND_SPIRIT := "bound_spirit"
const CURSE_GUARDIAN := "curse_guardian"
const PUPPETEER := "puppeteer"
const CHAPTER_BOSS_NAMES := {"thread_blade_boss": THREAD_BOSS_NAME, BOUND_SPIRIT: "被牵着的剑灵", PUPPETEER: "戏先生", CURSE_GUARDIAN: "咒剑守卫"}
const THREAD_THROWERS := [PUPPET, THREADER, WATCHER]


func get_encounter_roles(layer: int, count: int, elite: bool, rng: RandomNumberGenerator = null) -> Array[String]:
	var result: Array[String] = []
	if layer <= 3 and not elite:
		var role := SWORDSMAN if layer <= 1 else (GUARDIAN if layer == 2 else HEXER)
		for index in range(count):
			result.append(role)
	else:
		var pairs := [[SWORDSMAN, GUARDIAN], [GUARDIAN, HEXER], [SWORDSMAN, HEXER]]
		role_random_calls += 1
		var pair: Array = pairs[randi_range(0, pairs.size() - 1) if rng == null else rng.randi_range(0, pairs.size() - 1)]
		for index in range(count):
			result.append(pair[index % pair.size()])
	return result


# 第二章：线上的战斗一定有会抛线的；线外只出刀手和箱偶。
func get_chapter_two_roles(layer: int, count: int, elite: bool, on_thread: bool, rng: RandomNumberGenerator = null) -> Array[String]:
	var pairs: Array
	if not on_thread:
		pairs = [[BLADE]] if layer <= 1 else [[BLADE, BOX], [BLADE, BLADE], [BOX, BLADE]]
	elif elite:
		pairs = [[BLADE, THREADER, BOX], [THREADER, BLADE, PUPPET]]
	elif layer <= 1:
		pairs = [[PUPPET]]
	elif layer <= 3:
		pairs = [[PUPPET, PUPPET], [PUPPET, BLADE]]
	else:
		pairs = [[PUPPET, BLADE], [THREADER, BLADE], [BOX, PUPPET], [THREADER, BOX]]
	role_random_calls += 1
	var pair: Array = pairs[randi_range(0, pairs.size() - 1) if rng == null else rng.randi_range(0, pairs.size() - 1)]
	var result: Array[String] = []
	for index in range(count):
		result.append(str(pair[index % pair.size()]))
	return result


func thread_intent(role: String) -> Dictionary:
	return {"type": 4, "value": 0, "thread": true, "fallback": int(ROLES[role].get("fallback", 0)) if ROLES.has(role) else BOSS_ATTACK}


func get_role_intent(role: String, step: int, elite: bool, layer: int = 1) -> Dictionary:
	var definition: Dictionary = ROLES[role]
	var bonus := 2 if elite else 0
	var depth := int(maxi(clampi(layer, 1, BalanceConfig.ROUTE_TOTAL_LAYERS - 1) - 1, 0) / 4.0)
	if role in [THREADER, WATCHER] or (role == PUPPET and step % 2 == 0):
		var intent := thread_intent(role)
		intent["fallback"] = int(intent["fallback"]) + (bonus + depth if int(intent["fallback"]) > 0 else 0)
		return intent
	if role == BOX and step % 2 == 0:
		return {"type": 1, "value": int(definition["guard"]) + bonus + depth * 2, "support": true}
	if role == BLADE:
		var blade_heavy := step % 2 == 1
		return {"type": 0, "value": int(definition["heavy"] if blade_heavy else definition["attack"]) + bonus + depth * (2 if blade_heavy else 1), "heavy": blade_heavy, "borrow": true}
	if role == GUARDIAN and step % 2 == 0:
		return {"type": 1, "value": int(definition["guard"]) + bonus + depth * 2, "support": true}
	if role == HEXER and step % 2 == 1:
		return {"type": 3, "value": 1}
	var heavy := role == SWORDSMAN and step % 2 == 1
	return {"type": 0, "value": int(definition["heavy"] if heavy else definition["attack"]) + bonus + depth * (2 if heavy else 1), "heavy": heavy}


func get_normal_config(layer: int) -> Dictionary:
	layer = clampi(layer, 1, BalanceConfig.ROUTE_TOTAL_LAYERS - 1)
	if layer <= 1:
		return {"count_min": 1, "count_max": 1, "hp_min": 34, "hp_max": 38}
	if layer <= 3:
		return {"count_min": 1, "count_max": 2, "hp_min": 40 + (layer - 2) * 3, "hp_max": 46 + (layer - 2) * 3}
	return {"count_min": 2, "count_max": 2, "hp_min": 46 + (layer - 4) * 3, "hp_max": 56 + (layer - 4) * 3}


func get_elite_config(layer: int) -> Dictionary:
	var normal := get_normal_config(layer)
	return {"count_min": 2, "count_max": 2, "hp_min": int(normal["hp_min"]) + 14, "hp_max": int(normal["hp_max"]) + 22}


func get_boss_config(layer: int) -> Dictionary:
	var depth := int(maxi(clampi(layer, 1, BalanceConfig.ROUTE_TOTAL_LAYERS - 1) - 9, 0) / 5.0)
	return {"hp": BOSS["hp_min"] + depth * 60, "attack": BOSS_ATTACK + depth * 2, "guard": BOSS_GUARD + depth * 4, "heavy": BOSS_HEAVY + depth * 4, "enraged_heavy": BOSS_ENRAGED_HEAVY + depth * 5}
