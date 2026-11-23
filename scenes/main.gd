extends Node
## Root of the game: holds the 3D world, the menu backdrop and every UI screen.
## Screens are built from code (scripts/ui/*).

var world_holder: Node3D
var ui_layer: CanvasLayer
var root_ui: Control
var safe: MarginContainer
var screen_holder: Control
var overlay_holder: Control
var hud: Control
var touch: Control
var toasts: VBoxContainer
var loading: Control
var backdrop: Node3D
var fps_label: Label
var current: Control
var _pending_message := ""

func _ready() -> void:
	Game.main = self
	get_tree().root.content_scale_factor = 1.0
	world_holder = Node3D.new()
	world_holder.name = "World"
	add_child(world_holder)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = UIKit.get_theme()
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_ui)
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(safe)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(stack)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.visible = false
	stack.add_child(UIKit.full_rect(hud))
	touch = preload("res://scripts/ui/touch_controls.gd").new()
	touch.visible = false
	stack.add_child(UIKit.full_rect(touch))
	screen_holder = Control.new()
	screen_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(UIKit.full_rect(screen_holder))
	overlay_holder = Control.new()
	overlay_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(UIKit.full_rect(overlay_holder))
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-300, 120)
	toasts.custom_minimum_size = Vector2(600, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_child(toasts)
	fps_label = UIKit.label("", 24, Color.WHITE)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.position = Vector2(12, 4)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(fps_label)
	loading = preload("res://scripts/ui/loading.gd").new()
	loading.visible = false
	root_ui.add_child(UIKit.full_rect(loading))
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	Game.level_loaded.connect(_on_level_loaded)
	Game.load_progress.connect(_on_load_progress)
	Game.toast_requested.connect(toast)
	Game.results_ready.connect(_on_results)
	Net.host_left.connect(_on_host_left)
	backdrop = preload("res://scripts/ui/menu_backdrop.gd").new()
	world_holder.add_child(backdrop)
	Sfx.play_music("menu")
	go("menu")
	_handle_cmdline()

func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autostart="):
			start_solo(int(a.substr(12)))
		elif a.begins_with("--tri-count="):
			add_child(load("res://tests/tri_count.gd").new())
		elif a == "--ui-shots":
			add_child(load("res://tests/ui_shots.gd").new())
		elif a.begins_with("--dev-shots="):
			add_child(load("res://tests/dev_shots.gd").new())
		elif a == "--nettest-host" or a.begins_with("--nettest-client"):
			var nt = load("res://tests/net_test_driver.gd").new()
			nt.mode = a
			add_child(nt)

func _apply_safe_area() -> void:
	var sa := DisplayServer.get_display_safe_area()
	var ws := DisplayServer.window_get_size()
	var vs := get_viewport().get_visible_rect().size
	var m := {"left": 24.0, "right": 24.0, "top": 12.0, "bottom": 12.0}
	if ws.x > 0 and sa.size.x > 0 and OS.has_feature("mobile"):
		var sx := vs.x / ws.x
		var sy := vs.y / ws.y
		m.left = maxf(m.left, sa.position.x * sx)
		m.top = maxf(m.top, sa.position.y * sy)
		m.right = maxf(m.right, (ws.x - sa.end.x) * sx)
		m.bottom = maxf(m.bottom, (ws.y - sa.end.y) * sy)
	safe.add_theme_constant_override("margin_left", int(m.left))
	safe.add_theme_constant_override("margin_right", int(m.right))
	safe.add_theme_constant_override("margin_top", int(m.top))
	safe.add_theme_constant_override("margin_bottom", int(m.bottom))

func _process(_delta: float) -> void:
	fps_label.visible = Settings.get_value("show_fps")
	if fps_label.visible:
		var txt := "%d FPS" % Engine.get_frames_per_second()
		if Game.running and Game.world:
			txt += "  ·  %d draws  ·  %d bodies" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), Game.world.active_count()]
		fps_label.text = txt
	if Input.is_action_just_pressed("ui_fps"):
		Settings.set_value("show_fps", not Settings.get_value("show_fps"))

func _unhandled_input(event: InputEvent) -> void:
	if Game.running and not Game.ui_blocking and not DisplayServer.is_touchscreen_available():
		if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("pause") and Game.running:
		toggle_pause()

