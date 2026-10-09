extends RefCounted

# Pure display data. Does not mutate card definitions or battle state.
const CompanionCards = preload("res://scripts/data/companion_card_database.gd")

const PLAYER_MOTIFS := {
	0: "slash", 1: "shield", 2: "eye", 3: "cleave", 4: "gate",
	5: "leaves", 6: "waves", 7: "curse", 8: "breath", 9: "shadow",
	10: "break", 11: "deflect", 12: "sheath", 13: "beam", 14: "lotus",
	15: "wind", 16: "slash", 17: "shield", 18: "gate", 19: "deflect",
}
const COMPANION_MOTIFS := {
	"quick_slash": "slash", "guard_echo": "echo", "follow_up": "crossed",
	"clean_cut": "clean", "lead_momentum": "arrow", "oath_guard": "oath",
	"return_guard": "return", "escort": "escort", "heart_resonance": "resonance",
	"lone_judgment": "lone", "frost_cold": "frost", "ten_steps": "steps",
	"grind_sword": "grind", "cut_water": "water_cut", "long_wind": "wind",
	"behead_loulan": "behead", "yin_mountain": "yin", "few_return": "banner",
}

static func describe(player_card_id: int, companion_card_id: String, effective_cost: int = -1) -> Dictionary:
	if player_card_id >= 0:
		var player_definition: Dictionary = CardDatabase.get_definition(player_card_id)
		var card_type := str(player_definition.get("type", "技巧"))
		var player_accent := Color("#d66e62")
		match card_type:
			"防御": player_accent = Color("#74c7bd")
			"技巧": player_accent = Color("#d9c47f")
			"能力": player_accent = Color("#d9c47f")
			"诅咒": player_accent = Color("#ac83bd")
			"特殊技": player_accent = Color("#75d8df")
			"终极技": player_accent = Color("#f1bc75")
		var player_stats := _player_stats(player_card_id, player_definition)
		return {"name": str(player_definition["name"]), "cost": str(effective_cost if effective_cost >= 0 else player_definition["cost"]),
			"type": card_type, "accent": player_accent, "motif": PLAYER_MOTIFS.get(player_card_id, "slash"),
			"primary": player_stats[0], "secondary": player_stats[1]}
	var definition := CompanionCards.get_definition(companion_card_id)
	var category := "自保"
	var accent := Color("#83bce0")
	if definition.has("poem"):
		category = "剑意"
		accent = Color("#e37a70")
	elif definition.get("stance", "") == CompanionCards.STANCE_INVEST:
		category = "援护"
		accent = Color("#e7c879")
	var stats := _companion_stats(companion_card_id, definition)
	return {"name": str(definition.get("name", "小墨牌")), "cost": "墨",
		"type": category, "accent": accent,
		"motif": COMPANION_MOTIFS.get(companion_card_id, "slash"),
		"primary": stats[0], "secondary": stats[1]}


static func _player_stats(card_id: int, definition: Dictionary) -> Array[String]:
	match card_id:
		CardDatabase.PARRY: return ["格挡5·反击4伤至多2次", "清空连击·反击积势至下回合"]
		CardDatabase.RETAIN_SHIELD: return ["剩余护盾跨回合保留", "能力·包括小墨护盾"]
		CardDatabase.SHIELD_STRIKE: return ["当前护盾100%伤害", "不耗盾·连击+1·不吃连击加伤"]
		CardDatabase.FLOWING_CLOUD: return ["三连攻：抽1 / 精力+1", "能力·每回合一次"]
		CardDatabase.CHASE_WIND: return ["基础伤害 %d" % int(definition["damage"]), "连续攻击减费·连击+1"]
		CardDatabase.STATUS: return ["抽牌 1", "连击清零"]
		CardDatabase.CURSE: return ["无法打出", "占据手牌"]
		CardDatabase.TUNE_BREATH: return ["抽牌 1", "每回合限 1 次"]
		CardDatabase.SHADOW_STEP: return ["抽牌 2", "技巧"]
		CardDatabase.UNLOAD_FORCE: return ["敌攻 -%d" % int(definition["attack_reduction"]), "下次攻击生效"]
		CardDatabase.HIDE_EDGE: return ["格挡 %d" % int(definition["block"]), "回合末保留连击"]
		CardDatabase.FLOWING_LIGHT: return ["基础伤害 %d" % int(definition["damage"]), "需/耗 %d 连击" % int(definition["combo_required"])]
		CardDatabase.BRILLIANCE: return ["基础伤害 %d" % int(definition["damage"]), "需 %d 连击·清零" % int(definition["combo_required"])]
	if definition.has("block"):
		return ["格挡 %d" % int(definition["block"]), "连击清零"]
	if card_id == CardDatabase.SWEEP:
		return ["全体基础 %d" % int(definition["damage"]), "连击 +1"]
	if card_id == CardDatabase.BREAK_EDGE:
		return ["基础伤害 %d" % int(definition["damage"]), "连击 +1·易伤 %d" % int(definition["vulnerable"])]
	return ["基础伤害 %d" % int(definition.get("damage", 0)), "连击 +%d" % int(definition.get("combo", 0))]


static func _companion_stats(card_id: String, definition: Dictionary) -> Array[String]:
	match card_id:
		CompanionCards.LEAD_MOMENTUM: return ["下次攻击 ×2", "让给玩家"]
		CompanionCards.ESCORT: return ["格挡 6", "下次攻击 +4"]
		CompanionCards.FROST_COLD: return ["全体伤害 5", "敌攻 -2"]
		CompanionCards.GRIND_SWORD: return ["本次积蓄剑势", "小墨下次伤害 ×2"]
		CompanionCards.CUT_WATER: return ["下回合防御/状态", "不清空连击层数"]
		CompanionCards.LONG_WIND: return ["下回合精力 +1", "让给玩家"]
		CompanionCards.YIN_MOUNTAIN: return ["拦下一个敌人的全部攻击段", "按修正后总伤害选敌"]
		CompanionCards.FEW_RETURN: return ["致命伤害保留 1 血", "本回合免伤，每场一次"]
		CompanionCards.OATH_GUARD: return ["格挡 10", "守约时 +3"]
		CompanionCards.HEART_RESONANCE: return ["伤害 12+连击×3", "保留连击"]
		CompanionCards.LONE_JUDGMENT: return ["伤害 12+连击×4", "连击清零"]
		CompanionCards.TEN_STEPS: return ["伤害 4+连击×4", "击杀后再释放技能"]
		CompanionCards.BEHEAD_LOULAN: return ["伤害 14", "对最高血敌人，无视格挡"]
	if definition.has("damage") and definition.has("combo_scale"):
		return ["伤害 %d+连击×%d" % [int(definition["damage"]), int(definition["combo_scale"])], "连击 +1"]
	if definition.has("damage"):
		return ["伤害 %d" % int(definition["damage"]), "对低血敌人"]
	if definition.has("block"):
		return ["格挡 %d" % int(definition["block"]), "守护玩家"]
	return [str(definition.get("description", "")), "小墨出牌"]
