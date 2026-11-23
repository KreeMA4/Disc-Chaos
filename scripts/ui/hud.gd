extends Control
## In-level HUD: progress, timer, section bars, crosshair & target info, inspect card, chat feed.

var top_panel: PanelContainer
var level_lbl: Label
var prog_bar: ProgressBar
var prog_lbl: Label
var time_lbl: Label
var sections_box: VBoxContainer
var cross: Control
var target_lbl: Label
var detail_lbl: Label
var hint_lbl: Label
var inspect_card: PanelContainer
var inspect_title: Label
var inspect_info: Label
var chat_feed: VBoxContainer
var scanner_chip: Label
var tutorial: PanelContainer
var _sec_bars := {}
var _show_sections := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel = UIKit.panel(Color(1, 0.97, 0.9, 0.92))
	top_panel.position = Vector2(0, 0)
	top_panel.custom_minimum_size = Vector2(460, 0)
	top_panel.add_theme_stylebox_override("panel", _small_panel())
	add_child(top_panel)
	var v := UIKit.vbox(6)
	top_panel.add_child(v)
	var row := UIKit.hbox(10)
	level_lbl = UIKit.label("", 26, UIKit.INK, true)
	level_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(level_lbl)
	time_lbl = UIKit.label("0:00", 26, UIKit.INK, true)
	row.add_child(time_lbl)
	v.add_child(row)
	prog_bar = ProgressBar.new()
	prog_bar.custom_minimum_size = Vector2(420, 26)
	prog_bar.max_value = 1.0
	v.add_child(prog_bar)
	prog_lbl = UIKit.label("", 22, UIKit.INK)
	v.add_child(prog_lbl)
	sections_box = UIKit.vbox(4)
	v.add_child(sections_box)
	top_panel.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_show_sections = not _show_sections
			sections_box.visible = _show_sections)
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	scanner_chip = UIKit.label("", 24, Color.WHITE, true)
	scanner_chip.add_theme_color_override("font_outline_color", UIKit.INK)
	scanner_chip.add_theme_constant_override("outline_size", 8)
	scanner_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	scanner_chip.position = Vector2(-200, 6)
	scanner_chip.custom_minimum_size = Vector2(400, 0)
	scanner_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(scanner_chip)
	cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.custom_minimum_size = Vector2(30, 30)
	cross.position = Vector2(-15, -15)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	add_child(cross)
	target_lbl = _outlined(34)
	target_lbl.set_anchors_preset(Control.PRESET_CENTER)
	target_lbl.position = Vector2(-450, 40)
	target_lbl.custom_minimum_size = Vector2(900, 0)
	add_child(target_lbl)
	detail_lbl = _outlined(24)
	detail_lbl.set_anchors_preset(Control.PRESET_CENTER)
	detail_lbl.position = Vector2(-450, 86)
	detail_lbl.custom_minimum_size = Vector2(900, 0)
	add_child(detail_lbl)
	hint_lbl = _outlined(26)
	hint_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_lbl.position = Vector2(-450, -230)
	hint_lbl.custom_minimum_size = Vector2(900, 0)
	add_child(hint_lbl)
	inspect_card = UIKit.panel()
	inspect_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	inspect_card.position = Vector2(-520, -200)
	inspect_card.custom_minimum_size = Vector2(500, 0)
	var iv := UIKit.vbox(8)
	inspect_card.add_child(iv)
	inspect_title = UIKit.label("", 36, UIKit.INK, true)
	inspect_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_title.custom_minimum_size = Vector2(440, 0)
	iv.add_child(inspect_title)
	inspect_info = UIKit.label("", 26, UIKit.INK)
	iv.add_child(inspect_info)
	iv.add_child(UIKit.label("Drag to rotate · Interact to flip", 22, UIKit.GREY.darkened(0.3)))
	inspect_card.visible = false
	inspect_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inspect_card)
	chat_feed = UIKit.vbox(4)
	chat_feed.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_feed.position = Vector2(10, -520)
	chat_feed.custom_minimum_size = Vector2(600, 0)
	chat_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chat_feed)
	Game.progress_changed.connect(_refresh_progress)
	Game.chat_received.connect(_on_chat)

func _small_panel() -> StyleBoxFlat:
	var s := UIKit.panel_box(Color(1, 0.97, 0.9, 0.92))
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 16
	s.set_corner_radius_all(24)
	return s

