
extends RefCounted

# 大话骰（离线）。规则：
# - 你和小墨各摇 5 颗骰子，只看得见自己的。
# - 轮流叫「N 个 F」（F 为 2～6）。后叫的必须更大：个数更多，或个数相同、点数更大。
# - 1 点是「赖子」，算作任何点数。
# - 不信对方就「开」：两边所有骰子里 F 和 1 的个数 ≥ N，叫的人赢，否则开的人赢。
# - 每人三枚铜钱，输一轮交给对方一枚，先输光的输掉这一局。输的人先叫下一轮。
#
# 小墨叫数时会说一句话、停顿一下。她心里没底（吹牛）的时候，话和停顿会露破绽；
# 一起玩得越多，破绽越可靠——「越来越懂她」。

const DICE := 5
const COINS := 3
const MIN_COUNT := 2
const MAX_COUNT := DICE * 2
const WILD := 1

# 她叫数时的台词。{n}{f} 填叫的数。
const HONEST_LINES := [
	"{n}个{f}。", "那就{n}个{f}。", "嗯……{n}个{f}。", "{n}个{f}，该你了。", "我叫{n}个{f}。",
]
# 吹牛时：话多、急着催你、岔开话题。
const BLUFF_LINES := [
	"{n}个{f}！不信你开啊。", "{n}个{f}。……你看我做什么，快叫。", "今天的茶是不是淡了点？哦，{n}个{f}。",
	"{n}个{f}，这把我稳了，稳得很。", "{n}个{f}。你要开就开，我才不怕。",
]
# 她手上的小动作，也只在心虚时更常出现。
const BLUFF_GESTURES := ["她拨了一下剑穗。", "她把骰盅往你那边推了推。", "她别过脸去看窗外。"]
const OPEN_LINES := ["开！我不信。", "你吹牛。开。", "这个我可不信——开。"]
const CAUGHT_LINES := ["……你怎么看出来的？", "哼，算你眼尖。", "不算不算，刚才那把我手滑。"]
const WIN_BLUFF_LINES := ["嘿嘿，我刚才是蒙的。", "你也有被我骗到的时候。"]
const PLAYER_CAUGHT_LINES := ["被我抓到了吧？你吹牛的时候眼睛会往上看。", "就知道你在诈我。"]
const PLAYER_TRUE_LINES := ["……居然是真的。", "好吧，这把你没骗人。"]

var rng: RandomNumberGenerator
var player_dice: Array[int] = []
var xiaomo_dice: Array[int] = []
var player_coins := COINS
var xiaomo_coins := COINS
var bid_count := 0
var bid_face := 0
var bid_by := ""  # "player" / "xiaomo"
var bid_bluff := false  # 小墨最近一次叫数是否心虚
var turn := "player"
var history: Array[Dictionary] = []
var round_index := 0
var finished := false
var last_result: Dictionary = {}
# 统计：写进小游戏记忆
var caught_bluffs := 0
var fooled_by_bluffs := 0
var games_played := 0  # 之前一起玩过几局，决定破绽可靠程度


