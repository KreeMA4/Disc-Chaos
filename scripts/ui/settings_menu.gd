extends ColorRect
## Settings: graphics presets, render scale, FPS cap & counter, audio, controls, touch layout.
var in_overlay := false
var body: VBoxContainer
var tab := 0

func _ready() -> void:
	color = Color(0.1, 0.05, 0.15, 0.55) if in_overlay else Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1400, 860)
	var v := UIKit.vbox(14)
	p.add_child(v)
	var top := UIKit.hbox(12)
	var t := UIKit.label("Settings", 52, UIKit.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	for i in 4:
		var name: String = ["Graphics", "Audio", "Controls", "Gameplay"][i]
		top.add_child(UIKit.button(name, UIKit.TEAL if i == tab else UIKit.GREY, func():
			tab = i
			_rebuild_tabs(top)
			_build(), 28, 70))
	v.add_child(top)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	body = UIKit.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	v.add_child(UIKit.button("Done", UIKit.ORANGE, func(): _close()))
	add_child(UIKit.center(p))
	_build()

func _rebuild_tabs(top: HBoxContainer) -> void:
	for i in 4:
		var b: Button = top.get_child(i + 1)
		var c := UIKit.TEAL if i == tab else UIKit.GREY
		b.add_theme_stylebox_override("normal", UIKit.box(c, 22, 6))
		b.add_theme_stylebox_override("hover", UIKit.box(c.lightened(0.08), 22, 6))

func _close() -> void:
	if in_overlay:
		Game.main.close_overlay()
		Game.main.overlay("pause")
	else:
		Game.main.go("menu")

func _build() -> void:
	for c in body.get_children():
		c.queue_free()
	match tab:
		0:
			body.add_child(UIKit.choice_row("Quality preset", Settings.PRESETS, int(Settings.get_value("preset")), func(i):
				Settings.set_value("preset", i)
				_build()))
			body.add_child(UIKit.label("Low: no shadows/glow, 30 FPS-friendly · Medium: soft shadows · High: outlines + MSAA · Ultra: big shadow maps, longer draw distance. Changing presets fully applies on the next level load.", 22, UIKit.GREY.darkened(0.35)))
			body.add_child(UIKit.slider_row("Render scale", 0.5, 1.0, 0.05, float(Settings.get_value("render_scale")), func(x): Settings.set_value("render_scale", x), "%.2f"))
			var caps := [30, 60, 120]
			body.add_child(UIKit.choice_row("FPS cap", ["30", "60", "120"], maxi(0, caps.find(int(Settings.get_value("fps_cap")))), func(i): Settings.set_value("fps_cap", caps[i])))
			body.add_child(UIKit.toggle_row("Show FPS counter", Settings.get_value("show_fps"), func(on): Settings.set_value("show_fps", on)))
			body.add_child(UIKit.slider_row("Field of view", 60, 100, 1, float(Settings.get_value("fov")), func(x): Settings.set_value("fov", x), "%d°"))
			body.add_child(UIKit.toggle_row("Head bob", Settings.get_value("head_bob"), func(on): Settings.set_value("head_bob", on)))
		1:
			body.add_child(UIKit.slider_row("Master volume", 0, 1, 0.05, float(Settings.get_value("vol_master")), func(x): Settings.set_value("vol_master", x), "%.2f"))
			body.add_child(UIKit.slider_row("Music", 0, 1, 0.05, float(Settings.get_value("vol_music")), func(x): Settings.set_value("vol_music", x), "%.2f"))
			body.add_child(UIKit.slider_row("Sound effects", 0, 1, 0.05, float(Settings.get_value("vol_sfx")), func(x):
				Settings.set_value("vol_sfx", x)
				Sfx.play("click"), "%.2f"))
		2:
			body.add_child(UIKit.slider_row("Look sensitivity", 0.2, 3.0, 0.05, float(Settings.get_value("look_sens")), func(x): Settings.set_value("look_sens", x), "%.2f"))
			body.add_child(UIKit.toggle_row("Invert Y", Settings.get_value("invert_y"), func(on): Settings.set_value("invert_y", on)))
			body.add_child(UIKit.toggle_row("Haptics (vibration)", Settings.get_value("haptics"), func(on): Settings.set_value("haptics", on)))
			body.add_child(UIKit.slider_row("Button size", 0.6, 1.6, 0.05, float(Settings.get_value("button_scale")), func(x): Settings.set_value("button_scale", x), "%.2f"))
			body.add_child(UIKit.slider_row("Button opacity", 0.2, 1.0, 0.05, float(Settings.get_value("button_opacity")), func(x): Settings.set_value("button_opacity", x), "%.2f"))
			var row := UIKit.hbox()
			row.add_child(UIKit.button("Edit button layout", UIKit.BLUE, func(): _edit_layout(), 28, 72))
			row.add_child(UIKit.button("Reset layout", UIKit.GREY, func(): Settings.set_value("touch_layout", {}), 28, 72))
			body.add_child(row)
			body.add_child(UIKit.label("Keyboard: WASD move · Mouse look · Shift sprint · Ctrl/C crouch · Space jump · E / LMB grab · F interact · Q / RMB throw (hold to charge) · R inspect · G drop · Tab scanner · T emotes · Y chat · L flashlight · Esc pause · F3 FPS\nGamepad: sticks move/look · A jump · X / RT grab · Y interact · RB throw · LT / R3 inspect · B crouch · L3 sprint · LB scanner · D-pad emotes/chat/flashlight/drop · Start pause", 22, UIKit.GREY.darkened(0.4)))
		3:
			body.add_child(UIKit.toggle_row("Casual mode (scanner always on)", Settings.get_value("casual_scanner"), func(on): Settings.set_value("casual_scanner", on)))
			body.add_child(UIKit.toggle_row("Ragdoll slips", Settings.get_value("ragdoll"), func(on): Settings.set_value("ragdoll", on)))
			body.add_child(UIKit.toggle_row("Unlock all levels", Settings.get_value("unlock_all"), func(on): Settings.set_value("unlock_all", on)))
			var nr := UIKit.hbox()
			nr.add_child(UIKit.label("Clear cover-art cache", 28))
			nr.add_child(UIKit.button("Clear", UIKit.RED, func():
				var d := DirAccess.open("user://covercache")
				if d:
					for f in d.get_files():
						d.remove(f)
				Game.toast("Cover cache cleared"), 26, 64))
			body.add_child(nr)

func _edit_layout() -> void:
	var touch = Game.main.touch
	var was = touch.visible
	touch.visible = true
	touch.editing = true
	visible = false
	var done := UIKit.button("DONE", UIKit.GREEN, Callable(), 36, 90)
	done.set_anchors_preset(Control.PRESET_CENTER_TOP)
	done.position = Vector2(-120, 140)
	done.custom_minimum_size = Vector2(240, 90)
	Game.main.root_ui.add_child(done)
	done.pressed.connect(func():
		touch.editing = false
		touch.visible = was
		visible = true
		Settings.set_value("touch_layout", Settings.get_value("touch_layout"))
		done.queue_free())