func _outlined(size: int) -> Label:
	var l := UIKit.label("", size, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", UIKit.INK)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func on_level_start() -> void:
	level_lbl.text = Game.level_def.name
	for c in sections_box.get_children():
		c.queue_free()
	_sec_bars.clear()
	for s in Game.st.sections:
		var h := UIKit.hbox(8)
		var dot := ColorRect.new()
		dot.color = s.color
		dot.custom_minimum_size = Vector2(16, 16)
		h.add_child(dot)
		var l := UIKit.label(s.label, 20, UIKit.INK)
		l.custom_minimum_size = Vector2(220, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		h.add_child(l)
		var b := ProgressBar.new()
		b.custom_minimum_size = Vector2(150, 16)
		b.max_value = 1.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fill := UIKit.box(s.color.lightened(0.1), 8, 0)
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		b.add_theme_stylebox_override("fill", fill)
		h.add_child(b)
		sections_box.add_child(h)
		_sec_bars[s.id] = b
	_refresh_progress()

func _refresh_progress() -> void:
	if Game.st == null:
		return
	prog_bar.value = Game.st.progress()
	var hidden := Game.hidden_count()
	prog_lbl.text = "%s sorted  ·  %d%%%s" % [Game.progress_text(), int(Game.st.progress() * 100.0), ("  ·  %d hidden" % hidden) if hidden > 0 else ""]
	for sid in _sec_bars:
		var p := Game.st.section_progress(sid)
		_sec_bars[sid].value = float(p.x) / maxf(1.0, p.y)

func _on_chat(n: String, text: String) -> void:
	var l := _outlined(26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.text = "%s: %s" % [n, text]
	chat_feed.add_child(l)
	while chat_feed.get_child_count() > 4:
		chat_feed.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func _process(_d: float) -> void:
	if not visible or Game.st == null:
		return
	time_lbl.text = HUDUtil.fmt_time(Game.st.elapsed)
	var p := Game.local_player
	if p == null:
		return
	var ctx := p.context()
	target_lbl.text = ctx.name
	detail_lbl.text = ctx.detail
	var held := p.held()
	var hint := ""
	if p.inspecting:
		hint = ""
	elif held.size() > 1:
		hint = "Carrying %d cases" % held.size()
	elif ctx.grab != "" and DisplayServer.is_touchscreen_available() == false:
		hint = "[E] %s%s" % [ctx.grab, ("   [F] %s" % ctx.interact) if ctx.interact != "" else ""]
	hint_lbl.text = hint
	cross.queue_redraw()
	inspect_card.visible = p.inspecting and not held.is_empty()
	if inspect_card.visible:
		var uid: int = held[held.size() - 1]
		var it: LevelState.Item = Game.st.items[uid]
		if it.product >= 0:
			var pr: Dictionary = Game.st.products[it.product]
			var t: Dictionary = Catalog.titles[pr.title]
			inspect_title.text = t.name
			var lines := ["%s · %s" % [Defs.PLATFORMS[t.platform].name, Defs.EDITION_NAMES[pr.edition]]]
			lines.append("%s · %d · %s" % [Defs.GENRE_NAMES[t.genre], t.year, Defs.PUBLISHERS[t.publisher].name])
			if it.kind == Defs.K_DISC:
				lines.append("Disc %d of %d" % [it.sub + 1, t.discs])
			elif it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX:
				lines.append("%s · %s" % [Defs.FORMAT_NAMES[it.fmt] if it.kind == Defs.K_CASE else "Collector's box", "contains %d item(s)" % it.contents.size() if not it.contents.is_empty() else "empty"])
			else:
				lines.append(Defs.KIND_NAMES[it.kind])
			lines.append("Rated %s" % Defs.RATINGS[t.rating].label)
			inspect_info.text = "\n".join(lines)
	var sc := ""
	if Settings.get_value("casual_scanner"):
		sc = "Scanner: always on"
	elif Game.scanner_t > 0.0:
		sc = "SCANNER ACTIVE %ds" % ceili(Game.scanner_t)
	scanner_chip.text = sc

func _draw_cross() -> void:
	var p := Game.local_player
	var col := Color(1, 1, 1, 0.85)
	var r := 5.0
	if p and p.target.get("type", "") != "":
		col = Color(1.0, 0.85, 0.3)
		r = 8.0
	cross.draw_circle(Vector2(15, 15), r + 2.5, Color(0.1, 0.05, 0.15, 0.6))
	cross.draw_circle(Vector2(15, 15), r, col)

func show_tutorial() -> void:
	Game.main.overlay("tutorial")

## Screen rects of HUD widgets that take taps (touch controls leave these alone).
func tap_rects() -> Array:
	return [top_panel.get_global_rect()] if top_panel and top_panel.visible else []
