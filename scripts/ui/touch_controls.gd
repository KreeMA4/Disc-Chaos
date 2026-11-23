extends Control
## Multi-touch controls: floating left joystick, drag-anywhere-right to look, and big round
## buttons with contextual labels. Layout, size and opacity are adjustable (edit mode).

const DEFAULTS := {
	"grab": Vector2(0.885, 0.73), "jump": Vector2(0.955, 0.50), "interact": Vector2(0.77, 0.86),
	"throw": Vector2(0.765, 0.60), "inspect": Vector2(0.665, 0.88), "crouch": Vector2(0.955, 0.90),
	"sprint": Vector2(0.075, 0.46), "scanner": Vector2(0.905, 0.07), "emote": Vector2(0.785, 0.07),
	"chat": Vector2(0.845, 0.07), "pause": Vector2(0.965, 0.07), "flashlight": Vector2(0.725, 0.07),
}
const RADIUS := {"grab": 92.0, "jump": 64.0, "interact": 70.0, "throw": 60.0, "inspect": 54.0, "crouch": 50.0,
	"sprint": 56.0, "scanner": 44.0, "emote": 44.0, "chat": 44.0, "pause": 44.0, "flashlight": 44.0}
const COLORS := {"grab": Color(1.0, 0.6, 0.25), "jump": Color(0.35, 0.75, 1.0), "interact": Color(0.3, 0.8, 0.6),
	"throw": Color(1.0, 0.45, 0.55), "inspect": Color(0.65, 0.5, 0.95), "crouch": Color(0.6, 0.6, 0.7),
	"sprint": Color(1.0, 0.8, 0.3), "scanner": Color(0.35, 0.9, 0.5), "emote": Color(1.0, 0.7, 0.3),
	"chat": Color(0.5, 0.7, 1.0), "pause": Color(0.55, 0.55, 0.65), "flashlight": Color(1.0, 0.95, 0.6)}

var editing := false
var touches := {}          # index -> {role, start, pos, btn}
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_active := false
var sprint_on := false
var pressed := {}          # btn -> true
var _drag_btn := ""

func should_show() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _btn_ids() -> Array:
	var ids := DEFAULTS.keys()
	if not Game.level_def.get("flashlight", false):
		ids.erase("flashlight")
	return ids

func btn_pos(id: String) -> Vector2:
	var lay: Dictionary = Settings.get_value("touch_layout")
	var n: Vector2 = lay.get(id, DEFAULTS[id])
	return n * size

func btn_r(id: String) -> float:
	return RADIUS[id] * float(Settings.get_value("button_scale"))

func _hit_button(p: Vector2) -> String:
	for id in _btn_ids():
		if p.distance_to(btn_pos(id)) <= btn_r(id) * 1.15:
			return id
	return ""

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if Game.main and Game.main.has_overlay() and not editing:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position - global_position
		if event.pressed:
			var b := _hit_button(p)
			if editing:
				_drag_btn = b
				touches[event.index] = {"role": "edit", "pos": p}
				return
			if b != "":
				touches[event.index] = {"role": "btn", "btn": b}
				_press(b)
			elif p.x < size.x * 0.42:
				touches[event.index] = {"role": "joy"}
				joy_origin = p
				joy_pos = p
				joy_active = true
			else:
				touches[event.index] = {"role": "look", "pos": p}
			get_viewport().set_input_as_handled()
		else:
			var t: Dictionary = touches.get(event.index, {})
			match t.get("role", ""):
				"btn": _release(t.btn)
				"joy":
					joy_active = false
					if Game.local_player:
						Game.local_player.touch_move = Vector2.ZERO
				"edit":
					if _drag_btn != "":
						_save_btn(_drag_btn, btn_pos(_drag_btn))
					_drag_btn = ""
			touches.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var t2: Dictionary = touches.get(event.index, {})
		var p2: Vector2 = event.position - global_position
		match t2.get("role", ""):
			"joy":
				joy_pos = p2
				var d := (joy_pos - joy_origin)
				var maxr := 110.0 * float(Settings.get_value("button_scale"))
				if d.length() > maxr:
					joy_origin += d - d.normalized() * maxr
					d = d.normalized() * maxr
				if Game.local_player:
					Game.local_player.touch_move = d / maxr
			"look":
				if Game.local_player:
					Game.local_player.add_look(event.relative * 1.25)
			"edit":
				if _drag_btn != "":
					var lay: Dictionary = (Settings.get_value("touch_layout") as Dictionary).duplicate()
					lay[_drag_btn] = Vector2(clampf(p2.x / size.x, 0.03, 0.97), clampf(p2.y / size.y, 0.04, 0.96))
					Settings.values["touch_layout"] = lay
		get_viewport().set_input_as_handled()
		queue_redraw()

