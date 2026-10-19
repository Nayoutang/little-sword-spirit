extends RefCounted

# 第二章 · 线头、第三章 · 提线 的剧情文本与专属插画。
# 两章剧情与剑谱均已接入专属美术，归途复用家中背景。
# 每页：bg 背景、lines 逐句显示；choices 为两条回应，选后显示 reply 再继续。
# 「：」前是说话人，没有说话人的是旁白。

const SCROLL_NAMES := {
	"duansi": "剑谱残页·一「断丝」",
	"huixian": "剑谱残页·二「回线」",
	"jiesi": "剑谱残页·三「借丝」",
	"shoujian": "剑谱·收剑",
}
const SCROLL_RULES := {
	"duansi": "同一回合连续两次打中同一个持线者，第二次算两次命中。",
	"huixian": "斩断一根线时，持线者这一回合要做的事作废。",
	"jiesi": "斩断一根线时，你抽 1 张牌。",
	"shoujian": "你一回合没打出攻击牌就结束回合时，她这一回合的攻击伤害翻倍，防护多给 6 格挡。",
}
const SCROLL_NOTES := {
	"shoujian": "收手的剑。你先收住，她替你出这一剑。往后一直有效。",
}
const SCROLL_ART := {
	"duansi": preload("res://art/story/chapter_two/scroll_duansi_v1.png"),
	"huixian": preload("res://art/story/chapter_two/scroll_huixian_v1.png"),
	"jiesi": preload("res://art/story/chapter_three/scroll_jiesi_v1.png"),
	"shoujian": preload("res://art/story/chapter_three/scroll_shoujian_v1.png"),
}

