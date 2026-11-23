class_name UIKit
extends RefCounted
## Chunky, rounded, touch-friendly UI theme and small builder helpers.

const CREAM := Color(1.0, 0.97, 0.9)
const INK := Color(0.16, 0.12, 0.24)
const ORANGE := Color(1.0, 0.6, 0.25)
const TEAL := Color(0.22, 0.75, 0.72)
const PINK := Color(1.0, 0.45, 0.6)
const BLUE := Color(0.35, 0.55, 1.0)
const PURPLE := Color(0.6, 0.42, 0.95)
const GREEN := Color(0.35, 0.8, 0.45)
const YELLOW := Color(1.0, 0.82, 0.25)
const GREY := Color(0.6, 0.6, 0.68)
const RED := Color(0.95, 0.35, 0.35)

static var theme: Theme
static var font_head: Font
static var font_body: Font

static func get_theme() -> Theme:
	if theme:
		return theme
	font_head = Covers.fonts.get("lilita-one", ThemeDB.fallback_font)
	font_body = Covers.fonts.get("fredoka", ThemeDB.fallback_font)
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 30
	for t in ["Button", "MenuButton", "OptionButton", "CheckButton", "CheckBox"]:
		theme.set_stylebox("normal", t, box(ORANGE, 22, 6))
		theme.set_stylebox("hover", t, box(ORANGE.lightened(0.1), 22, 6))
		theme.set_stylebox("pressed", t, box(ORANGE.darkened(0.12), 22, 2, 4))
		theme.set_stylebox("disabled", t, box(GREY, 22, 6))
		theme.set_stylebox("focus", t, focus_box())
		theme.set_color("font_color", t, Color.WHITE)
		theme.set_color("font_hover_color", t, Color.WHITE)
		theme.set_color("font_pressed_color", t, Color.WHITE)
		theme.set_color("font_disabled_color", t, Color(1, 1, 1, 0.7))
		theme.set_color("font_outline_color", t, Color(0, 0, 0, 0.25))
		theme.set_constant("outline_size", t, 6)
		theme.set_font("font", t, font_head)
		theme.set_font_size("font_size", t, 34)
	theme.set_stylebox("panel", "PanelContainer", panel_box())
	theme.set_stylebox("panel", "Panel", panel_box())
	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("normal", "LineEdit", box(Color.WHITE, 18, 0, 0, INK.lerp(Color.WHITE, 0.7)))
	theme.set_stylebox("focus", "LineEdit", box(Color.WHITE, 18, 0, 0, ORANGE))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_font_size("font_size", "LineEdit", 34)
	theme.set_stylebox("slider", "HSlider", box(Color(0.85, 0.8, 0.72), 10, 0))
	theme.set_stylebox("grabber_area", "HSlider", box(TEAL, 10, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(TEAL.lightened(0.1), 10, 0))
	theme.set_icon("grabber", "HSlider", _knob_icon(TEAL))
	theme.set_icon("grabber_highlight", "HSlider", _knob_icon(TEAL.lightened(0.15)))
	theme.set_constant("separation", "VBoxContainer", 14)
	theme.set_constant("separation", "HBoxContainer", 14)
	theme.set_stylebox("panel", "TabContainer", panel_box())
	theme.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.25), 14, 0))
	theme.set_stylebox("fill", "ProgressBar", box(GREEN, 14, 0))
	theme.set_font_size("font_size", "ProgressBar", 1)
	theme.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_constant("h_separation", "GridContainer", 12)
	theme.set_constant("v_separation", "GridContainer", 12)
	return theme

static func box(col: Color, radius := 18, shadow := 6, press_offset := 0, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 12 + press_offset
	s.content_margin_bottom = 14 - press_offset
	if shadow > 0:
		s.shadow_color = Color(0.1, 0.05, 0.15, 0.35)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow)
		s.border_width_bottom = shadow
		s.border_color = col.darkened(0.25)
	if border.a > 0.0:
		s.set_border_width_all(4)
		s.border_color = border
	return s

static func panel_box(col := CREAM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(32)
	s.corner_detail = 8
	s.border_width_bottom = 10
	s.border_color = col.darkened(0.18)
	s.shadow_color = Color(0.1, 0.05, 0.15, 0.3)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 8)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 28
	s.content_margin_bottom = 32
	return s

static func focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(4)
	s.border_color = Color(1, 1, 1, 0.9)
	s.set_corner_radius_all(24)
	return s

static func _knob_icon(c: Color) -> Texture2D:
	var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 44:
		for x in 44:
			var d := Vector2(x - 21.5, y - 21.5).length()
			if d < 20.0:
				img.set_pixel(x, y, Color.WHITE if d < 14.0 else c.darkened(0.1))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ builders
static func button(text: String, col := ORANGE, cb := Callable(), font_size := 34, min_h := 84) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_stylebox_override("normal", box(col, 22, 6))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.08), 22, 6))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.1), 22, 2, 4))
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_ALL
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.ui()
			cb.call())
	b.button_down.connect(func(): _squish(b))
	return b

static func _squish(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(c, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func label(text: String, size := 30, col := INK, head := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if head:
		l.add_theme_font_override("font", Covers.fonts.get("lilita-one"))
	l.horizontal_alignment = align
	# Only wrap long text: short labels inside rows must never collapse to one letter per line.
	if text.length() > 42 or text.find("\n") >= 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
	return l

static func title(text: String, size := 64) -> Label:
	var l := label(text, size, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 18)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	l.add_theme_constant_override("shadow_offset_y", 6)
	return l

static func panel(col := CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(col))
	return p

static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func slider_row(text: String, minv: float, maxv: float, step: float, value: float, cb: Callable, fmt := "%.2f") -> HBoxContainer:
	var h := hbox()
	var l := label(text, 28)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(260, 56)
	var v := label(fmt % value, 28)
	v.custom_minimum_size = Vector2(110, 0)
	s.value_changed.connect(func(x):
		v.text = fmt % x
		cb.call(x))
	h.add_child(s)
	h.add_child(v)
	return h

static func toggle_row(text: String, value: bool, cb: Callable) -> HBoxContainer:
	var h := hbox()
	var l := label(text, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := button("ON" if value else "OFF", GREEN if value else GREY, Callable(), 28, 64)
	b.custom_minimum_size = Vector2(150, 64)
	b.toggle_mode = true
	b.button_pressed = value
	b.toggled.connect(func(on):
		Sfx.ui()
		b.text = "ON" if on else "OFF"
		b.add_theme_stylebox_override("normal", box(GREEN if on else GREY, 22, 6))
		b.add_theme_stylebox_override("hover", box((GREEN if on else GREY).lightened(0.08), 22, 6))
		cb.call(on))
	h.add_child(b)
	return h

static func choice_row(text: String, options: Array, current: int, cb: Callable) -> HBoxContainer:
	var h := hbox(10)
	var l := label(text, 28)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var btns: Array = []
	for i in options.size():
		var b := button(str(options[i]), TEAL if i == current else GREY, Callable(), 26, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.append(b)
		h.add_child(b)
	for i in btns.size():
		btns[i].pressed.connect(func():
			Sfx.ui()
			for j in btns.size():
				btns[j].add_theme_stylebox_override("normal", box(TEAL if j == i else GREY, 22, 6))
				btns[j].add_theme_stylebox_override("hover", box((TEAL if j == i else GREY).lightened(0.08), 22, 6))
			cb.call(i))
	return h

static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(c)
	return cc

static func stars_text(n: int, total := 3) -> String:
	var s := ""
	for i in total:
		s += "★" if i < n else "☆"
	return s
