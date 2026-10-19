extends Node

# 音效与小墨的"声音"。文件在 res://audio/sfx/<名字>.ogg 与 res://audio/voice/xiaomo_voice_<n>.ogg，
# 缺文件时静默跳过。只负责播放，不读写任何游戏状态。

const SFX_DIR := "res://audio/sfx/"
const VOICE_DIR := "res://audio/voice/"
const BUS_NAME := "SFX"
const POOL_SIZE := 12
const MIN_REPEAT_MS := 45
const VOICE_GAP := 0.085
const VOICE_MAX_SYLLABLES := 9

# 每种音效的基础音量（dB）与随机音高幅度，避免连续命中听起来像复读。
const PROFILE := {
	"click": [-14.0, 0.05],
	"card": [-8.0, 0.08],
	"hit_light": [-4.0, 0.08],
	"hit_heavy": [-2.0, 0.05],
	"guard_hit": [-6.0, 0.06],
	"shield_up": [-8.0, 0.03],
	"player_hurt": [-4.0, 0.06],
	"kill": [-3.0, 0.04],
	"combo": [-12.0, 0.0],
	"skill": [-1.0, 0.0],
	"xiaomo_strike": [-6.0, 0.05],
	"xiaomo_guard": [-7.0, 0.03],
	"victory": [-5.0, 0.0],
	"defeat": [-5.0, 0.0],
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _voice_streams: Array[AudioStream] = []
var _voice_serial := 0


# 无界面运行（回归测试、导出检查）时不出声，避免退出时音频回放未释放被判为错误。
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS_NAME) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_NAME)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_pool.append(player)
	for index in 32:
		var path := VOICE_DIR + "xiaomo_voice_%d.ogg" % index
		if not ResourceLoader.exists(path):
			break
		_voice_streams.append(load(path))
	# 所有按钮统一一声轻响；手牌等自带音效的按钮设 meta "sfx_silent"。
	get_tree().node_added.connect(_on_node_added)


func play(sound: String, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if _silent:
		return
	var stream := _load(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < MIN_REPEAT_MS:
		return
	_last_played[sound] = now
	var profile: Array = PROFILE.get(sound, [-6.0, 0.05])
	var spread := float(profile[1])
	_play_stream(stream, float(profile[0]) + volume_offset_db, pitch * randf_range(1.0 - spread, 1.0 + spread))


# 小墨说话：按台词长度念一串轻声音节（不是真人配音，像"嘀咕"）。
func voice(text: String, volume_offset_db: float = 0.0) -> void:
	if _silent:
		return
	if _voice_streams.is_empty():
		return
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	_voice_serial += 1
	var serial := _voice_serial
	var count := clampi(int(ceil(clean.length() / 3.0)), 2, VOICE_MAX_SYLLABLES)
	var base_pitch := randf_range(0.97, 1.05)
	for index in count:
		if serial != _voice_serial or not is_inside_tree():
			return
		var stream: AudioStream = _voice_streams[randi() % _voice_streams.size()]
		# 句尾稍微下沉；问句上扬。
		var contour := 1.0
		if index == count - 1:
			contour = 1.08 if clean.ends_with("？") or clean.ends_with("?") else 0.93
		_play_stream(stream, -13.0 + volume_offset_db, base_pitch * contour * randf_range(0.96, 1.04))
		await get_tree().create_timer(VOICE_GAP * randf_range(0.85, 1.2)).timeout


func stop_voice() -> void:
	_voice_serial += 1


func _play_stream(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func _load(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := SFX_DIR + sound + ".ogg"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(func():
			if not button.has_meta("sfx_silent"):
				play("click")
		)


func _exit_tree() -> void:
	# 退出时释放音频资源，避免引擎报告资源仍被占用。
	for player in _pool:
		player.stop()
		player.stream = null
	_cache.clear()
	_voice_streams.clear()
