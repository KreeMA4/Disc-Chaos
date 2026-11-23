extends Control
## Procedural cover-art painter. One instance paints one job, clipped to its own rect, inside a
## SubViewport. One seed drives front, spine, back, disc label, steelbook and collector box so the
## pieces visibly match (same motif, palette and logo).
##
## job: {part: "front"|"back"|"spine"|"label"|"steel"|"poster", title: Dictionary, edition: int,
##       disc: int, rect: Rect2, vsize: Vector2 (optional virtual paint size), override: Texture2D}

var job: Dictionary = {}
var fonts: Dictionary = {}
var noise_tex: Texture2D

const OUTLINE := Color(0.12, 0.09, 0.18)

func setup(j: Dictionary, f: Dictionary, n: Texture2D) -> void:
	job = j
	fonts = f
	noise_tex = n
	var r: Rect2 = j.rect
	position = r.position
	size = r.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var j := job
	if j.is_empty():
		return
	var local := Rect2(Vector2.ZERO, (j.rect as Rect2).size)
	if j.get("override") != null:
		if j.part == "spine" and j.get("override_rotate", false) and (j.override as Texture2D).get_height() > (j.override as Texture2D).get_width():
			draw_set_transform(Vector2(0, local.size.y), -PI * 0.5)
			draw_texture_rect(j.override, Rect2(Vector2.ZERO, Vector2(local.size.y, local.size.x)), false)
		else:
			draw_texture_rect(j.override, local, false)
		return
	var rect := local
	if j.has("vsize"):
		var vs: Vector2 = j.vsize
		draw_set_transform(Vector2.ZERO, 0.0, local.size / vs)
		rect = Rect2(Vector2.ZERO, vs)
	match j.part:
		"front": paint_front(rect, j.title, j.edition)
		"steel": paint_steel(rect, j.title)
		"back": paint_back(rect, j.title, j.edition)
		"spine": paint_spine(rect, j.title, j.edition)
		"label": paint_label(rect, j.title, j.edition, j.get("disc", 0))
		"poster": paint_poster(rect, j.title)
	draw_set_transform(Vector2.ZERO)

# ======================================================================== palette
static func palette(t: Dictionary) -> Dictionary:
	return CoverPalette.palette(t)

# ======================================================================== primitives
func grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func grad_rect_h(r: Rect2, left: Color, right: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([left, right, right, left]))

func poly(pts: Array, col: Color) -> void:
	var pv := PackedVector2Array(pts)
	if pv.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pv).is_empty():
		pv = Geometry2D.convex_hull(pv)
		if pv.size() < 4:
			return
	draw_colored_polygon(pv, col)

func ellipse(c: Vector2, rx: float, ry: float, col: Color, filled := true, width := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, width, true)

func rrect(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

func rrect_outline(r: Rect2, rad: float, col: Color, border: Color, bw: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(int(maxf(1.0, bw)))
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

func rays(c: Vector2, n: int, r: float, col: Color, rot := 0.0) -> void:
	for i in n:
		var a0 := rot + TAU * i / n
		var a1 := a0 + TAU / n * 0.5
		poly([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r], col)

func stars(r: Rect2, n: int, rng: RandomNumberGenerator, col: Color) -> void:
	for i in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		draw_circle(p, maxf(0.5, rng.randf() * r.size.x * 0.006), col)

func noise_overlay(r: Rect2, alpha := 0.12) -> void:
	if noise_tex:
		draw_texture_rect(noise_tex, r, true, Color(1, 1, 1, alpha))

func font(name: String) -> Font:
	return fonts.get(name, fonts.get("fredoka", ThemeDB.fallback_font))

## Draws text fitted into width, returns height used. Optional outline and shadow.
func fit_text(text: String, pos: Vector2, width: float, max_size: int, col: Color, fname: String,
		outline := 0.0, outline_col := OUTLINE, align := HORIZONTAL_ALIGNMENT_CENTER, shadow := true) -> float:
	if width <= 1.0 or max_size <= 1 or text == "":
		return 0.0
	var f := font(fname)
	var size := max_size
	while size > 6 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	var asc := f.get_ascent(size)
	var p := pos + Vector2(0, asc)
	if shadow and outline > 0.0:
		draw_string_outline(f, p + Vector2(outline * 0.6, outline * 0.8), text, align, width, size, int(outline * 2.0), Color(0, 0, 0, 0.35))
	if outline > 0.0:
		draw_string_outline(f, p, text, align, width, size, int(outline * 2.0), outline_col)
	draw_string(f, p, text, align, width, size, col)
	return f.get_height(size)

func title_lines(name: String) -> Array:
	if name.length() <= 13 or name.find(" ") < 0:
		return [name]
	var mid := name.length() / 2
	var best := -1
	for i in name.length():
		if name[i] == " " and (best < 0 or absi(i - mid) < absi(best - mid)):
			best = i
	if name.find(":") > 0:
		var c := name.find(":")
		return [name.substr(0, c), name.substr(c + 1).strip_edges()]
	return [name.substr(0, best), name.substr(best + 1)]

# ======================================================================== logos
func platform_logo(kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"orbit":
			draw_circle(c, s * 0.35, col)
			ellipse(c, s * 0.62, s * 0.22, col, false, maxf(1.0, s * 0.09))
		"orbit2":
			draw_circle(c, s * 0.3, col)
			ellipse(c, s * 0.6, s * 0.2, col, false, maxf(1.0, s * 0.08))
			draw_circle(c + Vector2(s * 0.55, -s * 0.12), s * 0.09, col)
		"wing":
			for i in 3:
				var o := Vector2(i * s * 0.22 - s * 0.3, 0)
				poly([c + o + Vector2(-s * 0.15, -s * 0.35), c + o + Vector2(s * 0.12, 0), c + o + Vector2(-s * 0.15, s * 0.35), c + o + Vector2(-s * 0.02, 0)], col)
		"pip":
			rrect(Rect2(c - Vector2(s * 0.5, s * 0.3), Vector2(s, s * 0.6)), s * 0.25, col)
			draw_circle(c + Vector2(-s * 0.22, 0), s * 0.1, Color(1, 1, 1, 0.9))
			draw_circle(c + Vector2(s * 0.22, 0), s * 0.1, Color(1, 1, 1, 0.9))
		"bubbles":
			draw_circle(c + Vector2(-s * 0.2, s * 0.1), s * 0.25, col)
			draw_circle(c + Vector2(s * 0.2, -s * 0.05), s * 0.18, col)
			draw_circle(c + Vector2(s * 0.05, -s * 0.3), s * 0.11, col)
		"gear":
			var pts: Array = []
			for i in 16:
				var a := TAU * i / 16.0
				var rr := s * (0.48 if i % 2 == 0 else 0.36)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			poly(pts, col)
			draw_circle(c, s * 0.15, Color(0, 0, 0, 0.6))
		"prism":
			poly([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.45, s * 0.35), c + Vector2(-s * 0.45, s * 0.35)], col)
			for i in 3:
				draw_line(c + Vector2(s * 0.1, 0), c + Vector2(s * 0.7, -s * 0.1 + i * s * 0.12), Color.from_hsv(i / 3.0, 0.8, 1.0), maxf(1.0, s * 0.07))
		"monitor":
			rrect(Rect2(c - Vector2(s * 0.45, s * 0.35), Vector2(s * 0.9, s * 0.55)), s * 0.08, col)
			draw_rect(Rect2(c - Vector2(s * 0.35, s * 0.27), Vector2(s * 0.7, s * 0.39)), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(c + Vector2(-s * 0.08, s * 0.2), Vector2(s * 0.16, s * 0.15)), col)
		_:
			draw_circle(c, s * 0.4, col)

func publisher_logo(idx: int, c: Vector2, s: float) -> void:
	var p: Dictionary = Defs.PUBLISHERS[idx]
	var col: Color = p.color
	match p.shape:
		"circle": draw_circle(c, s * 0.45, col); draw_circle(c, s * 0.22, Color.WHITE)
		"stack":
			for i in 3: rrect(Rect2(c + Vector2(-s * 0.45, -s * 0.4 + i * s * 0.28), Vector2(s * 0.9, s * 0.22)), s * 0.1, col.darkened(i * 0.12))
		"triangle": poly([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.45, s * 0.4), c + Vector2(-s * 0.45, s * 0.4)], col)
		"moon": draw_circle(c, s * 0.42, col); draw_circle(c + Vector2(s * 0.18, -s * 0.1), s * 0.32, Color(0, 0, 0, 0.0)); draw_circle(c + Vector2(s * 0.2, -s * 0.12), s * 0.3, Color(1, 1, 1, 0.35))
		"square": rrect(Rect2(c - Vector2(s * 0.42, s * 0.42), Vector2(s * 0.84, s * 0.84)), s * 0.15, col)
		"pixel":
			for i in 3:
				for k in 3:
					if (i + k) % 2 == 0:
						draw_rect(Rect2(c + Vector2(-s * 0.45 + i * s * 0.3, -s * 0.45 + k * s * 0.3), Vector2(s * 0.28, s * 0.28)), col)
		"star":
			var pts: Array = []
			for i in 10:
				var a := -PI / 2 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s * (0.48 if i % 2 == 0 else 0.2)))
			poly(pts, col)
		"leaf": ellipse(c, s * 0.25, s * 0.45, col)
		"saucer": ellipse(c + Vector2(0, s * 0.05), s * 0.48, s * 0.16, col); draw_circle(c + Vector2(0, -s * 0.08), s * 0.18, col.lightened(0.3))
		"blob": draw_circle(c + Vector2(-s * 0.12, 0), s * 0.3, col); draw_circle(c + Vector2(s * 0.18, s * 0.05), s * 0.24, col)
		"wave":
			for i in 3: draw_arc(c + Vector2(0, s * 0.3), s * (0.2 + i * 0.12), PI, TAU, 10, col, maxf(1.0, s * 0.08))
		"bolt": poly([c + Vector2(s * 0.1, -s * 0.5), c + Vector2(-s * 0.3, s * 0.05), c + Vector2(0, s * 0.05), c + Vector2(-s * 0.1, s * 0.5), c + Vector2(s * 0.3, -s * 0.05), c + Vector2(0, -s * 0.05)], col)
		"hex":
			var pts: Array = []
			for i in 6:
				pts.append(c + Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0)) * s * 0.45)
			poly(pts, col)
		"tooth": rrect(Rect2(c - Vector2(s * 0.35, s * 0.45), Vector2(s * 0.7, s * 0.6)), s * 0.25, col); draw_rect(Rect2(c + Vector2(-s * 0.3, 0), Vector2(s * 0.2, s * 0.45)), col); draw_rect(Rect2(c + Vector2(s * 0.1, 0), Vector2(s * 0.2, s * 0.45)), col)
		_: draw_circle(c, s * 0.4, col)