const STORIES := {
	"ch2_opening": {
		"title": "第二章 · 线头",
		"pages": [
			{"bg": "res://art/story/chapter_two/ch2_opening_window_v1.png", "lines": [
				"夜里，小墨坐在窗边。剑穗上缠着一截从旧祠带回来的断线，还泛着一点紫，一直朝东北方向轻轻地动。",
				"小墨：线断了，那头的人就知道了。",
				"小墨：他知道我醒了。……与其在这里等他找上门，不如我们先去找他。",
				"小墨：地图上还有两处记号，是他以前常去的地方。去看看吧。",
			]},
		],
	},
	"ch2_blacksmith": {
		"title": "奇遇 · 铁匠铺",
		"scroll": "duansi",
		"moment": "镇口的老铁匠还了一页剑谱。小墨说，「小墨」这个名字是他起的。",
		"pages": [
			{"bg": "res://art/story/chapter_two/ch2_blacksmith_arrival_v1.png", "lines": [
				"镇口有一间老铁匠铺。炉火很旺，老铁匠盯着小墨腰间的剑看了半天。",
				"老铁匠：这把剑，我修过。",
			]},
			{"bg": "res://art/story/chapter_two/ch2_blacksmith_page_v1.png", "lines": [
				"多年前，有个银发剑客来修剑镡，身上没带钱，压了一页剑谱当工钱。",
				"老铁匠：他说，哪天有人带着这把剑来，就把这页还给她。",
				"小墨：……是他的字。写得还是这么难看。",
				"小墨：「小墨」这个名字，是他起的。捡到我的时候，剑身黑得跟墨一样。",
			], "choices": [
				{"text": "「这页你收着。」", "reply": ["小墨：……嗯。不过招是练给你看的，你得在旁边。"]},
				{"text": "「念给我听听？」", "reply": ["小墨：念什么念，字丑成这样。", "她嘴上这么说，还是低声念了第一行。"]},
			]},
			{"bg": "res://art/story/chapter_two/ch2_blacksmith_departure_v1.png", "lines": [
				"出门时，老铁匠在背后补了一句。",
				"老铁匠：他那时候说，这把剑脾气大，跟着他受委屈了。",
				"小墨没回头，脚步慢了一下。",
			]},
		],
	},
	"ch2_trip1_return": {
		"title": "归途",
		"pages": [
			{"bg": "res://art/backgrounds/home_room_v2.png", "lines": [
				"小墨：他牵着的都是死人。那个刀客身上的衣服还是好的，大概也就死了一两年。",
				"小墨：……线比上次在旧祠的细。他不是冲着刀客去的，那只是顺手。",
				"小墨：下一处记号在南边的镇子。歇够了，我们再走。",
			]},
		],
	},
	"ch2_troupe": {
		"title": "奇遇 · 傀儡戏班",
		"scroll": "huixian",
		"moment": "空戏台后面，小墨说出了旧祠那具尸身真正是做什么用的。",
		"pages": [
			{"bg": "res://art/story/chapter_two/ch2_troupe_empty_stage_v1.png", "lines": [
				"路过一个镇子，戏班子刚走，戏台还没拆。",
				"台下的人说：戏好看，那些木偶跟真人一样，会笑，还会擦汗。",
			]},
			{"bg": "res://art/story/chapter_two/ch2_troupe_shells_v1.png", "lines": [
				"台后的箱子里摆着一排没上线的木偶，都是空的。最底下压着一页剑谱，上面缠着一截紫线，像是故意留的。",
				"小墨：木偶会擦汗？……木头里得有东西才会。",
				"小墨：旧祠那个，他不是牵来杀我的。",
				"小墨：他是想让我住进去。剑灵进了壳，傀儡就跟活人一样了。",
			], "choices": [
				{"text": "「那他找错人了。」", "reply": ["小墨：嗯。我有地方住。"]},
				{"text": "「你早就猜到了？」", "reply": ["小墨：在旧祠就猜到了。那时候不想说，怕你觉得我是什么麻烦东西。"]},
			]},
			{"bg": "res://art/story/chapter_two/ch2_troupe_cut_v1.png", "lines": [
				"小墨把那截紫线绕在指头上，扯断了。",
			]},
		],
	},
	"ch2_ending": {
		"title": "第二章 · 线头 · 终",
		"pages": [
			{"bg": "res://art/story/chapter_two/ch2_ending_rooftop_v1.png", "lines": [
				"远处戏楼的屋檐上站着一个人，十根手指上都垂着紫线。他没有动手。",
				"戏先生：醒了就好。这七年，让我好找。",
				"戏先生：下次见面，带着她来戏台。",
				"他走了。",
			]},
			{"bg": "res://art/backgrounds/home_room_v2.png", "lines": [
				"回到家，小墨把断碑的事说了出来：她不是自己睡在那里的，是他把她封进去的。",
				"小墨：那天他说，睡一觉，醒来就有人来接我了。",
				"小墨：我醒来的时候，等到的是你。",
			]},
		],
	},

	# ---- 剑境 · 五 打通（在家播）----
	"realm5_clear": {
		"title": "剑境 · 五",
		"pages": [
			{"bg": "res://art/backgrounds/home_room_v2.png", "lines": [
				"回到家，小墨把剑横在膝上，看了很久。",
				"小墨：这一路，最难的那几场，你都没退。",
				"小墨：他那时候说我脾气大，跟着谁都受委屈。……跟着你，好像没有。",
				"小墨：往后还要走的话，我也还跟着。",
			]},
		],
	},

	# ---- 第三章 · 提线 ----
	"ch3_opening": {
		"title": "第三章 · 提线",
		"pages": [
			{"bg": "res://art/story/chapter_three/ch3_opening_dawn_v1.png", "lines": [
				"天还没亮，小墨已经醒了。剑穗上那截紫线被她解了下来，放在桌上，线头一直朝着西边。",
				"小墨：戏台在西边的山谷里。他说带着我去，那就是说，他要的是我，不是你。",
				"小墨：我一个人去，他不会为难你。",
			], "choices": [
				{"text": "「我们一起去。」", "reply": ["小墨：……好。那你跟紧我。"]},
				{"text": "「你去哪我去哪。」", "reply": ["小墨：这话说得跟他一模一样。", "小墨：走吧。"]},
			]},
		],
	},
	"ch3_sword_tomb": {
		"title": "奇遇 · 剑冢",
		"scroll": "jiesi",
		"moment": "山谷里的剑冢，小墨听见了那些被线缠住的剑。最深处是他的剑，剑柄上绑着一封信，她说回家再看。",
		"pages": [
			{"bg": "res://art/story/chapter_three/ch3_sword_tomb_v1.png", "lines": [
				"戏班落脚的山谷里，有一片剑冢。地上插满了剑，每一把都缠着细细的紫线。",
				"小墨停下来，侧着头听了一会儿。",
				"小墨：它们都还醒着。说不出话，被线勒着。",
				"小墨：都是他收来的。没有人来接它们。",
			], "choices": [
				{"text": "「等斩了他，线就都断了。」", "reply": ["小墨：嗯。我记着这句。"]},
				{"text": "「你听得见它们说什么？」", "reply": ["小墨：听不清。就是很吵，像好多人一起在哭。", "小墨：别担心，我不会变成它们那样。有你在。"]},
			]},
			{"bg": "res://art/story/chapter_three/ch3_old_sword_letter_v1.png", "lines": [
				"最深处有一把旧剑，剑身上没有线。剑柄上用布条绑着一页剑谱，还有一封信。",
				"小墨：是他的剑。",
				"她把剑谱解下来递给你，信揣进了怀里。",
				"小墨：信回家再看。现在看，我怕我走不动了。",
			]},
			{"bg": "res://art/story/chapter_three/ch3_tomb_departure_v1.png", "lines": [
				"走出剑冢的时候，身后有一把剑轻轻响了一声。",
				"小墨没有回头。",
			]},
		],
	},
	"ch3_trip1_return": {
		"title": "归途",
		"pages": [
			{"bg": "res://art/backgrounds/home_room_v2.png", "lines": [
				"小墨：那个剑灵，线断的时候跟我说了声谢谢，然后就散了。",
				"小墨：它跟我差不多大。就是没等到有人来接。",
				"小墨：……下一趟就是戏台了。这回，把线全都斩了。",
			]},
		],
	},
	"ch3_ending": {
		"title": "第三章 · 提线 · 终",
		"scroll": "shoujian",
		"scroll_at_home": true,
		"pages": [
			{"bg": "res://art/story/chapter_three/ch3_final_thread_v1.png", "lines": [
				"最后一根主线，是你和小墨一起斩断的。",
				"戏先生手上的线一根接一根地松了下来。他低头看了一会儿空空的手指，什么也没说。",
				"山谷那边，剑冢里所有的剑同时轻轻响了一声。",
			]},
			{"bg": "res://art/story/chapter_three/ch3_lamplit_letter_v1.png", "lines": [
				"回到家，小墨在灯下拆开了那封信。信是写给「下一个拿起她的人」的。",
				"信：不知道你是谁，先谢过。",
				"信：她嘴硬，怕黑，更怕被留下。别让她一个人等太久。",
				"信：最后一式我始终没练成，叫「收剑」。是收手的剑，不是杀人的剑。我一个人总想着替她挡，挡来挡去就收不住。",
				"信：你们两个一起，或许能成。",
				"小墨看完，把信折好，收了起来。",
				"小墨：他说得对。你们两个一起。",
				"小墨：……那就一起练吧。往后的路还长。",
			]},
		],
	},
}


static func has_story(story_id: String) -> bool:
	return STORIES.has(story_id)


static func get_story(story_id: String) -> Dictionary:
	return STORIES.get(story_id, {})
