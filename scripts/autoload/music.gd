extends Node

# 背景音乐：跨场景常驻，切场景时按曲目交叉淡入淡出；同一首不重播。
# 曲目文件放在 res://audio/music/<曲目ID>.ogg（或 .mp3），缺文件时安静跳过。

const MUSIC_DIR := "res://audio/music/"
const BUS_NAME := "Music"
const FADE_SECONDS := 1.2
const VOLUME_DB := -6.0

# 场景 → 曲目。没列出的场景保持当前音乐不变。
const SCENE_TRACKS := {
	"res://scenes/main_menu.tscn": "menu",
	"res://scenes/save_select.tscn": "menu",
	"res://scenes/intro.tscn": "intro",
	"res://scenes/home.tscn": "home",
	"res://scenes/promise.tscn": "home",
	"res://scenes/relationship_milestone.tscn": "home",
	"res://scenes/map.tscn": "journey",
	"res://scenes/event.tscn": "journey",
	"res://scenes/adventure.tscn": "journey",
	"res://scenes/expedition_poetry.tscn": "poetry",
	"res://scenes/battle_reward.tscn": "journey",
	"res://scenes/settlement.tscn": "home",
	"res://scenes/battle.tscn": "battle",
	"res://scenes/finale.tscn": "finale",
	"res://scenes/chapter_story.tscn": "finale",
}

# 缺某首时退而用哪首（例如没做 Boss 曲就用普通战斗曲）。
const FALLBACKS := {
	"intro": "menu",
	"poetry": "journey",
	"boss": "battle",
	"finale_battle": "boss",
	"finale": "home",
}

var current_track := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tween: Tween
var _cache: Dictionary = {}


# 无界面运行（回归测试、导出检查）时不出声，避免退出时音频回放未释放被判为错误。
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS_NAME) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_NAME)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if not SCENE_TRACKS.has(path):
		return
	var track := str(SCENE_TRACKS[path])
	if track == "battle":
		if RunState.finale_state == "battle":
			track = "finale_battle"
		elif RunState.pending_encounter == RunState.EncounterType.BOSS:
			track = "boss"
	# 这一首（及替代）都还没放文件时，保持当前音乐，不突然静音。
	if _resolve(track).is_empty():
		return
	play(track)


# 播放曲目（按 FALLBACKS 找替代）；传空字符串则淡出停止。
func play(track: String) -> void:
	if _silent:
		return
	var resolved := _resolve(track)
	if resolved == current_track:
		return
	current_track = resolved
	var outgoing := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if resolved.is_empty() and not outgoing.playing:
		return
	_tween = create_tween().set_parallel(true)
	if not resolved.is_empty():
		incoming.stream = _load(resolved)
		incoming.volume_db = -40.0
		incoming.play()
		_tween.tween_property(incoming, "volume_db", VOLUME_DB, FADE_SECONDS)
	if outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", -80.0, FADE_SECONDS)
		_tween.chain().tween_callback(outgoing.stop)


func stop() -> void:
	play("")


func _resolve(track: String) -> String:
	var candidate := track
	var guard := 0
	while not candidate.is_empty() and guard < 6:
		if _load(candidate) != null:
			return candidate
		candidate = str(FALLBACKS.get(candidate, ""))
		guard += 1
	return ""


func _load(track: String) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var stream: AudioStream = null
	for extension: String in ["ogg", "mp3", "wav"]:
		var path := MUSIC_DIR + track + "." + extension
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", true)
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_cache[track] = stream
	return stream


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for player in _players:
		player.stop()
		player.stream = null
	_cache.clear()