func rating_badge(r: Rect2, rating: int) -> void:
	var rd: Dictionary = Defs.RATINGS[rating]
	rrect_outline(r, r.size.x * 0.18, Color.WHITE, OUTLINE, maxf(1.0, r.size.x * 0.06))
	rrect(Rect2(r.position + r.size * Vector2(0.1, 0.08), r.size * Vector2(0.8, 0.62)), r.size.x * 0.12, rd.color)
	fit_text(rd.label, r.position + r.size * Vector2(0.1, 0.12), r.size.x * 0.8, int(r.size.y * 0.42), Color.WHITE, "lilita-one", 0.0)
	fit_text("PLAYSAFE", r.position + r.size * Vector2(0.05, 0.71), r.size.x * 0.9, int(r.size.y * 0.2), OUTLINE, "fredoka", 0.0)

func platform_banner(r: Rect2, plat: Dictionary, edition: int) -> void:
	var bc: Color = plat.banner
	var tc: Color = plat.banner_text
	if edition == Defs.E_GH:
		grad_rect(r, Color(1.0, 0.86, 0.35), Color(0.9, 0.62, 0.15))
		tc = Color(0.3, 0.18, 0.02)
	elif plat.code == "S16":
		grad_rect(r, bc, bc)
		for i in 5:
			draw_rect(Rect2(r.position + Vector2(r.size.x * (0.74 + i * 0.05), 0), Vector2(r.size.x * 0.04, r.size.y)), Color.from_hsv(i / 5.0, 0.8, 1.0))
	elif plat.code == "P32":
		grad_rect_h(r, Color(0.98, 0.98, 1.0), Color(0.85, 0.88, 0.95))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.85), Vector2(r.size.x, r.size.y * 0.15)), Color(0.9, 0.2, 0.4))
	else:
		grad_rect(r, bc.lightened(0.12), bc.darkened(0.1))
	var s := r.size.y
	platform_logo(plat.logo, r.position + Vector2(s * 0.7, s * 0.5), s * 0.8, tc)
	var label: String = plat.name
	if edition == Defs.E_GH:
		label = "GOLDEN GREATS"
	fit_text(label, r.position + Vector2(s * 1.3, s * 0.12), r.size.x - s * 1.5, int(s * 0.62), tc, plat.font if edition != Defs.E_GH else "lilita-one", 0.0, OUTLINE, HORIZONTAL_ALIGNMENT_LEFT, false)

