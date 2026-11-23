extends Node
## Sound effects (pooled 3D + 2D players) and per-level music loops. All audio is synthesized by
## tools/synth_audio.py (original, generated from code).

const MUSIC := ["level1", "level2", "level3", "level4", "level5", "level6"]
var _streams := {}
var _pool3d: Array = []
var _pool2d: Array = []
var _i3 := 0
var _i2 := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _last_play := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	Settings.apply_runtime()
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 4.0
		p.max_distance = 24.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in 6:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)

func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := "res://assets/audio/sfx/%s.wav" % name
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s

## pos == Vector3.ZERO plays non-positional (UI, own actions).
func play(name: String, pos := Vector3.ZERO, pitch := 1.0, vol_db := 0.0) -> void:
	if name == "clink":
		name = ["clink", "clink1", "clink2"][randi() % 3]
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, 0)) < 35:
		return
	_last_play[name] = now
	var s := _stream(name)
	if s == null:
		return
	if pos == Vector3.ZERO or get_viewport().get_camera_3d() == null:
		var p2: AudioStreamPlayer = _pool2d[_i2]
		_i2 = (_i2 + 1) % _pool2d.size()
		p2.stream = s
		p2.pitch_scale = pitch
		p2.volume_db = vol_db
		p2.play()
		return
	var p: AudioStreamPlayer3D = _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	p.stream = s
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = vol_db
	p.play()

func ui(name := "ui_tap") -> void:
	play(name)

func play_music(level_index_or_name) -> void:
	var name: String
	if typeof(level_index_or_name) == TYPE_STRING:
		name = level_index_or_name
	else:
		name = MUSIC[clampi(int(level_index_or_name), 0, MUSIC.size() - 1)]
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var path := "res://assets/audio/music/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	var s: AudioStreamWAV = load(path)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate) - 1
	_music.stream = s
	_music.volume_db = -4.0
	_music.play()

func stop_music() -> void:
	_music.stop()
	_music_name = ""
