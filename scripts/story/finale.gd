extends Node2D
const TEXT := {
	"memory": "她把那张旧地图铺在你们常坐的桌上，指尖停在山中的一座旧祠。\n有些过去，她曾经一个人藏了很久。如今，她愿意把它告诉你。\n小墨：有你在，我才敢回去看看。",
	"arrival": "旧祠里的风铃早已锈住。故人的尸身被幽紫细线牵起，举剑逼近。\n小墨只停了一瞬，便握紧了剑。\n他已经走了。留下的这个……我得让它停下来。",
	"alone": "她挡住一剑，又一剑，却没能斩断那些牵引的线。\n剑光熄灭前，她望向来时的山路，像在寻找那扇熟悉的窗。\n小墨：明明……还想回去和你坐一会儿的。\n山风吹散花瓣。她再也没能回家。",
	"victory": "最后一根细线被你们一起斩断。小墨向故人轻轻颔首，转身走到你面前。\n以前的事，到这里就好。\n她伸出手，笑着等你。\n往后的路，我想和你一起走。……我们回家。",
	"sacrifice": "你倒下时，她没有退开半步。最后的剑光，是她为你留下的生路。\n小墨：别说这一趟不值得。我和你走过的每一步，都算数。\n好好活着。还有好多地方……替我们去看看。\n她的笑意化作花瓣。那些束缚终于断了，剑上却再没有她的声音。",
	"journey": "你带着那把失去光芒的灵剑，走向很远的地方。\n仍习惯停下脚步等她，仍会把第二杯茶放在身旁。\n山风偶尔拂过剑穗，像有人轻轻拉了一下你的衣袖。\n你记得，她希望你继续走下去。"
}
const ENDING_TITLES := {"refusal": "结局 · 未归", "victory": "结局 · 同归", "sacrifice": "结局 · 余途"}

var pages: Array[String] = []
var page_index := 0
var finishing := false
@onready var page = $FinaleUI/Page
func _ready() -> void:
	match RunState.finale_mode:
		"refusal": pages.assign(["memory", "arrival", "alone"])
		"victory": pages.assign(["victory"])
		"sacrifice": pages.assign(["sacrifice", "journey"])
		_: pages.assign(["memory", "arrival"])
	$FinaleUI/Continue.pressed.connect(_advance)
	page.sequence_completed.connect(func(): $FinaleUI/Caption.show())
	_show_page()
func _show_page() -> void:
	$FinaleUI/Caption.hide()
	page.begin(load("res://art/story/finale/" + pages[page_index] + "_v2.png"))
	$FinaleUI/Caption.text = TEXT[pages[page_index]]
	if pages[page_index] == "memory" and RunState.finale_mode == "refusal":
		$FinaleUI/Caption.text = "她把地图收好，点了点头，没有责怪你。\n小墨：我知道了。你留在家里吧，别替我担心。\n临走前，她把第二只茶杯放回你身旁，像平常那样。"
	$FinaleUI/Continue.text = "继续"
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_advance()
func _advance() -> void:
	if finishing:
		if RunState.finale_state == "ended":
			RunState.navigate("save_select", self)
		return
	if page.reveal_next(): return
	if page_index + 1 < pages.size():
		page_index += 1
		_show_page()
		return
	finishing = true
	if RunState.finale_mode == "arrival":
		RunState.prepare_finale_battle()
		RunState.navigate("battle", self)
	else:
		RunState.set_finale_state("ended", RunState.finale_mode)
		$FinaleUI/Continue.text = "返回存档"
		$FinaleUI/Caption.text += "\n" + str(ENDING_TITLES.get(RunState.finale_mode, "故事终"))
