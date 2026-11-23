extends ColorRect
## Bean customization: colors, patterns, eyes, hats, glasses, shirts, backpacks, gloves, scarves,
## capes. Big RANDOMIZE with an animation, per-category dice, nickname. Saved + synced.
var arg = null
var in_overlay := false
var preview: BeanPreview
var grid: GridContainer
var cat := "color"
var name_edit: LineEdit
var tabs: HBoxContainer

func _ready() -> void:
	color = Color(0.1, 0.05, 0.15, 0.55) if in_overlay else Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1700, 880)
	var h := UIKit.hbox(24)
	p.add_child(h)
	var left := UIKit.vbox(12)
	left.custom_minimum_size = Vector2(560, 0)
	h.add_child(left)
	preview = BeanPreview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(540, 520)
	left.add_child(preview)
	name_edit = LineEdit.new()
	name_edit.text = Profile.nickname
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(0, 76)
	name_edit.text_changed.connect(func(t):
		Profile.nickname = t.strip_edges() if t.strip_edges() != "" else Profile.nickname
		Profile.save_profile()
		_update_preview())
	left.add_child(name_edit)
	var rb := UIKit.button("RANDOMIZE!", UIKit.PINK, func(): _randomize_all(), 44, 110)
	left.add_child(rb)
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var tsc := ScrollContainer.new()
	tsc.custom_minimum_size = Vector2(0, 96)
	tsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.add_child(tabs)
	right.add_child(tsc)
	var cats: Array = ["color"] + Profile.CATEGORIES
	for c in cats:
		var b := UIKit.button(String(c).capitalize(), UIKit.TEAL if c == cat else UIKit.GREY, Callable(), 26, 76)
		b.pressed.connect(func():
			Sfx.ui()
			cat = c
			_build_tabs()
			_build_grid())
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.button("Shuffle category", UIKit.PURPLE, func(): _randomize_cat(), 28, 80))
	var done := UIKit.button("Done", UIKit.ORANGE, func(): _close(), 34, 80)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(done)
	right.add_child(row)
	add_child(UIKit.center(p))
	await get_tree().process_frame
	_update_preview()
	_build_grid()

func _close() -> void:
	Net.push_look()
	if Game.local_player:
		Game.local_player.refresh_look()
	if Game.main.backdrop:
		Game.main.backdrop.refresh_bean()
	if in_overlay:
		Game.main.close_overlay()
		Game.main.overlay("pause")
	elif arg == "lobby":
		Game.main.go("lobby")
	else:
		Game.main.go("menu")

func _build_tabs() -> void:
	var cats: Array = ["color"] + Profile.CATEGORIES
	for i in tabs.get_child_count():
		var b: Button = tabs.get_child(i)
		var c := UIKit.TEAL if cats[i] == cat else UIKit.GREY
		b.add_theme_stylebox_override("normal", UIKit.box(c, 22, 6))
		b.add_theme_stylebox_override("hover", UIKit.box(c.lightened(0.08), 22, 6))

func _update_preview() -> void:
	if preview and preview.vp:
		preview.set_beans([Profile.net_look()])

func _build_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	if cat == "color":
		grid.columns = 6
		for col in Profile.BODY_COLORS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(120, 100)
			var sel: bool = Profile.look.color is Color and (Profile.look.color as Color).is_equal_approx(col)
			b.add_theme_stylebox_override("normal", UIKit.box(col, 26, 6, 0, UIKit.INK if sel else Color(0, 0, 0, 0)))
			b.add_theme_stylebox_override("hover", UIKit.box(col.lightened(0.1), 26, 6))
			b.add_theme_stylebox_override("pressed", UIKit.box(col.darkened(0.1), 26, 2, 4))
			b.pressed.connect(func():
				Sfx.ui()
				Profile.set_look("color", col)
				_update_preview()
				_build_grid())
			grid.add_child(b)
		var cp := ColorPickerButton.new()
		cp.color = Profile.look.color if Profile.look.color is Color else Color.WHITE
		cp.custom_minimum_size = Vector2(240, 100)
		cp.text = "Custom"
		cp.edit_alpha = false
		cp.color_changed.connect(func(c):
			Profile.set_look("color", c)
			_update_preview())
		grid.add_child(cp)
		return
	grid.columns = 4
	var opts: Array = Profile.COSMETICS[cat]
	for i in opts.size():
		var unlocked := Profile.is_unlocked(cat, i)
		var selected := int(Profile.look.get(cat, 0)) == i
		var text: String = opts[i] if unlocked else "%s\n(%d stars)" % [opts[i], Profile.stars_needed(cat, i)]
		var b := UIKit.button(text, (UIKit.ORANGE if selected else UIKit.BLUE) if unlocked else UIKit.GREY, Callable(), 26, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not unlocked
		b.pressed.connect(func():
			Sfx.ui()
			Profile.set_look(cat, i)
			_update_preview()
			_build_grid())
		grid.add_child(b)

func _randomize_cat() -> void:
	Profile.randomize_look(cat)
	Sfx.play("randomize")
	_update_preview()
	_build_grid()
	if preview:
		preview.celebrate()

func _randomize_all() -> void:
	Sfx.play("randomize")
	for i in 7:
		Profile.randomize_look()
		_update_preview()
		await get_tree().create_timer(0.11).timeout
	Profile.randomize_look()
	Profile.nickname = Profile.NAME_A[randi() % Profile.NAME_A.size()] + " " + Profile.NAME_B[randi() % Profile.NAME_B.size()] if randf() < 0.3 else Profile.nickname
	Profile.save_profile()
	name_edit.text = Profile.nickname
	_update_preview()
	_build_grid()
	await get_tree().process_frame
	preview.celebrate()
	_confetti()

func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 80
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70
	p.initial_velocity_min = 500
	p.initial_velocity_max = 900
	p.gravity = Vector2(0, 1400)
	p.scale_amount_min = 8
	p.scale_amount_max = 14
	var g := Gradient.new()
	g.colors = PackedColorArray([UIKit.PINK, UIKit.YELLOW, UIKit.TEAL, UIKit.BLUE, UIKit.ORANGE])
	g.offsets = PackedFloat32Array([0, 0.25, 0.5, 0.75, 1.0])
	p.color_initial_ramp = g
	add_child(p)
	p.position = Vector2(get_viewport_rect().size.x * 0.25, get_viewport_rect().size.y * 0.7)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