# ------------------------------------------------------------------ navigation
func go(name: String, arg = null) -> void:
	for c in screen_holder.get_children():
		c.queue_free()
	current = null
	var s: Control
	match name:
		"menu": s = preload("res://scripts/ui/main_menu.gd").new()
		"levels": s = preload("res://scripts/ui/level_select.gd").new()
		"join": s = preload("res://scripts/ui/join_menu.gd").new()
		"lobby": s = preload("res://scripts/ui/lobby.gd").new()
		"customize": s = preload("res://scripts/ui/customize.gd").new()
		"settings": s = preload("res://scripts/ui/settings_menu.gd").new()
		"credits": s = preload("res://scripts/ui/credits.gd").new()
		"none": return
	if s == null:
		return
	if arg != null and "arg" in s:
		s.arg = arg
	screen_holder.add_child(UIKit.full_rect(s))
	current = s
	if _pending_message != "":
		message(_pending_message)
		_pending_message = ""
	_pop_in(s)

func _pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.18)

func overlay(name: String, arg = null) -> Control:
	close_overlay()
	var s: Control
	match name:
		"pause": s = preload("res://scripts/ui/pause_menu.gd").new()
		"settings": s = preload("res://scripts/ui/settings_menu.gd").new()
		"results": s = preload("res://scripts/ui/results.gd").new()
		"emotes": s = preload("res://scripts/ui/emote_wheel.gd").new()
		"chat": s = preload("res://scripts/ui/emote_wheel.gd").new(); s.chat_mode = true
		"customize": s = preload("res://scripts/ui/customize.gd").new()
	if s == null:
		return null
	if arg != null and "arg" in s:
		s.arg = arg
	if "in_overlay" in s:
		s.in_overlay = true
	overlay_holder.add_child(UIKit.full_rect(s))
	Game.ui_blocking = name != "emotes" and name != "chat"
	if Game.ui_blocking:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pop_in(s)
	return s

func close_overlay() -> void:
	for c in overlay_holder.get_children():
		c.queue_free()
	Game.ui_blocking = false

func has_overlay() -> bool:
	return overlay_holder.get_child_count() > 0

func toggle_pause() -> void:
	if has_overlay():
		close_overlay()
	else:
		overlay("pause")

# ------------------------------------------------------------------ game flow
func start_solo(level_id: int, resume := false) -> void:
	Net.leave(false)
	_begin_loading()
	if resume:
		await Game.resume(level_id)
	else:
		await Game.host_start_level(level_id)

func host_start(level_id: int, resume := false) -> void:
	_begin_loading()
	if resume:
		await Game.resume(level_id)
	else:
		await Game.host_start_level(level_id)

func _begin_loading() -> void:
	go("none")
	for c in screen_holder.get_children():
		c.queue_free()
	close_overlay()
	loading.show_tip(Levels.get_def(Net.lobby_level).get("tip", ""))
	loading.visible = true

func _on_load_progress(frac: float, text: String) -> void:
	if not loading.visible:
		for c in screen_holder.get_children():
			c.queue_free()
		close_overlay()
		loading.visible = true
	loading.set_progress(frac, text)

func _on_level_loaded() -> void:
	loading.visible = false
	if backdrop:
		backdrop.queue_free()
		backdrop = null
	hud.visible = true
	hud.on_level_start()
	touch.visible = touch.should_show()
	for c in screen_holder.get_children():
		c.queue_free()
	if Game.level_def.id == 1 and not Profile.completed.has(1):
		hud.show_tutorial()

func _on_results(data: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay("results", data)
	Game.delete_save(data.level.id)

func leave_to_menu(msg := "") -> void:
	close_overlay()
	Net.leave(false)
	Game.unload_level()
	hud.visible = false
	touch.visible = false
	loading.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if backdrop == null:
		backdrop = preload("res://scripts/ui/menu_backdrop.gd").new()
		world_holder.add_child(backdrop)
	Sfx.play_music("menu")
	_pending_message = msg
	go("menu")

func _on_host_left(reason: String) -> void:
	leave_to_menu(reason)

# ------------------------------------------------------------------ toasts / dialogs
func toast(text: String) -> void:
	var p := UIKit.panel(Color(0.16, 0.12, 0.24, 0.88))
	var l := UIKit.label(text, 30, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	while toasts.get_child_count() > 3:
		toasts.get_child(0).queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func message(text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	root_ui.add_child(UIKit.full_rect(dim))
	var p := UIKit.panel()
	var v := UIKit.vbox(20)
	p.add_child(v)
	v.add_child(UIKit.label(text, 34, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.button("OK", UIKit.TEAL, func(): dim.queue_free()))
	p.custom_minimum_size = Vector2(760, 0)
	dim.add_child(UIKit.center(p))