func _save_btn(id: String, _pos: Vector2) -> void:
	Settings.set_value("touch_layout", Settings.get_value("touch_layout"))

func _press(b: String) -> void:
	pressed[b] = true
	if Settings.get_value("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(10)
	match b:
		"sprint":
			sprint_on = not sprint_on
			if sprint_on:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")
		"pause":
			Game.main.toggle_pause()
		"emote":
			Game.main.overlay("emotes")
		"chat":
			Game.main.overlay("chat")
		"crouch":
			Input.action_press("crouch")
		_:
			Input.action_press(b)

func _release(b: String) -> void:
	pressed.erase(b)
	match b:
		"sprint", "pause", "emote", "chat":
			pass
		_:
			Input.action_release(b)

func _process(_d: float) -> void:
	if visible:
		queue_redraw()
	if sprint_on and Game.local_player and Game.local_player.touch_move.length() < 0.05 and not joy_active:
		pass

func _draw() -> void:
	var op := float(Settings.get_value("button_opacity"))
	if joy_active:
		draw_circle(joy_origin, 110.0 * float(Settings.get_value("button_scale")), Color(1, 1, 1, 0.12 * op + 0.05))
		draw_arc(joy_origin, 110.0 * float(Settings.get_value("button_scale")), 0, TAU, 40, Color(1, 1, 1, 0.5 * op), 4.0, true)
		draw_circle(joy_pos, 46.0, Color(1, 1, 1, 0.55 * op + 0.2))
	elif not editing:
		var hint := Vector2(size.x * 0.16, size.y * 0.74)
		draw_arc(hint, 80.0, 0, TAU, 40, Color(1, 1, 1, 0.18 * op), 3.0, true)
	var ctx: Dictionary = Game.local_player.context() if Game.local_player else {}
	for id in _btn_ids():
		var c := btn_pos(id)
		var r := btn_r(id)
		var col: Color = COLORS[id]
		var active = pressed.has(id) or (id == "sprint" and sprint_on) or (id == "scanner" and Game.scanner_active())
		var a := op * (1.0 if not active else 1.0)
		var label := ""
		if id == "grab":
			label = String(ctx.get("grab", ""))
			if label == "":
				a *= 0.55
		elif id == "interact":
			label = String(ctx.get("interact", ""))
			if label == "":
				a *= 0.45
		if id == "scanner" and Game.scanner_cd > 0.0 and not Settings.get_value("casual_scanner"):
			a *= 0.5
		var press_off := Vector2(0, 4) if active else Vector2.ZERO
		draw_circle(c + Vector2(0, 6), r, Color(0.1, 0.05, 0.15, 0.35 * a))
		draw_circle(c + press_off, r, Color(col.darkened(0.15) if active else col, 0.85 * a))
		draw_arc(c + press_off, r - 3, 0, TAU, 40, Color(1, 1, 1, 0.9 * a), 5.0, true)
		_icon(id, c + press_off + (Vector2(0, -r * 0.18) if label != "" else Vector2.ZERO), r * (0.5 if label != "" else 0.62), Color(1, 1, 1, a))
		if label != "":
			var f: Font = Covers.fonts.get("lilita-one")
			var fs := int(r * 0.34)
			draw_string_outline(f, c + press_off + Vector2(-r, r * 0.48), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 6, Color(0.1, 0.05, 0.15, a))
			draw_string(f, c + press_off + Vector2(-r, r * 0.48), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, a))
		if id == "throw" and Game.local_player and Game.local_player.throw_charge >= 0.0:
			draw_arc(c, r + 10, -PI / 2, -PI / 2 + TAU * Game.local_player.throw_charge, 32, Color(1, 0.9, 0.3), 8.0, true)
		if id == "scanner" and Game.scanner_cd > 0.0 and not Settings.get_value("casual_scanner"):
			draw_arc(c, r + 6, -PI / 2, -PI / 2 + TAU * (1.0 - Game.scanner_cd / Game.SCANNER_COOLDOWN), 32, Color(0.4, 1.0, 0.5, 0.9), 6.0, true)
	if editing:
		var f2: Font = Covers.fonts.get("lilita-one")
		draw_string_outline(f2, Vector2(0, size.y * 0.5), "Drag buttons to move them. Tap DONE when finished.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 10, UIKit.INK)
		draw_string(f2, Vector2(0, size.y * 0.5), "Drag buttons to move them. Tap DONE when finished.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color.WHITE)

func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(3.0, s * 0.16)
	match id:
		"grab":
			draw_circle(c + Vector2(0, s * 0.15), s * 0.42, col)
			for i in 4:
				draw_circle(c + Vector2(-s * 0.36 + i * s * 0.24, -s * 0.32), s * 0.14, col)
			draw_circle(c + Vector2(-s * 0.5, s * 0.08), s * 0.15, col)
		"jump":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(s * 0.55, 0), c + Vector2(-s * 0.55, 0)]), col)
			draw_rect(Rect2(c + Vector2(-s * 0.2, 0), Vector2(s * 0.4, s * 0.5)), col)
		"throw":
			draw_arc(c + Vector2(0, s * 0.3), s * 0.55, PI * 1.1, PI * 1.9, 16, col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.45, -s * 0.45), c + Vector2(s * 0.6, s * 0.05), c + Vector2(s * 0.1, -s * 0.15)]), col)
		"inspect":
			draw_arc(c + Vector2(-s * 0.1, -s * 0.1), s * 0.38, 0, TAU, 24, col, w, true)
			draw_line(c + Vector2(s * 0.18, s * 0.18), c + Vector2(s * 0.5, s * 0.5), col, w * 1.3)
		"interact":
			draw_arc(c, s * 0.42, 0, TAU, 24, col, w, true)
			draw_circle(c, s * 0.16, col)
		"crouch":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.15), c + Vector2(0, s * 0.3), c + Vector2(s * 0.45, -s * 0.15)]), col, w * 1.3)
		"sprint":
			for k in 2:
				var o := Vector2(-s * 0.2 + k * s * 0.35, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.2, -s * 0.4), c + o + Vector2(s * 0.15, 0), c + o + Vector2(-s * 0.2, s * 0.4)]), col, w * 1.2)
		"scanner":
			for k in 3:
				draw_arc(c + Vector2(0, s * 0.35), s * (0.25 + k * 0.25), PI * 1.2, PI * 1.8, 12, col, w * 0.8, true)
			draw_circle(c + Vector2(0, s * 0.35), s * 0.1, col)
		"emote":
			draw_arc(c, s * 0.5, 0, TAU, 24, col, w, true)
			draw_circle(c + Vector2(-s * 0.18, -s * 0.12), s * 0.07, col)
			draw_circle(c + Vector2(s * 0.18, -s * 0.12), s * 0.07, col)
			draw_arc(c + Vector2(0, s * 0.02), s * 0.25, 0.3, PI - 0.3, 10, col, w * 0.8, true)
		"chat":
			draw_rect(Rect2(c - Vector2(s * 0.5, s * 0.35), Vector2(s, s * 0.55)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.2), c + Vector2(-s * 0.35, s * 0.5), c + Vector2(0, s * 0.2)]), col)
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.4), Vector2(s * 0.2, s * 0.8)), col)
			draw_rect(Rect2(c + Vector2(s * 0.1, -s * 0.4), Vector2(s * 0.2, s * 0.8)), col)
		"flashlight":
			draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.12), Vector2(s * 0.5, s * 0.24)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.25), c + Vector2(s * 0.55, -s * 0.5), c + Vector2(s * 0.55, s * 0.5), c + Vector2(0, s * 0.25)]), col)
