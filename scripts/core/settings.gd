extends Node
## Persistent settings (user://settings.cfg), graphics presets and the input map.

signal changed(key: String)

const PATH := "user://settings.cfg"
const PRESETS := ["Low", "Medium", "High", "Ultra"]

const DEFAULTS := {
	"preset": 2,                # High
	"render_scale": 1.0,
	"fps_cap": 60,
	"show_fps": false,
	"vol_master": 0.9,
	"vol_music": 0.55,
	"vol_sfx": 0.9,
	"look_sens": 1.0,
	"invert_y": false,
	"fov": 78.0,
	"haptics": true,
	"button_scale": 1.0,
	"button_opacity": 0.75,
	"touch_layout": {},         # button id -> Vector2 (normalized position)
	"ragdoll": true,
	"casual_scanner": false,
	"head_bob": true,
	"last_ip": "",
	"last_code": "",
	"warehouse_items": 400,
	"dev_no_cover_cache": false,
}

var values := {}

## Preset table: what each graphics preset turns on.
const PRESET_DATA := [
	{"scale": 0.67, "shadows": false, "shadow_size": 1024, "outlines": false, "glow": false, "msaa": 0, "fxaa": true, "lights": 2, "detail": 0.5, "vis_mult": 0.6, "fps": 30, "mirror": false},
	{"scale": 0.8, "shadows": true, "shadow_size": 1024, "outlines": false, "glow": true, "msaa": 0, "fxaa": true, "lights": 4, "detail": 0.75, "vis_mult": 0.8, "fps": 60, "mirror": true},
	{"scale": 1.0, "shadows": true, "shadow_size": 2048, "outlines": true, "glow": true, "msaa": 1, "fxaa": false, "lights": 6, "detail": 1.0, "vis_mult": 1.0, "fps": 60, "mirror": true},
	{"scale": 1.0, "shadows": true, "shadow_size": 4096, "outlines": true, "glow": true, "msaa": 2, "fxaa": false, "lights": 8, "detail": 1.0, "vis_mult": 1.35, "fps": 60, "mirror": true},
]

func _ready() -> void:
	load_settings()
	_setup_input()
	apply_runtime()

func get_value(key: String, def = null):
	if values.has(key):
		return values[key]
	return DEFAULTS.get(key, def)

func set_value(key: String, v) -> void:
	values[key] = v
	if key == "preset":
		var pd: Dictionary = PRESET_DATA[int(v)]
		values["render_scale"] = pd.scale
	save_settings()
	apply_runtime()
	changed.emit(key)

func preset() -> Dictionary:
	return PRESET_DATA[clampi(int(get_value("preset")), 0, 3)]

func load_settings() -> void:
	values = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in cf.get_section_keys("s"):
			values[k] = cf.get_value("s", k)
	elif OS.has_feature("mobile"):
		values["preset"] = 2

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("s", k, values[k])
	cf.save(PATH)

func apply_runtime() -> void:
	Engine.max_fps = int(get_value("fps_cap"))
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, float(get_value("vol_master")))))
	for b in ["Music", "SFX"]:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, float(get_value("vol_" + b.to_lower())))))
	var vp := get_viewport()
	if vp:
		var pd := preset()
		vp.scaling_3d_scale = clampf(float(get_value("render_scale")), 0.4, 1.0)
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if vp.scaling_3d_scale < 0.95 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(pd.msaa)]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if pd.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
		RenderingServer.directional_shadow_atlas_set_size(int(pd.shadow_size), true)

# ------------------------------------------------------------------ input map
const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "grab": [KEY_E], "throw": [KEY_Q],
	"interact": [KEY_F], "inspect": [KEY_R], "scanner": [KEY_TAB], "emote": [KEY_T], "chat": [KEY_Y],
	"pause": [KEY_ESCAPE], "flashlight": [KEY_L], "drop": [KEY_G], "ui_fps": [KEY_F3],
}
const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A], "grab": [JOY_BUTTON_X], "interact": [JOY_BUTTON_Y], "crouch": [JOY_BUTTON_B],
	"sprint": [JOY_BUTTON_LEFT_STICK], "inspect": [JOY_BUTTON_RIGHT_STICK], "scanner": [JOY_BUTTON_LEFT_SHOULDER],
	"throw": [JOY_BUTTON_RIGHT_SHOULDER], "emote": [JOY_BUTTON_DPAD_UP], "chat": [JOY_BUTTON_DPAD_DOWN],
	"flashlight": [JOY_BUTTON_DPAD_LEFT], "drop": [JOY_BUTTON_DPAD_RIGHT], "pause": [JOY_BUTTON_START],
}

func _setup_input() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in PAD_BUTTONS:
		for b in PAD_BUTTONS[a]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(a, ev)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.15)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	# triggers: right = grab alternative, left = throw alternative
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("grab", rt)
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	InputMap.action_add_event("inspect", lt)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("grab", mb)
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("throw", mr)
	var mm := InputEventMouseButton.new()
	mm.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event("inspect", mm)

func _axis(action: String, axis: int, v: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = v
	InputMap.action_add_event(action, ev)