# ======================================================================== motifs (genre templates)
func motif(r: Rect2, t: Dictionary, pal: Dictionary, zoom := 1.0, offset := Vector2.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pal.seed
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	var P := func(x: float, y: float) -> Vector2: return o + Vector2((x + offset.x) * w, (y + offset.y) * h)
	var S := w * zoom
	match int(t.genre):
		Defs.G_SPACE:
			grad_rect(r, pal.dark, pal.mid)
			stars(r, 60, rng, Color(1, 1, 1, 0.8))
			var pc: Vector2 = P.call(0.68, 0.38)
			draw_circle(pc, S * 0.26, pal.accent)
			draw_circle(pc + Vector2(S * 0.05, -S * 0.04), S * 0.2, pal.accent.lightened(0.2))
			ellipse(pc, S * 0.42, S * 0.09, pal.light, false, maxf(1.0, S * 0.025))
			var sc: Vector2 = P.call(0.32, 0.62)
			poly([sc + Vector2(0, -S * 0.16), sc + Vector2(S * 0.1, S * 0.12), sc + Vector2(0, S * 0.06), sc + Vector2(-S * 0.1, S * 0.12)], pal.light)
			draw_circle(sc + Vector2(0, S * 0.1), S * 0.04, Color(1.0, 0.7, 0.3))
			for i in 4:
				var a: Vector2 = P.call(0.1 + i * 0.2, 0.9 - i * 0.1)
				draw_line(a, a + Vector2(S * 0.15, -S * 0.15), pal.accent2, maxf(1.0, S * 0.012))
		Defs.G_KART:
			grad_rect(r, pal.sky1, pal.sky2.lerp(Color(1, 0.8, 0.5), 0.5))
			draw_circle(P.call(0.75, 0.3), S * 0.16, Color(1.0, 0.9, 0.55))
			poly([P.call(0.42, 0.45), P.call(0.58, 0.45), P.call(1.1, 1.0), P.call(-0.1, 1.0)], Color(0.3, 0.3, 0.36))
			poly([P.call(-0.2, 0.45), P.call(0.42, 0.45), P.call(-0.1, 1.0), P.call(-0.2, 1.0)], Color(0.4, 0.75, 0.35))
			poly([P.call(0.58, 0.45), P.call(1.2, 0.45), P.call(1.2, 1.0), P.call(1.1, 1.0)], Color(0.4, 0.75, 0.35))
			for i in 7:
				var y := 0.5 + i * 0.07
				var x0 := 0.42 - (y - 0.45) * 0.95
				var x1 := 0.58 + (y - 0.45) * 0.95
				draw_rect(Rect2(P.call(x0, y), Vector2((x1 - x0) * w * 0.12, h * 0.025)), Color(1, 1, 1) if i % 2 == 0 else Color(0.9, 0.2, 0.2))
			var kc: Vector2 = P.call(0.5, 0.72)
			rrect(Rect2(kc - Vector2(S * 0.22, S * 0.08), Vector2(S * 0.44, S * 0.14)), S * 0.06, pal.accent)
			draw_circle(kc + Vector2(-S * 0.15, S * 0.07), S * 0.06, OUTLINE)
			draw_circle(kc + Vector2(S * 0.15, S * 0.07), S * 0.06, OUTLINE)
			draw_circle(kc + Vector2(0, -S * 0.13), S * 0.08, pal.accent2)
			draw_circle(kc + Vector2(S * 0.02, -S * 0.15), S * 0.04, Color.WHITE)
			for i in 6:
				var y2 := 0.55 + i * 0.05
				draw_line(P.call(0.02, y2), P.call(0.25, y2), Color(1, 1, 1, 0.6), maxf(1.0, S * 0.01))
		Defs.G_CRIME:
			grad_rect(r, Color(1.0, 0.55, 0.35), Color(0.85, 0.25, 0.55))
			draw_circle(P.call(0.5, 0.55), S * 0.3, Color(1.0, 0.85, 0.45))
			for i in 9:
				var bx := i / 9.0
				var bh := 0.25 + rng.randf() * 0.35
				var col: Color = pal.dark.lerp(Color(0.2, 0.05, 0.25), 0.5)
				draw_rect(Rect2(P.call(bx, 1.0 - bh), Vector2(w / 9.0 + 1, bh * h)), col)
				for k in 6:
					if rng.randf() < 0.5:
						draw_rect(Rect2(P.call(bx + 0.02 + (k % 2) * 0.04, 1.0 - bh + 0.04 + (k / 2) * 0.06), Vector2(w * 0.025, h * 0.025)), Color(1, 0.9, 0.5, 0.8))
			for px in [0.12, 0.88]:
				var b2: Vector2 = P.call(px, 1.0)
				draw_line(b2, b2 + Vector2(0, -h * 0.45), Color(0.1, 0.05, 0.12), maxf(1.0, S * 0.025))
				for k in 5:
					var a := -PI * 0.5 + (k - 2) * 0.55
					poly([b2 + Vector2(0, -h * 0.45), b2 + Vector2(0, -h * 0.45) + Vector2(cos(a), sin(a) + 0.4) * S * 0.18, b2 + Vector2(0, -h * 0.43)], Color(0.1, 0.05, 0.12))
			var fc: Vector2 = P.call(0.5, 0.85)
			rrect(Rect2(fc - Vector2(S * 0.13, S * 0.05), Vector2(S * 0.26, S * 0.4)), S * 0.06, OUTLINE)
			draw_circle(fc + Vector2(0, -S * 0.12), S * 0.09, OUTLINE)
			draw_rect(Rect2(fc + Vector2(-S * 0.09, -S * 0.15), Vector2(S * 0.18, S * 0.035)), Color(0.9, 0.2, 0.6))
			draw_line(P.call(0.0, 0.2), P.call(1.0, 0.05), Color(1, 1, 1, 0.5), maxf(1.0, S * 0.01))
		Defs.G_MONSTER:
			grad_rect(r, pal.sky2.lightened(0.2), pal.sky1.lightened(0.3))
			ellipse(P.call(0.3, 1.05), w * 0.8, h * 0.3, Color(0.45, 0.8, 0.4))
			ellipse(P.call(0.9, 1.1), w * 0.6, h * 0.3, Color(0.35, 0.7, 0.35))
			for i in 3:
				var cc: Vector2 = P.call(0.25 + i * 0.27, 0.68 - (i % 2) * 0.12)
				var cs := S * (0.16 - i * 0.02)
				var col := Color.from_ok_hsl(fposmod(pal.h + i * 0.3, 1.0), 0.75, 0.68)
				draw_circle(cc, cs, col)
				poly([cc + Vector2(-cs * 0.7, -cs * 0.5), cc + Vector2(-cs * 0.9, -cs * 1.4), cc + Vector2(-cs * 0.2, -cs * 0.85)], col)
				poly([cc + Vector2(cs * 0.7, -cs * 0.5), cc + Vector2(cs * 0.9, -cs * 1.4), cc + Vector2(cs * 0.2, -cs * 0.85)], col)
				draw_circle(cc + Vector2(-cs * 0.35, -cs * 0.1), cs * 0.25, Color.WHITE)
				draw_circle(cc + Vector2(cs * 0.35, -cs * 0.1), cs * 0.25, Color.WHITE)
				draw_circle(cc + Vector2(-cs * 0.3, -cs * 0.08), cs * 0.12, OUTLINE)
				draw_circle(cc + Vector2(cs * 0.4, -cs * 0.08), cs * 0.12, OUTLINE)
				draw_arc(cc + Vector2(0, cs * 0.25), cs * 0.25, 0.3, PI - 0.3, 8, OUTLINE, maxf(1.0, cs * 0.08))
			var jar: Vector2 = P.call(0.82, 0.35)
			rrect(Rect2(jar - Vector2(S * 0.07, S * 0.09), Vector2(S * 0.14, S * 0.18)), S * 0.04, Color(0.8, 0.95, 1.0, 0.8))
			draw_rect(Rect2(jar - Vector2(S * 0.08, S * 0.11), Vector2(S * 0.16, S * 0.04)), pal.accent)
			for i in 6:
				draw_circle(P.call(rng.randf(), rng.randf() * 0.5), S * 0.012, Color(1, 1, 0.8))
		Defs.G_FANTASY:
			grad_rect(r, pal.dark, pal.sky1)
			draw_circle(P.call(0.72, 0.22), S * 0.13, Color(1.0, 0.95, 0.8))
			stars(Rect2(o, Vector2(w, h * 0.5)), 30, rng, Color(1, 1, 1, 0.6))
			poly([P.call(-0.1, 1.0), P.call(0.2, 0.55), P.call(0.45, 0.8), P.call(0.7, 0.5), P.call(1.1, 1.0)], pal.mid.darkened(0.3))
			var cb: Vector2 = P.call(0.7, 0.72)
			draw_rect(Rect2(cb - Vector2(S * 0.12, S * 0.18), Vector2(S * 0.24, S * 0.2)), pal.dark)
			for i in 3:
				var tx := -0.12 + i * 0.1
				draw_rect(Rect2(cb + Vector2(S * tx, -S * 0.3), Vector2(S * 0.05, S * 0.14)), pal.dark)
				poly([cb + Vector2(S * (tx - 0.01), -S * 0.3), cb + Vector2(S * (tx + 0.025), -S * 0.38), cb + Vector2(S * (tx + 0.06), -S * 0.3)], pal.dark)
			var dc: Vector2 = P.call(0.35, 0.3)
			poly([dc, dc + Vector2(-S * 0.25, -S * 0.12), dc + Vector2(-S * 0.1, S * 0.02), dc + Vector2(S * 0.05, S * 0.02), dc + Vector2(S * 0.25, -S * 0.15), dc + Vector2(S * 0.1, S * 0.05), dc + Vector2(S * 0.15, S * 0.1)], pal.dark.lerp(pal.accent, 0.3))
			var sw: Vector2 = P.call(0.5, 0.95)
			poly([sw + Vector2(-S * 0.02, 0), sw + Vector2(0, -S * 0.55), sw + Vector2(S * 0.02, 0)], Color(0.9, 0.93, 1.0))
			draw_rect(Rect2(sw + Vector2(-S * 0.09, -S * 0.02), Vector2(S * 0.18, S * 0.03)), pal.accent)
			draw_circle(sw + Vector2(0, -S * 0.3), S * 0.08, Color(pal.accent2, 0.35))
		Defs.G_HORROR:
			grad_rect(r, Color(0.12, 0.16, 0.14), pal.mid.darkened(0.15))
			draw_circle(P.call(0.75, 0.22), S * 0.14, Color(0.95, 0.95, 0.8))
			draw_circle(P.call(0.78, 0.2), S * 0.12, Color(0.85, 0.85, 0.7))
			var mc: Vector2 = P.call(0.5, 0.75)
			poly([mc + Vector2(-S * 0.35, S * 0.1), mc + Vector2(-S * 0.35, -S * 0.15), mc + Vector2(-S * 0.18, -S * 0.32), mc + Vector2(0, -S * 0.15), mc + Vector2(S * 0.1, -S * 0.42), mc + Vector2(S * 0.22, -S * 0.15), mc + Vector2(S * 0.35, -S * 0.15), mc + Vector2(S * 0.35, S * 0.1)], Color(0.02, 0.02, 0.03))
			for i in 5:
				draw_rect(Rect2(mc + Vector2(-S * 0.3 + i * S * 0.13, -S * 0.08), Vector2(S * 0.05, S * 0.07)), Color(1.0, 0.85, 0.3, 0.9) if rng.randf() < 0.6 else Color(0.1, 0.1, 0.1))
			for tx in [0.08, 0.92]:
				var tb: Vector2 = P.call(tx, 1.0)
				draw_line(tb, tb + Vector2(0, -h * 0.5), Color(0.02, 0.02, 0.02), maxf(1.0, S * 0.03))
				for k in 4:
					draw_line(tb + Vector2(0, -h * (0.25 + k * 0.06)), tb + Vector2((1 if k % 2 else -1) * S * 0.12, -h * (0.32 + k * 0.06)), Color(0.02, 0.02, 0.02), maxf(1.0, S * 0.012))
			for i in 3:
				grad_rect(Rect2(P.call(0, 0.82 + i * 0.05), Vector2(w, h * 0.06)), Color(0.7, 0.8, 0.75, 0.0), Color(0.7, 0.8, 0.75, 0.25))
		Defs.G_MASCOT:
			grad_rect(r, pal.sky1.lightened(0.3), pal.sky2.lightened(0.4))
			for i in 3:
				var cl: Vector2 = P.call(0.15 + i * 0.35, 0.15 + (i % 2) * 0.08)
				for k in 3:
					draw_circle(cl + Vector2((k - 1) * S * 0.06, 0), S * 0.06, Color(1, 1, 1, 0.9))
			for i in 3:
				var pl: Vector2 = P.call(0.1 + i * 0.32, 0.55 + (i % 2) * 0.2)
				rrect(Rect2(pl, Vector2(S * 0.22, S * 0.06)), S * 0.03, Color(0.55, 0.85, 0.35))
				draw_rect(Rect2(pl + Vector2(0, S * 0.04), Vector2(S * 0.22, S * 0.03)), Color(0.6, 0.4, 0.25))
			for i in 5:
				draw_circle(P.call(0.2 + i * 0.13, 0.42), S * 0.025, Color(1.0, 0.82, 0.2))
			var mc2: Vector2 = P.call(0.5, 0.72)
			var mcol: Color = pal.accent
			poly([mc2 + Vector2(-S * 0.15, -S * 0.08), mc2 + Vector2(-S * 0.22, -S * 0.3), mc2 + Vector2(-S * 0.05, -S * 0.15)], mcol)
			poly([mc2 + Vector2(S * 0.15, -S * 0.08), mc2 + Vector2(S * 0.22, -S * 0.3), mc2 + Vector2(S * 0.05, -S * 0.15)], mcol)
			draw_circle(mc2, S * 0.18, mcol)
			draw_circle(mc2 + Vector2(0, S * 0.06), S * 0.1, mcol.lightened(0.4))
			draw_circle(mc2 + Vector2(-S * 0.07, -S * 0.04), S * 0.055, Color.WHITE)
			draw_circle(mc2 + Vector2(S * 0.07, -S * 0.04), S * 0.055, Color.WHITE)
			draw_circle(mc2 + Vector2(-S * 0.06, -S * 0.035), S * 0.028, OUTLINE)
			draw_circle(mc2 + Vector2(S * 0.08, -S * 0.035), S * 0.028, OUTLINE)
			draw_arc(mc2 + Vector2(0, S * 0.05), S * 0.06, 0.2, PI - 0.2, 8, OUTLINE, maxf(1.0, S * 0.015))
			ellipse(mc2 + Vector2(-S * 0.1, S * 0.2), S * 0.08, S * 0.04, Color(0.9, 0.2, 0.2))
			ellipse(mc2 + Vector2(S * 0.1, S * 0.2), S * 0.08, S * 0.04, Color(0.9, 0.2, 0.2))
		Defs.G_SPORTS:
			grad_rect(r, pal.dark, pal.mid)
			for i in 4:
				var lp: Vector2 = P.call(0.1 + i * 0.27, 0.12)
				draw_rect(Rect2(lp, Vector2(S * 0.12, S * 0.05)), Color(1, 1, 0.85))
				poly([lp, lp + Vector2(S * 0.12, 0), lp + Vector2(S * 0.3, h * 0.5), lp + Vector2(-S * 0.18, h * 0.5)], Color(1, 1, 0.8, 0.08))
			for i in 4:
				draw_rect(Rect2(P.call(0, 0.3 + i * 0.06), Vector2(w, h * 0.04)), pal.mid.lerp(pal.accent2, 0.2 + i * 0.1))
			grad_rect(Rect2(P.call(0, 0.55), Vector2(w, h * 0.45)), Color(0.3, 0.7, 0.35), Color(0.2, 0.55, 0.25))
			draw_line(P.call(0, 0.75), P.call(1, 0.75), Color(1, 1, 1, 0.7), maxf(1.0, S * 0.01))
			ellipse(P.call(0.5, 0.75), S * 0.15, S * 0.05, Color(1, 1, 1, 0.7), false, maxf(1.0, S * 0.01))
			var bc: Vector2 = P.call(0.65, 0.45)
			draw_circle(bc, S * 0.13, pal.accent)
			draw_arc(bc, S * 0.13, 0, TAU, 20, OUTLINE, maxf(1.0, S * 0.012))
			draw_line(bc + Vector2(-S * 0.13, 0), bc + Vector2(S * 0.13, 0), OUTLINE, maxf(1.0, S * 0.01))
			draw_arc(bc + Vector2(-S * 0.2, 0), S * 0.15, -0.8, 0.8, 8, OUTLINE, maxf(1.0, S * 0.01))
			var pc2: Vector2 = P.call(0.3, 0.75)
			draw_circle(pc2 + Vector2(0, -S * 0.3), S * 0.06, OUTLINE)
			poly([pc2 + Vector2(-S * 0.08, -S * 0.24), pc2 + Vector2(S * 0.08, -S * 0.24), pc2 + Vector2(S * 0.05, -S * 0.05), pc2 + Vector2(-S * 0.05, -S * 0.05)], pal.accent2)
			draw_line(pc2 + Vector2(-S * 0.03, -S * 0.05), pc2 + Vector2(-S * 0.12, S * 0.08), OUTLINE, maxf(1.0, S * 0.03))
			draw_line(pc2 + Vector2(S * 0.03, -S * 0.05), pc2 + Vector2(S * 0.14, S * 0.02), OUTLINE, maxf(1.0, S * 0.03))
		Defs.G_FIGHTING:
			grad_rect(r, pal.accent.darkened(0.3), pal.dark)
			rays(P.call(0.5, 0.5), 18, S * 1.2, Color(1, 1, 0.8, 0.12), pal.h * 3.0)
			for side in [-1.0, 1.0]:
				var fc2: Vector2 = P.call(0.5 + side * 0.24, 0.72)
				var col2: Color = pal.accent2 if side < 0 else pal.light.darkened(0.1)
				draw_circle(fc2 + Vector2(0, -S * 0.3), S * 0.07, col2)
				poly([fc2 + Vector2(-S * 0.1, -S * 0.22), fc2 + Vector2(S * 0.1, -S * 0.22), fc2 + Vector2(S * 0.07, S * 0.05), fc2 + Vector2(-S * 0.07, S * 0.05)], col2)
				draw_line(fc2 + Vector2(-side * S * 0.08, -S * 0.18), fc2 + Vector2(-side * S * 0.22, -S * 0.25), col2, maxf(1.0, S * 0.04))
				draw_circle(fc2 + Vector2(-side * S * 0.23, -S * 0.26), S * 0.035, col2)
				draw_line(fc2 + Vector2(-S * 0.04, S * 0.05), fc2 + Vector2(-S * 0.1, S * 0.25), col2, maxf(1.0, S * 0.045))
				draw_line(fc2 + Vector2(S * 0.04, S * 0.05), fc2 + Vector2(S * 0.1, S * 0.25), col2, maxf(1.0, S * 0.045))
			var vs: Vector2 = P.call(0.5, 0.42)
			poly([vs + Vector2(-S * 0.03, -S * 0.15), vs + Vector2(S * 0.06, -S * 0.02), vs + Vector2(0, 0), vs + Vector2(S * 0.03, S * 0.15), vs + Vector2(-S * 0.06, S * 0.02), vs + Vector2(0, 0)], Color(1, 0.95, 0.4))
		Defs.G_RHYTHM:
			grad_rect(r, Color(0.12, 0.04, 0.2), pal.mid)
			for i in 9:
				var x := i / 8.0
				draw_line(P.call(0.5, 0.55), P.call(x * 1.6 - 0.3, 1.0), Color(pal.accent, 0.6), maxf(1.0, S * 0.008))
			for i in 5:
				var y3 := 0.6 + i * i * 0.017
				draw_line(P.call(0, y3), P.call(1, y3), Color(pal.accent, 0.5), maxf(1.0, S * 0.008))
			for i in 10:
				var bh2 := 0.08 + rng.randf() * 0.25
				draw_rect(Rect2(P.call(0.05 + i * 0.09, 0.55 - bh2), Vector2(w * 0.06, h * bh2)), Color.from_ok_hsl(fposmod(pal.h + i * 0.08, 1.0), 0.9, 0.65))
			var db: Vector2 = P.call(0.5, 0.15)
			draw_circle(db, S * 0.1, Color(0.85, 0.85, 0.95))
			for i in 4:
				draw_line(db + Vector2(-S * 0.1, (i - 1.5) * S * 0.045), db + Vector2(S * 0.1, (i - 1.5) * S * 0.045), Color(0.5, 0.5, 0.7), 1.0)
			for i in 3:
				var nc: Vector2 = P.call(0.15 + i * 0.35, 0.3 + (i % 2) * 0.08)
				ellipse(nc, S * 0.035, S * 0.027, pal.light)
				draw_line(nc + Vector2(S * 0.03, 0), nc + Vector2(S * 0.03, -S * 0.12), pal.light, maxf(1.0, S * 0.012))
		Defs.G_MECH:
			grad_rect(r, pal.mid, pal.dark)
			for i in 12:
				var hx := (i % 4) * 0.3 + (0.15 if (i / 4) % 2 else 0.0)
				var hy := (i / 4) * 0.25
				var hc: Vector2 = P.call(hx, hy)
				var hpts: Array = []
				for k in 6:
					hpts.append(hc + Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0)) * S * 0.12)
				hpts.append(hpts[0])
				draw_polyline(PackedVector2Array(hpts), Color(1, 1, 1, 0.08), 1.0)
			var mb: Vector2 = P.call(0.5, 0.62)
			var mcol2: Color = pal.light.darkened(0.25)
			draw_rect(Rect2(mb - Vector2(S * 0.16, S * 0.2), Vector2(S * 0.32, S * 0.26)), mcol2)
			draw_rect(Rect2(mb - Vector2(S * 0.08, S * 0.32), Vector2(S * 0.16, S * 0.12)), mcol2.lightened(0.1))
			draw_rect(Rect2(mb - Vector2(S * 0.05, S * 0.27), Vector2(S * 0.1, S * 0.03)), pal.accent)
			draw_rect(Rect2(mb + Vector2(-S * 0.3, -S * 0.18), Vector2(S * 0.13, S * 0.3)), mcol2.darkened(0.15))
			draw_rect(Rect2(mb + Vector2(S * 0.17, -S * 0.18), Vector2(S * 0.13, S * 0.3)), mcol2.darkened(0.15))
			draw_rect(Rect2(mb + Vector2(-S * 0.14, S * 0.06), Vector2(S * 0.1, S * 0.3)), mcol2.darkened(0.2))
			draw_rect(Rect2(mb + Vector2(S * 0.04, S * 0.06), Vector2(S * 0.1, S * 0.3)), mcol2.darkened(0.2))
			for i in 8:
				draw_rect(Rect2(P.call(i * 0.13, 0.94), Vector2(w * 0.065, h * 0.06)), Color(1.0, 0.8, 0.1) if i % 2 == 0 else OUTLINE)
		Defs.G_STEALTH:
			grad_rect(r, Color(0.04, 0.06, 0.14), pal.mid.darkened(0.3))
			poly([P.call(0.8, -0.05), P.call(0.95, -0.05), P.call(0.65, 1.0), P.call(0.2, 1.0)], Color(0.9, 0.95, 0.7, 0.15))
			for i in 4:
				draw_line(P.call(0, 0.55 + i * 0.1), P.call(1, 0.45 + i * 0.12), Color(1.0, 0.2, 0.25, 0.7), maxf(1.0, S * 0.006))
			var sc2: Vector2 = P.call(0.35, 0.75)
			poly([sc2 + Vector2(-S * 0.12, S * 0.1), sc2 + Vector2(-S * 0.05, -S * 0.15), sc2 + Vector2(S * 0.08, -S * 0.12), sc2 + Vector2(S * 0.15, S * 0.1)], Color(0.02, 0.02, 0.04))
			draw_circle(sc2 + Vector2(0, -S * 0.2), S * 0.06, Color(0.02, 0.02, 0.04))
			draw_rect(Rect2(sc2 + Vector2(-S * 0.04, -S * 0.22), Vector2(S * 0.09, S * 0.02)), Color(0.3, 1.0, 0.5))
			var rc: Vector2 = P.call(0.7, 0.4)
			draw_arc(rc, S * 0.1, 0, TAU, 24, Color(1, 1, 1, 0.6), maxf(1.0, S * 0.008))
			draw_line(rc - Vector2(S * 0.14, 0), rc + Vector2(S * 0.14, 0), Color(1, 1, 1, 0.6), 1.0)
			draw_line(rc - Vector2(0, S * 0.14), rc + Vector2(0, S * 0.14), Color(1, 1, 1, 0.6), 1.0)
		Defs.G_PUZZLE:
			grad_rect(r, pal.sky2.lightened(0.2), pal.sky1)
			var cols := 6
			var cw := w / cols
			for i in cols:
				for k in 7:
					if rng.randf() < 0.55 + k * 0.05:
						var bc2 := Color.from_ok_hsl(fposmod(pal.h + rng.randi() % 5 * 0.2, 1.0), 0.8, 0.65)
						rrect(Rect2(o + Vector2(i * cw + 1, h - (k + 1) * cw), Vector2(cw - 2, cw - 2)), cw * 0.18, bc2)
			var fb: Vector2 = P.call(0.5, 0.3)
			rrect(Rect2(fb - Vector2(S * 0.14, S * 0.14), Vector2(S * 0.28, S * 0.28)), S * 0.06, pal.accent)
			draw_circle(fb + Vector2(-S * 0.05, -S * 0.02), S * 0.03, OUTLINE)
			draw_circle(fb + Vector2(S * 0.05, -S * 0.02), S * 0.03, OUTLINE)
			draw_arc(fb + Vector2(0, S * 0.03), S * 0.05, 0.3, PI - 0.3, 8, OUTLINE, maxf(1.0, S * 0.015))
		Defs.G_FARM:
			grad_rect(r, Color(0.5, 0.8, 1.0), Color(1.0, 0.92, 0.7))
			draw_circle(P.call(0.2, 0.2), S * 0.12, Color(1.0, 0.85, 0.3))
			rays(P.call(0.2, 0.2), 12, S * 0.22, Color(1.0, 0.85, 0.3, 0.4))
			ellipse(P.call(0.5, 1.0), w * 0.9, h * 0.45, Color(0.55, 0.8, 0.35))
			for i in 6:
				draw_line(P.call(0.05 + i * 0.18, 0.62), P.call(-0.2 + i * 0.28, 1.0), Color(0.45, 0.65, 0.25), maxf(1.0, S * 0.02))
			var barn: Vector2 = P.call(0.72, 0.62)
			draw_rect(Rect2(barn - Vector2(S * 0.13, S * 0.12), Vector2(S * 0.26, S * 0.18)), Color(0.85, 0.25, 0.2))
			poly([barn + Vector2(-S * 0.16, -S * 0.12), barn + Vector2(0, -S * 0.25), barn + Vector2(S * 0.16, -S * 0.12)], Color(0.6, 0.15, 0.15))
			draw_rect(Rect2(barn - Vector2(S * 0.04, S * 0.0), Vector2(S * 0.08, S * 0.06)), Color(1, 1, 1))
			for i in 4:
				var vc: Vector2 = P.call(0.15 + i * 0.12, 0.8)
				draw_circle(vc, S * 0.035, [Color(1, 0.5, 0.1), Color(0.9, 0.15, 0.2), Color(0.6, 0.3, 0.8), Color(1, 0.85, 0.2)][i])
				draw_line(vc - Vector2(0, S * 0.03), vc - Vector2(0, S * 0.07), Color(0.3, 0.7, 0.3), maxf(1.0, S * 0.012))
	noise_overlay(r, 0.08)