func _init(seed_value: int = -1, previous_games: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	games_played = maxi(previous_games, 0)


static func face_name(face: int) -> String:
	return ["", "一", "二", "三", "四", "五", "六"][clampi(face, 0, 6)]


static func count_name(count: int) -> String:
	return ["零", "一", "两", "三", "四", "五", "六", "七", "八", "九", "十"][clampi(count, 0, 10)]


static func bid_text(count: int, face: int) -> String:
	return "%s个%s" % [count_name(count), face_name(face)]


# 破绽的可靠程度：第一局 65%，一起玩多了到 90%。
func tell_reliability() -> float:
	return minf(0.65 + 0.04 * games_played, 0.9)


func start_round(first: String = "") -> void:
	round_index += 1
	player_dice = _roll()
	xiaomo_dice = _roll()
	bid_count = 0
	bid_face = 0
	bid_by = ""
	bid_bluff = false
	history.clear()
	last_result = {}
	if not first.is_empty():
		turn = first


func _roll() -> Array[int]:
	var dice: Array[int] = []
	for i in range(DICE):
		dice.append(rng.randi_range(1, 6))
	dice.sort()
	return dice


func is_legal_bid(count: int, face: int) -> bool:
	if face < 2 or face > 6 or count < MIN_COUNT or count > MAX_COUNT:
		return false
	if bid_count == 0:
		return true
	return count > bid_count or (count == bid_count and face > bid_face)


# 最小的合法加注：给界面当默认值。
func minimum_raise(face: int) -> int:
	if bid_count == 0:
		return MIN_COUNT
	return bid_count if face > bid_face else bid_count + 1


static func matches(dice: Array[int], face: int) -> int:
	var total := 0
	for value in dice:
		if value == face or value == WILD:
			total += 1
	return total


func actual_count(face: int) -> int:
	return matches(player_dice, face) + matches(xiaomo_dice, face)


# 至少 need 个成功，trials 次、每次 1/3（目标点数或赖子）。
static func at_least(need: int, trials: int) -> float:
	if need <= 0:
		return 1.0
	if need > trials:
		return 0.0
	var total := 0.0
	for k in range(need, trials + 1):
		total += _choose(trials, k) * pow(1.0 / 3.0, k) * pow(2.0 / 3.0, trials - k)
	return total


static func _choose(n: int, k: int) -> float:
	var result := 1.0
	for i in range(k):
		result = result * float(n - i) / float(i + 1)
	return result


# 从她的视角看「N 个 F」为真的概率。
func xiaomo_belief(count: int, face: int) -> float:
	return at_least(count - matches(xiaomo_dice, face), DICE)


# ---- 玩家行动 ----

func player_bid(count: int, face: int) -> bool:
	if finished or turn != "player" or not is_legal_bid(count, face):
		return false
	_set_bid("player", count, face, false)
	turn = "xiaomo"
	return true


func player_open() -> Dictionary:
	if finished or turn != "player" or bid_by != "xiaomo":
		return {}
	return _reveal("player")


# ---- 小墨行动 ----

# 返回 {"action": "bid"/"open", "count", "face", "bluff", "line", "gesture", "delay"}
func xiaomo_decide() -> Dictionary:
	if finished or turn != "xiaomo":
		return {}
	if bid_by == "player":
		var belief := xiaomo_belief(bid_count, bid_face)
		var threshold := 0.38 + rng.randf_range(-0.06, 0.06)
		if belief < threshold or bid_count >= MAX_COUNT:
			return {"action": "open", "line": _pick(OPEN_LINES), "delay": 0.8}
	var choice := _choose_bid()
	if choice.is_empty():
		return {"action": "open", "line": _pick(OPEN_LINES), "delay": 0.8}
	var bluff: bool = choice.bluff
	# 破绽：可靠时，心虚就用心虚的话、停顿短；不可靠时反过来。
	var shows_tell := bluff if rng.randf() < tell_reliability() else not bluff
	var line := _pick(BLUFF_LINES if shows_tell else HONEST_LINES)
	line = line.replace("{n}", count_name(choice.count)).replace("{f}", face_name(choice.face))
	var gesture := ""
	if shows_tell and rng.randf() < 0.6:
		gesture = _pick(BLUFF_GESTURES)
	return {"action": "bid", "count": choice.count, "face": choice.face, "bluff": bluff,
		"line": line, "gesture": gesture, "delay": 0.45 if shows_tell else 1.2}


func apply_xiaomo(decision: Dictionary) -> Dictionary:
	if decision.is_empty():
		return {}
	if decision.action == "open":
		return _reveal("xiaomo")
	_set_bid("xiaomo", int(decision.count), int(decision.face), bool(decision.bluff))
	turn = "player"
	return {}


func _choose_bid() -> Dictionary:
	var candidates: Array[Dictionary] = []
	var start := MIN_COUNT if bid_count == 0 else bid_count
	for count in range(start, mini(start + 3, MAX_COUNT) + 1):
		for face in range(2, 7):
			if is_legal_bid(count, face):
				candidates.append({"count": count, "face": face, "p": xiaomo_belief(count, face)})
	if candidates.is_empty():
		return {}
	# 有把握的叫法里挑最稳的那个（个数越小越好，同个数挑把握大的）。
	var safe := candidates.filter(func(c): return c.p >= 0.55)
	# 落后时更敢吹。
	var bluff_rate := 0.3 + (0.15 if xiaomo_coins < player_coins else 0.0)
	if not safe.is_empty() and rng.randf() >= bluff_rate:
		safe.sort_custom(func(a, b): return a.count < b.count or (a.count == b.count and a.p > b.p))
		var pick: Dictionary = safe[0]
		return {"count": pick.count, "face": pick.face, "bluff": false}
	# 吹牛：挑一个心里没底、但听起来不离谱的最小加注。
	var risky := candidates.filter(func(c): return c.p >= 0.15 and c.p < 0.55)
	if risky.is_empty():
		if safe.is_empty():
			return {}
		var fallback: Dictionary = safe[0]
		return {"count": fallback.count, "face": fallback.face, "bluff": false}
	risky.sort_custom(func(a, b): return a.count < b.count or (a.count == b.count and a.p > b.p))
	var bluff_pick: Dictionary = risky[mini(rng.randi_range(0, 1), risky.size() - 1)]
	return {"count": bluff_pick.count, "face": bluff_pick.face, "bluff": true}


func _set_bid(who: String, count: int, face: int, bluff: bool) -> void:
	bid_by = who
	bid_count = count
	bid_face = face
	bid_bluff = bluff
	history.append({"by": who, "count": count, "face": face})


# 开骰：结算这一轮，返回结果。
func _reveal(opener: String) -> Dictionary:
	var actual := actual_count(bid_face)
	var bid_true := actual >= bid_count
	var winner := bid_by if bid_true else opener
	var loser := "xiaomo" if winner == "player" else "player"
	if loser == "player":
		player_coins -= 1
	else:
		xiaomo_coins -= 1
	var line := ""
	if opener == "player":
		if bid_bluff and not bid_true:
			caught_bluffs += 1
			line = _pick(CAUGHT_LINES)
		elif not bid_true:
			line = "……我也没想到会差这么多。"
		else:
			line = _pick(WIN_BLUFF_LINES) if bid_bluff else "我可没骗你。"
	else:
		line = _pick(PLAYER_TRUE_LINES) if bid_true else _pick(PLAYER_CAUGHT_LINES)
	if bid_by == "xiaomo" and bid_bluff and opener == "player" and bid_true:
		fooled_by_bluffs += 1
	finished = player_coins <= 0 or xiaomo_coins <= 0
	turn = loser
	last_result = {"opener": opener, "bidder": bid_by, "count": bid_count, "face": bid_face,
		"actual": actual, "bid_true": bid_true, "winner": winner, "loser": loser,
		"bluff": bid_bluff and bid_by == "xiaomo", "line": line, "game_over": finished}
	return last_result


func player_won() -> bool:
	return finished and xiaomo_coins <= 0


func result_summary() -> String:
	var outcome := "你赢了" if player_won() else "她赢了"
	var detail := "看穿了她 %d 次吹牛" % caught_bluffs if caught_bluffs > 0 else "一次也没看穿她吹牛"
	return "大话骰：%s，%s。" % [outcome, detail]


func _pick(pool: Array) -> String:
	return str(pool[rng.randi_range(0, pool.size() - 1)])