# ======================================================================== parts
func paint_front(r: Rect2, t: Dictionary, edition: int) -> void:
	var pal := palette(t)
	var plat: Dictionary = Defs.PLATFORMS[t.platform]
	var w := r.size.x
	var h := r.size.y
	var banner_h := h * 0.1
	var art := Rect2(r.position + Vector2(0, banner_h), Vector2(w, h - banner_h))
	motif(art, t, pal)
	# title block
	var lines := title_lines(String(t.base) if String(t.subtitle) != "" and String(t.name).find(":") > 0 else String(t.name))
	var sub := ""
	if String(t.name).find(":") > 0:
		sub = String(t.subtitle)
	elif String(t.subtitle) != "" and String(t.name) != String(t.base):
		lines = title_lines(String(t.name))
	var fname: String = Defs.TITLE_FONTS_BY_GENRE[t.genre]
	if t.platform == Defs.P_S16:
		fname = "press-start-2p" if int(t.seed) % 3 == 0 else fname
	var big := int(h * (0.12 if lines.size() == 1 else 0.095))
	var block_h := lines.size() * big * 1.05 + (h * 0.07 if sub != "" else 0.0)
	var ty := art.position.y + h * (0.12 if edition == Defs.E_CE else 0.04)
	if int(t.genre) in [Defs.G_KART, Defs.G_MASCOT, Defs.G_SPORTS] or int(t.seed) % 4 == 0:
		ty = r.end.y - h * 0.17 - block_h
	for ln in lines:
		ty += fit_text(String(ln).to_upper() if fname != "creepster" else String(ln), Vector2(r.position.x + w * 0.05, ty), w * 0.9, big,
			pal.title if t.genre != Defs.G_HORROR else Color(0.85, 0.1, 0.1), fname, maxf(1.5, h * 0.012)) * 0.86
	if sub != "":
		fit_text(sub, Vector2(r.position.x + w * 0.1, ty + h * 0.005), w * 0.8, int(h * 0.05), Color.WHITE, "fredoka", maxf(1.0, h * 0.008))
	platform_banner(Rect2(r.position, Vector2(w, banner_h)), plat, edition)
	# rating + publisher
	rating_badge(Rect2(r.position + Vector2(w * 0.04, h * 0.84), Vector2(w * 0.13, h * 0.13)), t.rating)
	draw_circle(r.position + Vector2(w * 0.88, h * 0.9), w * 0.075, Color(1, 1, 1, 0.85))
	publisher_logo(t.publisher, r.position + Vector2(w * 0.88, h * 0.9), w * 0.11)
	if edition == Defs.E_CE:
		var rib := Rect2(r.position + Vector2(0, banner_h), Vector2(w, h * 0.07))
		grad_rect(rib, Color(0.95, 0.78, 0.3), Color(0.8, 0.55, 0.15))
		fit_text("COLLECTOR'S EDITION", rib.position + Vector2(w * 0.05, h * 0.01), w * 0.9, int(h * 0.05), Color(0.25, 0.12, 0.02), "lilita-one", 0.0)
	if int(t.discs) > 1:
		var dy := h * (0.19 if edition == Defs.E_CE else 0.115)
		rrect(Rect2(r.position + Vector2(w * 0.68, dy), Vector2(w * 0.28, h * 0.055)), h * 0.02, Color(1, 1, 1, 0.9))
		fit_text("%d DISCS" % t.discs, r.position + Vector2(w * 0.69, dy + h * 0.004), w * 0.26, int(h * 0.042), OUTLINE, "lilita-one", 0.0)
	draw_rect(r, Color(0, 0, 0, 0.25), false, maxf(1.0, w * 0.01))

func paint_steel(r: Rect2, t: Dictionary) -> void:
	# Minimal emblem art (shader turns it into embossed metal).
	var pal := palette(t)
	var w := r.size.x
	var h := r.size.y
	grad_rect(r, Color(0.25, 0.25, 0.28), Color(0.12, 0.12, 0.14))
	var c := r.position + Vector2(w * 0.5, h * 0.45)
	draw_circle(c, w * 0.32, Color(0.85, 0.85, 0.88))
	draw_circle(c, w * 0.28, Color(0.3, 0.3, 0.33))
	var inner := Rect2(c - Vector2(w * 0.26, w * 0.26), Vector2(w * 0.52, w * 0.52))
	motif(inner, t, {"seed": pal.seed, "h": pal.h, "sky1": Color(0.35, 0.35, 0.38), "sky2": Color(0.5, 0.5, 0.55),
		"accent": Color(0.95, 0.95, 0.98), "accent2": Color(0.8, 0.8, 0.85), "dark": Color(0.2, 0.2, 0.22),
		"mid": Color(0.4, 0.4, 0.44), "light": Color(0.95, 0.95, 0.97), "title": Color.WHITE}, 0.8)
	fit_text(String(t.base).to_upper(), r.position + Vector2(w * 0.08, h * 0.82), w * 0.84, int(h * 0.06), Color(0.95, 0.95, 0.98), Defs.TITLE_FONTS_BY_GENRE[t.genre], 0.0, OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, false)
	fit_text("STEELBOOK", r.position + Vector2(w * 0.3, h * 0.92), w * 0.4, int(h * 0.03), Color(0.8, 0.8, 0.85), "orbitron", 0.0, OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, false)

func paint_back(r: Rect2, t: Dictionary, edition: int) -> void:
	var pal := palette(t)
	var plat: Dictionary = Defs.PLATFORMS[t.platform]
	var w := r.size.x
	var h := r.size.y
	grad_rect(r, pal.dark.lerp(plat.case, 0.25), pal.dark)
	platform_banner(Rect2(r.position, Vector2(w, h * 0.08)), plat, edition)
	fit_text(String(t.name), r.position + Vector2(w * 0.05, h * 0.1), w * 0.9, int(h * 0.055), pal.title, Defs.TITLE_FONTS_BY_GENRE[t.genre], maxf(1.0, h * 0.006))
	# screenshots: the same motif at different zoom/offsets
	for i in 3:
		var sr := Rect2(r.position + Vector2(w * (0.05 + i * 0.31), h * 0.19), Vector2(w * 0.28, h * 0.17))
		draw_rect(sr.grow(2), Color(1, 1, 1, 0.9))
		motif(sr, t, pal, 1.8, Vector2(-0.3 - i * 0.25, -0.35 + i * 0.1))
	var big := Rect2(r.position + Vector2(w * 0.05, h * 0.38), Vector2(w * 0.9, h * 0.2))
	draw_rect(big.grow(2), Color(1, 1, 1, 0.9))
	motif(big, t, pal, 0.7, Vector2(0.0, -0.2))
	# blurb
	var f := font("fredoka-regular")
	var blurb: String = t.blurb
	var fs := int(h * 0.026)
	draw_multiline_string(f, r.position + Vector2(w * 0.06, h * 0.62 + f.get_ascent(fs)), blurb, HORIZONTAL_ALIGNMENT_LEFT, w * 0.88, fs, 4, Color(1, 1, 1, 0.92))
	var feats := ["%s" % Defs.GENRE_NAMES[t.genre], "1-4 players" if int(t.seed) % 2 == 0 else "1 player", "Released %d" % t.year]
	for i in feats.size():
		draw_circle(r.position + Vector2(w * 0.08, h * (0.76 + i * 0.035) + fs * 0.4), fs * 0.25, pal.accent)
		draw_string(f, r.position + Vector2(w * 0.11, h * (0.76 + i * 0.035) + f.get_ascent(fs)), feats[i], HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, fs, Color(1, 1, 1, 0.85))
	rating_badge(Rect2(r.position + Vector2(w * 0.05, h * 0.87), Vector2(w * 0.1, h * 0.1)), t.rating)
	publisher_logo(t.publisher, r.position + Vector2(w * 0.24, h * 0.92), w * 0.08)
	draw_string(f, r.position + Vector2(w * 0.3, h * 0.93), Defs.PUBLISHERS[t.publisher].name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.3, int(h * 0.022), Color(1, 1, 1, 0.8))
	# barcode
	var bc := Rect2(r.position + Vector2(w * 0.68, h * 0.87), Vector2(w * 0.27, h * 0.1))
	draw_rect(bc, Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = pal.seed
	var x := bc.position.x + 3
	while x < bc.end.x - 4:
		var bw := 1.0 + rng.randi() % 3
		draw_rect(Rect2(Vector2(x, bc.position.y + 3), Vector2(bw, bc.size.y * 0.7)), Color.BLACK)
		x += bw + 1 + rng.randi() % 3
	draw_string(f, bc.position + Vector2(3, bc.size.y - 2), t.gid.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, bc.size.x, int(h * 0.016), Color.BLACK)
	draw_string(f, r.position + Vector2(w * 0.05, h * 0.995), "© %d %s. Disc Chaos fictional product. Not a real game." % [t.year, Defs.PUBLISHERS[t.publisher].name], HORIZONTAL_ALIGNMENT_LEFT, w * 0.9, int(h * 0.014), Color(1, 1, 1, 0.5))

## Spine painted horizontally (u along the case height): [platform block | title | publisher].
func paint_spine(r: Rect2, t: Dictionary, edition: int) -> void:
	var pal := palette(t)
	var plat: Dictionary = Defs.PLATFORMS[t.platform]
	var w := r.size.x
	var h := r.size.y
	var base: Color = pal.dark.lerp(pal.accent, 0.15)
	if edition == Defs.E_STEEL:
		base = Color(0.55, 0.56, 0.6)
	grad_rect(r, base.lightened(0.1), base.darkened(0.1))
	var blk := Rect2(r.position, Vector2(w * 0.16, h))
	if edition == Defs.E_GH:
		grad_rect(blk, Color(1.0, 0.86, 0.35), Color(0.9, 0.62, 0.15))
	else:
		draw_rect(blk, plat.banner)
	platform_logo(plat.logo, blk.position + Vector2(blk.size.x * 0.3, h * 0.5), h * 0.7, Color(0.3, 0.18, 0.02) if edition == Defs.E_GH else plat.banner_text)
	fit_text(plat.code, blk.position + Vector2(blk.size.x * 0.52, h * 0.12), blk.size.x * 0.46, int(h * 0.6), Color(0.3, 0.18, 0.02) if edition == Defs.E_GH else plat.banner_text, "lilita-one", 0.0, OUTLINE, HORIZONTAL_ALIGNMENT_LEFT, false)
	fit_text(String(t.name), r.position + Vector2(w * 0.18, h * 0.08), w * 0.64, int(h * 0.78), pal.title.lightened(0.2), Defs.TITLE_FONTS_BY_GENRE[t.genre], maxf(1.0, h * 0.06), OUTLINE, HORIZONTAL_ALIGNMENT_LEFT, false)
	publisher_logo(t.publisher, r.position + Vector2(w * 0.9, h * 0.5), h * 0.75)
	if edition == Defs.E_CE:
		draw_rect(Rect2(r.position + Vector2(w * 0.83, 0), Vector2(w * 0.03, h)), Color(0.95, 0.78, 0.3))

func paint_label(r: Rect2, t: Dictionary, edition: int, disc: int) -> void:
	var pal := palette(t)
	var plat: Dictionary = Defs.PLATFORMS[t.platform]
	var w := r.size.x
	var h := r.size.y
	if edition == Defs.E_STEEL:
		grad_rect(r, Color(0.7, 0.72, 0.78), Color(0.45, 0.46, 0.5))
	motif(r, t, pal, 0.9, Vector2(0.0, 0.05))
	var c := r.position + r.size * 0.5
	# soft vignette ring to frame it as a disc
	draw_arc(c, w * 0.47, 0, TAU, 40, Color(0, 0, 0, 0.35), w * 0.06)
	var plate := Rect2(r.position + Vector2(w * 0.1, h * 0.66), Vector2(w * 0.8, h * 0.17))
	rrect(plate, h * 0.05, Color(pal.dark, 0.75))
	fit_text(String(t.name), plate.position + Vector2(w * 0.04, h * 0.015), plate.size.x - w * 0.08, int(h * 0.09), pal.title, Defs.TITLE_FONTS_BY_GENRE[t.genre], maxf(1.0, h * 0.008), OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, false)
	draw_circle(r.position + Vector2(w * 0.5, h * 0.14), w * 0.08, plat.banner)
	platform_logo(plat.logo, r.position + Vector2(w * 0.5, h * 0.14), w * 0.1, plat.banner_text)
	if int(t.discs) > 1:
		rrect(Rect2(r.position + Vector2(w * 0.7, h * 0.4), Vector2(w * 0.22, h * 0.17)), h * 0.04, Color.WHITE)
		fit_text("DISC", r.position + Vector2(w * 0.71, h * 0.405), w * 0.2, int(h * 0.06), OUTLINE, "lilita-one", 0.0)
		fit_text("%d/%d" % [disc + 1, t.discs], r.position + Vector2(w * 0.71, h * 0.465), w * 0.2, int(h * 0.08), OUTLINE, "lilita-one", 0.0)
	if edition == Defs.E_GH:
		draw_arc(c, w * 0.43, -2.6, -0.5, 20, Color(1.0, 0.8, 0.25), w * 0.05)
	elif edition == Defs.E_CE:
		draw_arc(c, w * 0.43, -2.6, -0.5, 20, Color(0.75, 0.45, 0.95), w * 0.05)

func paint_poster(r: Rect2, t: Dictionary) -> void:
	var pal := palette(t)
	motif(r, t, pal, 1.0)
	var lines := title_lines(String(t.name))
	var y := r.position.y + r.size.y * 0.06
	for ln in lines:
		y += fit_text(String(ln).to_upper(), Vector2(r.position.x + r.size.x * 0.06, y), r.size.x * 0.88, int(r.size.y * 0.1), pal.title, Defs.TITLE_FONTS_BY_GENRE[t.genre], maxf(2.0, r.size.y * 0.01)) * 0.86
	fit_text("COMING SOON TO %s" % Defs.PLATFORMS[t.platform].name.to_upper(), r.position + Vector2(r.size.x * 0.1, r.size.y * 0.9), r.size.x * 0.8, int(r.size.y * 0.04), Color.WHITE, "lilita-one", maxf(1.0, r.size.y * 0.004))
