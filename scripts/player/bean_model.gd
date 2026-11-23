class_name BeanModel
extends Node3D
## Wobbly bean character built from code: rounded body with pattern, big expressive eyes, stubby
## arms with mittens, and every cosmetic. Faces -Z. Feet at y = 0, about 1.35 m tall.
## Animation is procedural: spring-damped lean/squash, waddle, arm swing, emotes, ragdoll tumble.

const H := 1.32
const R := 0.37
const OUT := Color(0.12, 0.09, 0.18)

var look := {}
var body_mi: MeshInstance3D
var wobble: Node3D
var face: Node3D
var eyes: Node3D
var acc_mi: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var cape: Node3D
var backpack: Node3D
var name_label: Label3D

# animation state
var velocity := Vector3.ZERO
var on_floor := true
var emote := ""
var emote_t := 0.0
var carrying := false
var _lean := Vector2.ZERO
var _lean_v := Vector2.ZERO
var _squash := 0.0
var _squash_v := 0.0
var _walk_phase := 0.0
var _blink := 0.0
var _prev_vel := Vector3.ZERO
var _time := 0.0
var talk_t := 0.0

static var _pattern_cache := {}

func _ready() -> void:
	if look.is_empty():
		look = Profile.default_look()
	rebuild()

func apply_look(l: Dictionary) -> void:
	look = l.duplicate()
	if is_inside_tree():
		rebuild()

func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	wobble = Node3D.new()
	wobble.name = "Wobble"
	add_child(wobble)
	var col: Color = look.get("color", Color(0.3, 0.8, 0.75))
	if typeof(col) == TYPE_STRING:
		col = Color(col)
	# body
	body_mi = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = R
	cm.height = H - 0.04
	cm.radial_segments = 20
	cm.rings = 10
	body_mi.mesh = cm
	body_mi.position = Vector3(0, H * 0.5, 0)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/toon.gdshader")
	bm.set_shader_parameter("albedo", col)
	var pat: int = int(look.get("pattern", 0))
	if pat > 0:
		bm.set_shader_parameter("pattern_tex", pattern_texture(pat))
		bm.set_shader_parameter("pattern_mix", 0.85)
		bm.set_shader_parameter("pattern_scale", Vector2(3.0, 2.0))
	body_mi.material_override = bm
	wobble.add_child(body_mi)
	# face + accessories (merged, vertex colored)
	face = Node3D.new()
	face.name = "Face"
	wobble.add_child(face)
	eyes = Node3D.new()
	eyes.position = Vector3(0, 1.02, -R + 0.02)
	face.add_child(eyes)
	var ek := MeshKit.new()
	ek.ao_enabled = false
	_build_eyes(ek, int(look.get("eyes", 0)), col)
	_add_kit(eyes, ek)
	var fk := MeshKit.new()
	fk.ao_enabled = false
	_build_mouth_and_cheeks(fk, int(look.get("eyes", 0)), col)
	_add_kit(face, fk)
	var ak := MeshKit.new()
	ak.ao_enabled = false
	_build_shirt(ak, int(look.get("shirt", 0)), col)
	_build_hat(ak, int(look.get("hat", 0)))
	_build_glasses(ak, int(look.get("glasses", 0)))
	_build_scarf(ak, int(look.get("scarf", 0)))
	acc_mi = _add_kit(wobble, ak)
	backpack = Node3D.new()
	backpack.position = Vector3(0, 0.78, R - 0.02)
	wobble.add_child(backpack)
	var bk := MeshKit.new()
	bk.ao_enabled = false
	_build_backpack(bk, int(look.get("backpack", 0)))
	_add_kit(backpack, bk)
	cape = Node3D.new()
	cape.position = Vector3(0, 1.08, R * 0.75)
	wobble.add_child(cape)
	var ck := MeshKit.new()
	ck.ao_enabled = false
	_build_cape(ck, int(look.get("cape", 0)))
	_add_kit(cape, ck)
	# arms with mittens
	var glove := glove_color(int(look.get("gloves", 0)))
	arm_l = _make_arm(-1.0, col, glove, int(look.get("gloves", 0)))
	arm_r = _make_arm(1.0, col, glove, int(look.get("gloves", 0)))
	# feet
	foot_l = _make_foot(-1.0, col)
	foot_r = _make_foot(1.0, col)
	# name tag
	name_label = Label3D.new()
	name_label.text = String(look.get("name", ""))
	name_label.font = Covers.fonts.get("lilita-one")
	name_label.font_size = 48
	name_label.pixel_size = 0.004
	name_label.outline_size = 12
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0, H + 0.42, 0)
	name_label.no_depth_test = false
	name_label.visibility_range_end = 25.0
	add_child(name_label)

func set_name_visible(v: bool) -> void:
	if name_label:
		name_label.visible = v

func _add_kit(parent: Node3D, k: MeshKit) -> MeshInstance3D:
	var last: MeshInstance3D = null
	for chn in k.ch.keys():
		var mi := MeshInstance3D.new()
		mi.mesh = k.build_mesh(chn)
		if chn == "emit":
			mi.material_override = WorldBuilder.mat("emit")
		elif chn == "glass":
			mi.material_override = WorldBuilder.mat("glass")
		else:
			mi.material_override = WorldBuilder.mat("toon")
		parent.add_child(mi)
		last = mi
	return last

func _make_arm(side: float, col: Color, glove: Color, gidx: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * (R - 0.02), 0.82, 0)
	wobble.add_child(pivot)
	var k := MeshKit.new()
	k.ao_enabled = false
	k.capsule("toon", Transform3D(Basis(), Vector3(side * 0.06, -0.1, 0)), 0.075, 0.26, col.darkened(0.04), 10)
	var gc := glove
	k.sphere("toon", Transform3D(Basis(), Vector3(side * 0.07, -0.26, 0)), Vector3(0.095, 0.085, 0.095), gc, 6, 10)
	k.sphere("toon", Transform3D(Basis(), Vector3(side * 0.02, -0.24, -0.06)), Vector3(0.04, 0.04, 0.04), gc.darkened(0.05), 4, 8)
	if gidx == 8:
		k.torus("toon", Transform3D(Basis(), Vector3(side * 0.07, -0.2, 0)), 0.085, 0.018, Color.WHITE, 12, 4)
	elif gidx == 9:
		for i in 4:
			k.sphere("toon", Transform3D(Basis(), Vector3(side * 0.07, -0.26, 0) + Vector3(cos(i * 1.6) * 0.06, sin(i * 2.1) * 0.05, -0.07)), Vector3(0.015, 0.015, 0.01), Color.WHITE, 3, 6)
	_add_kit(pivot, k)
	return pivot

func _make_foot(side: float, col: Color) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(side * 0.16, 0.06, -0.04)
	add_child(n)
	var k := MeshKit.new()
	k.ao_enabled = false
	k.sphere("toon", Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(0.13, 0.08, 0.17), col.darkened(0.25), 6, 10)
	_add_kit(n, k)
	return n

static func glove_color(i: int) -> Color:
	return [Color(1.0, 0.82, 0.3), Color(0.95, 0.3, 0.3), Color(0.3, 0.5, 0.95), Color(0.35, 0.8, 0.35), Color(0.65, 0.4, 0.9),
		Color(0.18, 0.18, 0.22), Color(0.96, 0.96, 0.96), Color(1.0, 0.5, 0.7), Color(0.95, 0.5, 0.2), Color(0.3, 0.75, 0.9), Color(1.0, 0.8, 0.2)][clampi(i, 0, 10)]

# ------------------------------------------------------------------ patterns
static func pattern_texture(idx: int) -> Texture2D:
	if _pattern_cache.has(idx):
		return _pattern_cache[idx]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 99
	var W := Color(1, 1, 1, 1)
	var D := Color(0.55, 0.55, 0.6, 1)
	for y in n:
		for x in n:
			var c := Color(1, 1, 1, 0)
			var fx := float(x) / n
			var fy := float(y) / n
			match idx:
				1: # spots
					if Vector2(fposmod(fx * 2.0, 1.0) - 0.5, fposmod(fy * 2.0 + floor(fx * 2.0) * 0.5, 1.0) - 0.5).length() < 0.22: c = D
				2: # stripes
					if fposmod(fy * 4.0, 1.0) < 0.45: c = W
				3: # stars (diamonds)
					var dx := absf(fposmod(fx * 3.0, 1.0) - 0.5)
					var dy := absf(fposmod(fy * 3.0, 1.0) - 0.5)
					if dx + dy < 0.2 or (dx < 0.04 and dy < 0.3) or (dy < 0.04 and dx < 0.3): c = Color(1.0, 0.95, 0.5)
				4: # hearts
					var hx := fposmod(fx * 3.0, 1.0) - 0.5
					var hy := fposmod(fy * 3.0, 1.0) - 0.45
					var hv := pow(hx * hx + hy * hy - 0.04, 3.0) - hx * hx * hy * hy * hy * 0.5
					if hv < 0.0: c = Color(1.0, 0.4, 0.55)
				5: # checker
					if (int(fx * 6.0) + int(fy * 6.0)) % 2 == 0: c = W
				6: # zigzag
					if absf(fposmod(fy * 4.0 + absf(fposmod(fx * 4.0, 1.0) - 0.5), 1.0) - 0.5) < 0.18: c = W
				7: # polka small
					if Vector2(fposmod(fx * 5.0, 1.0) - 0.5, fposmod(fy * 5.0, 1.0) - 0.5).length() < 0.2: c = W
				8: # camo
					var v := sin(fx * 13.0 + sin(fy * 7.0) * 2.0) + sin(fy * 11.0 + cos(fx * 5.0) * 2.0)
					if v > 0.6: c = Color(0.3, 0.4, 0.25)
					elif v < -0.7: c = Color(0.55, 0.5, 0.35)
				9: # gradient (lighter top)
					c = Color(1, 1, 1, clampf(1.0 - fy * 1.3, 0.0, 1.0) * 0.8)
				10: # galaxy
					c = Color(0.2, 0.15, 0.45, 0.8)
					if rng.randf() < 0.03: c = W
				11: # freckles
					if rng.randf() < 0.012: c = Color(0.6, 0.35, 0.25)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_pattern_cache[idx] = tex
	return tex

# ------------------------------------------------------------------ face
func _build_eyes(k: MeshKit, style: int, body: Color) -> void:
	var W := Color(1, 1, 1)
	var sep := 0.11
	if style == 11:
		k.sphere("toon", Transform3D(Basis(), Vector3(0, 0.0, -0.02)), Vector3(0.1, 0.11, 0.05), W, 8, 14)
		k.sphere("toon", Transform3D(Basis(), Vector3(0, -0.005, -0.06)), Vector3(0.05, 0.055, 0.02), OUT, 6, 10)
		k.sphere("toon", Transform3D(Basis(), Vector3(0.02, 0.02, -0.075)), Vector3(0.014, 0.014, 0.01), W, 3, 6)
		return
	for s in [-1.0, 1.0]:
		var c := Vector3(s * sep, 0, -0.02)
		match style:
			0, 1, 6, 10:
				k.sphere("toon", Transform3D(Basis(), c), Vector3(0.075, 0.085, 0.045), W, 8, 12)
				var pr := 0.045 if style != 1 else 0.032
				var look_down := -0.02 if style == 10 else 0.0
				k.sphere("toon", Transform3D(Basis(), c + Vector3(s * 0.005, -0.008 + look_down, -0.04)), Vector3(pr, pr * 1.1, 0.02), OUT, 6, 10)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(s * 0.005 + 0.018, 0.02, -0.058)), Vector3(0.014, 0.014, 0.008), W, 3, 6)
				if style == 6:
					k.sphere("emit", Transform3D(Basis(), c + Vector3(-0.015, -0.025, -0.06)), Vector3(0.01, 0.01, 0.006), Color(1.5, 1.5, 1.5), 3, 6)
			2: # sleepy: half lids
				k.sphere("toon", Transform3D(Basis(), c), Vector3(0.075, 0.08, 0.045), W, 8, 12)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(0, -0.02, -0.035)), Vector3(0.035, 0.035, 0.02), OUT, 6, 10)
				k.sphere("toon", Transform3D(Basis(Vector3.RIGHT, 0.1), c + Vector3(0, 0.03, -0.01)), Vector3(0.082, 0.06, 0.052), body.darkened(0.08), 6, 12, true)
			3, 9: # grumpy / determined: angled brows
				k.sphere("toon", Transform3D(Basis(), c), Vector3(0.07, 0.075, 0.045), W, 8, 12)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(0, -0.01, -0.04)), Vector3(0.04, 0.04, 0.02), OUT, 6, 10)
				var tilt = -s * (0.45 if style == 3 else 0.25)
				k.box("toon", Transform3D(Basis(Vector3.BACK, tilt), c + Vector3(0, 0.085, -0.03)), Vector3(0.09, 0.022, 0.02), OUT, 0.008)
			4: # surprised
				k.sphere("toon", Transform3D(Basis(), c), Vector3(0.085, 0.1, 0.045), W, 8, 12)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(0, 0, -0.04)), Vector3(0.02, 0.022, 0.012), OUT, 4, 8)
			5: # wink (left closed arc)
				if s < 0:
					k.torus("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI), c + Vector3(0, -0.01, -0.03)), 0.05, 0.012, OUT, 10, 4, PI)
				else:
					k.sphere("toon", Transform3D(Basis(), c), Vector3(0.075, 0.085, 0.045), W, 8, 12)
					k.sphere("toon", Transform3D(Basis(), c + Vector3(0, -0.008, -0.04)), Vector3(0.045, 0.05, 0.02), OUT, 6, 10)
			7: # dizzy rings
				k.sphere("toon", Transform3D(Basis(), c), Vector3(0.075, 0.085, 0.04), W, 8, 12)
				for r in 3:
					k.torus("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0, -0.035)), 0.015 + r * 0.018, 0.005, OUT, 12, 3)
			8: # hearts
				var hc := Color(1.0, 0.3, 0.45)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(-0.025, 0.015, -0.01)), Vector3(0.04, 0.04, 0.03), hc, 6, 10)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(0.025, 0.015, -0.01)), Vector3(0.04, 0.04, 0.03), hc, 6, 10)
				k.box("toon", Transform3D(Basis(Vector3.BACK, PI * 0.25), c + Vector3(0, -0.015, -0.01)), Vector3(0.055, 0.055, 0.03), hc, 0.01)

func _build_mouth_and_cheeks(k: MeshKit, style: int, body: Color) -> void:
	var m := Vector3(0, 0.88, -R + 0.005)
	match style:
		3:
			k.torus("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), m + Vector3(0, -0.03, 0)), 0.045, 0.01, OUT, 10, 4, PI)
		4:
			k.sphere("toon", Transform3D(Basis(), m + Vector3(0, -0.01, 0)), Vector3(0.03, 0.04, 0.02), OUT, 6, 10)
		_:
			k.torus("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI), m + Vector3(0, 0.01, 0)), 0.05, 0.01, OUT, 10, 4, PI)
	if style in [0, 5, 8, 10, 6]:
		for s in [-1.0, 1.0]:
			k.sphere("toon", Transform3D(Basis(), Vector3(s * 0.2, 0.92, -R + 0.07)), Vector3(0.05, 0.03, 0.02), Color(1.0, 0.55, 0.6), 4, 8)

# ------------------------------------------------------------------ outfits
func _build_shirt(k: MeshKit, idx: int, body: Color) -> void:
	if idx == 0:
		return
	var palette := [Color(1, 1, 1), Color(0.95, 0.95, 0.95), Color(1.0, 0.85, 0.9), Color(0.25, 0.3, 0.5), Color(0.2, 0.2, 0.25),
		Color(1.0, 0.95, 0.6), Color(0.95, 0.4, 0.35), Color(0.4, 0.7, 0.95), Color(1.0, 0.75, 0.4), Color(0.75, 0.6, 0.95), Color(1, 1, 1), Color(0.35, 0.5, 0.85)]
	var sc: Color = palette[idx]
	k.cylinder("toon", Transform3D(Basis(), Vector3(0, 0.62, 0)), R + 0.012, 0.42, sc, 20, R + 0.006, false)
	var front := Vector3(0, 0.65, -R - 0.018)
	var fb := Basis(Vector3.RIGHT, PI * 0.5)
	match idx:
		1: # disc
			k.cylinder("toon", Transform3D(fb, front), 0.08, 0.006, Color(0.75, 0.8, 0.95), 16)
			k.cylinder("toon", Transform3D(fb, front + Vector3(0, 0, -0.004)), 0.02, 0.006, Color(0.3, 0.3, 0.4), 10)
		2:
			k.sphere("toon", Transform3D(Basis(), front + Vector3(-0.03, 0.02, 0)), Vector3(0.045, 0.045, 0.01), Color(1, 0.3, 0.45), 4, 10)
			k.sphere("toon", Transform3D(Basis(), front + Vector3(0.03, 0.02, 0)), Vector3(0.045, 0.045, 0.01), Color(1, 0.3, 0.45), 4, 10)
			k.box("toon", Transform3D(Basis(Vector3.BACK, PI * 0.25), front + Vector3(0, -0.02, 0)), Vector3(0.065, 0.065, 0.01), Color(1, 0.3, 0.45), 0.005)
		3:
			for i in 5:
				var a := -PI * 0.5 + TAU * i / 5.0
				k.box("toon", Transform3D(Basis(Vector3.BACK, a), front + Vector3(cos(a), -sin(a), 0) * 0.035), Vector3(0.07, 0.03, 0.01), Color(1.0, 0.85, 0.2), 0.005)
		4:
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.4), front + Vector3(0.0, 0.03, 0)), Vector3(0.03, 0.09, 0.01), Color(1.0, 0.85, 0.2), 0.003)
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.4), front + Vector3(0.02, -0.04, 0)), Vector3(0.03, 0.09, 0.01), Color(1.0, 0.85, 0.2), 0.003)
		5:
			k.cylinder("toon", Transform3D(fb, front), 0.07, 0.006, Color(1.0, 0.85, 0.2), 16)
			k.sphere("toon", Transform3D(Basis(), front + Vector3(-0.025, 0.02, -0.005)), Vector3(0.01, 0.015, 0.005), OUT, 3, 6)
			k.sphere("toon", Transform3D(Basis(), front + Vector3(0.025, 0.02, -0.005)), Vector3(0.01, 0.015, 0.005), OUT, 3, 6)
		6:
			for i in 4:
				k.cylinder("toon", Transform3D(Basis(), Vector3(0, 0.47 + i * 0.1, 0)), R + 0.016, 0.035, Color(0.95, 0.35, 0.35), 20)
		7:
			k.box("toon", Transform3D(Basis(), front), Vector3(0.14, 0.07, 0.01), OUT, 0.02)
			k.sphere("toon", Transform3D(Basis(), front + Vector3(0.04, 0.0, -0.006)), Vector3(0.012, 0.012, 0.005), Color(1, 0.3, 0.3), 3, 6)
		8:
			k.box("toon", Transform3D(Basis(Vector3.BACK, PI), front + Vector3(0, 0, 0)), Vector3(0.12, 0.004, 0.01), Color(0.9, 0.7, 0.3), 0.0)
			for i in 3:
				k.sphere("toon", Transform3D(Basis(), front + Vector3(-0.03 + i * 0.03, -0.02 + (i % 2) * 0.02, -0.004)), Vector3(0.015, 0.015, 0.004), Color(0.85, 0.2, 0.15), 3, 6)
		9:
			k.sphere("toon", Transform3D(Basis(), front), Vector3(0.06, 0.05, 0.01), Color(0.3, 0.3, 0.35), 4, 10)
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.4), front + Vector3(-0.04, 0.05, 0)), Vector3(0.03, 0.04, 0.01), Color(0.3, 0.3, 0.35), 0.003)
			k.box("toon", Transform3D(Basis(Vector3.BACK, -0.4), front + Vector3(0.04, 0.05, 0)), Vector3(0.03, 0.04, 0.01), Color(0.3, 0.3, 0.35), 0.003)
		10:
			for i in 5:
				k.torus("toon", Transform3D(fb, front + Vector3(0, -0.03, 0)), 0.04 + i * 0.015, 0.007, Color.from_hsv(i / 6.0, 0.7, 1.0), 14, 3, PI)
		11: # overalls
			k.box("toon", Transform3D(Basis(), front + Vector3(0, -0.02, 0.005)), Vector3(0.2, 0.16, 0.01), Color(0.35, 0.5, 0.85), 0.02)
			for s in [-1.0, 1.0]:
				k.box("toon", Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(s * 0.08, 0.84, -R + 0.01)), Vector3(0.035, 0.18, 0.012), Color(0.35, 0.5, 0.85), 0.005)
				k.sphere("toon", Transform3D(Basis(), Vector3(s * 0.08, 0.76, -R - 0.02)), Vector3(0.012, 0.012, 0.006), Color(1, 0.85, 0.3), 3, 6)

func _build_hat(k: MeshKit, idx: int) -> void:
	var top := Vector3(0, H - 0.04, 0)
	match idx:
		1: # cap
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(0.355, 0.245, 0.355), Color(0.95, 0.3, 0.3), 6, 16, true)
			k.box("toon", Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.11, -0.4)), Vector3(0.32, 0.025, 0.2), Color(0.95, 0.3, 0.3), 0.012)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.345, 0)), Vector3(0.03, 0.03, 0.03), Color.WHITE, 3, 6)
		2: # beanie
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.08, 0)), Vector3(0.37, 0.31, 0.37), Color(0.4, 0.55, 0.95), 6, 16, true)
			k.cylinder("toon", Transform3D(Basis(), Vector3(0, 1.11, 0)), 0.365, 0.08, Color(0.35, 0.45, 0.85), 18, 0.34)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.41, 0)), Vector3(0.07, 0.07, 0.07), Color.WHITE, 4, 8)
		3: # crown
			var gold := Color(1.0, 0.8, 0.25)
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.02, 0)), 0.2, 0.1, gold, 16, -1.0, false)
			for i in 6:
				var a := TAU * i / 6.0
				k.cylinder("toon", Transform3D(Basis(), top + Vector3(cos(a) * 0.19, 0.11, sin(a) * 0.19)), 0.035, 0.08, gold, 6, 0.0)
				k.sphere("toon", Transform3D(Basis(), top + Vector3(cos(a) * 0.2, 0.04, sin(a) * 0.2)), Vector3(0.02, 0.02, 0.02), Color.from_hsv(i / 6.0, 0.7, 1.0), 3, 6)
		4: # headphones
			k.torus("toon", Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), top + Vector3(0, -0.12, 0)), R + 0.02, 0.025, OUT, 18, 5, PI)
			for s in [-1.0, 1.0]:
				k.cylinder("toon", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * (R + 0.02), 1.0, 0)), 0.1, 0.07, Color(0.95, 0.35, 0.55), 14)
		5: # propeller
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(0.355, 0.245, 0.355), Color(0.3, 0.6, 0.95), 6, 16, true)
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.16, 0)), 0.012, 0.08, OUT, 6)
			k.box("toon", Transform3D(Basis(Vector3.UP, 0.4), top + Vector3(0, 0.2, 0)), Vector3(0.36, 0.01, 0.06), Color(1.0, 0.85, 0.2), 0.01)
		6: # traffic cone
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.15, 0)), 0.2, 0.42, Color(1.0, 0.5, 0.1), 16, 0.03)
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.12, 0)), 0.155, 0.08, Color.WHITE, 16, 0.135)
			k.box("toon", Transform3D(Basis(), top + Vector3(0, -0.06, 0)), Vector3(0.5, 0.04, 0.5), Color(1.0, 0.5, 0.1), 0.01)
		7: # chef hat
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.0, 0)), 0.24, 0.16, Color.WHITE, 16)
			for i in 5:
				var a := TAU * i / 5.0
				k.sphere("toon", Transform3D(Basis(), top + Vector3(cos(a) * 0.13, 0.2, sin(a) * 0.13)), Vector3(0.14, 0.13, 0.14), Color.WHITE, 6, 10)
			k.sphere("toon", Transform3D(Basis(), top + Vector3(0, 0.25, 0)), Vector3(0.15, 0.13, 0.15), Color.WHITE, 6, 10)
		8: # top hat
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, -0.04, 0)), 0.32, 0.03, OUT, 20)
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.14, 0)), 0.2, 0.36, OUT, 18)
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, 0.0, 0)), 0.205, 0.06, Color(0.85, 0.2, 0.3), 18)
		9: # cowboy
			k.cylinder("toon", Transform3D(Basis(), top + Vector3(0, -0.04, 0)), 0.45, 0.03, Color(0.65, 0.42, 0.25), 20)
			k.sphere("toon", Transform3D(Basis(), top + Vector3(0, 0.0, 0)), Vector3(0.24, 0.24, 0.22), Color(0.65, 0.42, 0.25), 6, 14, true)
		10: # horns
			for s in [-1.0, 1.0]:
				k.cylinder("toon", Transform3D(Basis(Vector3.BACK, -s * 0.5), top + Vector3(s * 0.22, -0.02, 0)), 0.06, 0.26, Color(0.98, 0.95, 0.85), 10, 0.0)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(0.355, 0.245, 0.355), Color(0.6, 0.6, 0.65), 6, 16, true)
		11: # bunny ears
			for s in [-1.0, 1.0]:
				k.capsule("toon", Transform3D(Basis(Vector3.BACK, -s * 0.18), top + Vector3(s * 0.12, 0.18, 0)), 0.06, 0.36, Color.WHITE, 10)
				k.capsule("toon", Transform3D(Basis(Vector3.BACK, -s * 0.18), top + Vector3(s * 0.12, 0.18, -0.04)), 0.03, 0.26, Color(1.0, 0.7, 0.75), 8)
		12: # party hat
			k.cylinder("toon", Transform3D(Basis(Vector3.BACK, 0.2), top + Vector3(0.03, 0.16, 0)), 0.15, 0.36, Color(0.6, 0.4, 0.95), 14, 0.0)
			k.sphere("toon", Transform3D(Basis(), top + Vector3(0.07, 0.35, 0)), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.85, 0.3), 4, 8)
		13: # halo
			k.torus("emit", Transform3D(Basis(), top + Vector3(0, 0.18, 0)), 0.2, 0.025, Color(1.4, 1.25, 0.6), 20, 6)
		14: # flower crown
			k.torus("toon", Transform3D(Basis(), top + Vector3(0, -0.06, 0)), R * 0.85, 0.02, Color(0.35, 0.7, 0.35), 20, 4)
			for i in 8:
				var a := TAU * i / 8.0
				k.sphere("toon", Transform3D(Basis(), top + Vector3(cos(a) * R * 0.85, -0.04, sin(a) * R * 0.85)), Vector3(0.045, 0.035, 0.045), Color.from_hsv(fposmod(i * 0.13, 1.0), 0.5, 1.0), 4, 8)
		15: # disc hat
			k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, 0.15), top + Vector3(0, 0.03, 0)), 0.32, 0.012, Color(0.82, 0.84, 0.92), 24)
			k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, 0.15), top + Vector3(0, 0.04, 0)), 0.06, 0.012, Color(0.3, 0.3, 0.4), 12)

func _build_glasses(k: MeshKit, idx: int) -> void:
	if idx == 0:
		return
	var c := Vector3(0, 1.02, -R - 0.03)
	var fb := Basis(Vector3.RIGHT, PI * 0.5)
	var frame := OUT
	match idx:
		1, 9:
			for s in [-1.0, 1.0]:
				k.torus("toon", Transform3D(fb, c + Vector3(s * 0.11, 0, 0)), 0.08, 0.012 if idx == 1 else 0.02, frame, 16, 4)
			k.box("toon", Transform3D(Basis(), c), Vector3(0.06, 0.012, 0.012), frame, 0.0)
		2:
			for s in [-1.0, 1.0]:
				k.box("toon", Transform3D(Basis(), c + Vector3(s * 0.11, 0, 0)), Vector3(0.16, 0.12, 0.012), frame, 0.01)
				k.plane("glass", Transform3D(Basis(), c + Vector3(s * 0.11, 0, -0.008)), Vector2(0.13, 0.09), Color.WHITE)
		3:
			for s in [-1.0, 1.0]:
				for i in 5:
					var a := -PI * 0.5 + TAU * i / 5.0
					k.box("toon", Transform3D(Basis(Vector3.BACK, a), c + Vector3(s * 0.11, 0, 0) + Vector3(cos(a), -sin(a), 0) * 0.04), Vector3(0.08, 0.035, 0.012), Color(1.0, 0.8, 0.2), 0.005)
		4:
			for s in [-1.0, 1.0]:
				var hc := Color(1.0, 0.35, 0.55)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(s * 0.11 - 0.025, 0.015, 0)), Vector3(0.045, 0.045, 0.012), hc, 4, 10)
				k.sphere("toon", Transform3D(Basis(), c + Vector3(s * 0.11 + 0.025, 0.015, 0)), Vector3(0.045, 0.045, 0.012), hc, 4, 10)
				k.box("toon", Transform3D(Basis(Vector3.BACK, PI * 0.25), c + Vector3(s * 0.11, -0.02, 0)), Vector3(0.065, 0.065, 0.012), hc, 0.005)
		5: # 3D specs
			k.box("toon", Transform3D(Basis(), c), Vector3(0.36, 0.11, 0.012), Color.WHITE, 0.01)
			k.box("emit", Transform3D(Basis(), c + Vector3(-0.1, 0, -0.008)), Vector3(0.12, 0.07, 0.004), Color(1.2, 0.2, 0.2), 0.005)
			k.box("emit", Transform3D(Basis(), c + Vector3(0.1, 0, -0.008)), Vector3(0.12, 0.07, 0.004), Color(0.2, 0.7, 1.2), 0.005)
		6: # monocle
			k.torus("toon", Transform3D(fb, c + Vector3(0.11, 0, 0)), 0.08, 0.012, Color(1.0, 0.8, 0.3), 16, 4)
			k.box("toon", Transform3D(Basis(), c + Vector3(0.18, -0.15, 0.02)), Vector3(0.006, 0.25, 0.006), Color(1.0, 0.8, 0.3), 0.0)
		7: # goggles
			k.torus("toon", Transform3D(Basis(), Vector3(0, 1.02, 0)), R + 0.01, 0.025, Color(0.35, 0.25, 0.2), 20, 4)
			for s in [-1.0, 1.0]:
				k.cylinder("toon", Transform3D(fb, c + Vector3(s * 0.11, 0, 0.0)), 0.085, 0.05, Color(0.55, 0.4, 0.3), 14)
				k.cylinder("glass", Transform3D(fb, c + Vector3(s * 0.11, 0, -0.026)), 0.07, 0.004, Color.WHITE, 14)
		8: # aviators
			for s in [-1.0, 1.0]:
				k.sphere("toon", Transform3D(Basis(), c + Vector3(s * 0.11, -0.01, 0)), Vector3(0.08, 0.07, 0.012), Color(0.25, 0.2, 0.15), 4, 12)
			k.box("toon", Transform3D(Basis(), c + Vector3(0, 0.04, 0)), Vector3(0.26, 0.01, 0.01), Color(1.0, 0.8, 0.3), 0.0)
		10: # shades
			k.box("toon", Transform3D(Basis(), c), Vector3(0.38, 0.1, 0.014), Color(0.1, 0.1, 0.12), 0.03)

func _build_scarf(k: MeshKit, idx: int) -> void:
	if idx == 0:
		return
	var n := Vector3(0, 0.86, 0)
	match idx:
		1, 2, 3:
			var c1 = [Color(0.95, 0.3, 0.3), Color(0.95, 0.3, 0.3), Color(0.5, 0.75, 0.95)][idx - 1]
			k.torus("toon", Transform3D(Basis(), n), R + 0.02, 0.06, c1, 20, 6)
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.15), n + Vector3(0.12, -0.15, -R - 0.02)), Vector3(0.1, 0.26, 0.04), c1, 0.02)
			if idx == 2:
				for i in 3:
					k.box("toon", Transform3D(Basis(Vector3.BACK, 0.15), n + Vector3(0.125, -0.08 - i * 0.07, -R - 0.045)), Vector3(0.1, 0.025, 0.01), Color.WHITE, 0.0)
		4: # bandana
			k.torus("toon", Transform3D(Basis(), n), R + 0.015, 0.035, Color(0.3, 0.45, 0.85), 20, 4)
			k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, PI) , n + Vector3(0, -0.08, -R + 0.02)), 0.1, 0.16, Color(0.3, 0.45, 0.85), 3, 0.0)
		5: # bowtie
			for s in [-1.0, 1.0]:
				k.cylinder("toon", Transform3D(Basis(Vector3.BACK, s * PI * 0.5), n + Vector3(s * 0.05, 0, -R - 0.03)), 0.045, 0.08, Color(0.9, 0.2, 0.3), 3, 0.0)
			k.sphere("toon", Transform3D(Basis(), n + Vector3(0, 0, -R - 0.035)), Vector3(0.025, 0.025, 0.02), Color(0.7, 0.1, 0.2), 3, 6)
		6: # necklace
			k.torus("toon", Transform3D(Basis(Vector3.RIGHT, -0.25), n + Vector3(0, -0.02, 0)), R + 0.01, 0.01, Color(1.0, 0.8, 0.3), 24, 4)
			k.sphere("toon", Transform3D(Basis(), n + Vector3(0, -0.1, -R - 0.03)), Vector3(0.035, 0.035, 0.02), Color(0.4, 0.8, 1.0), 4, 8)
		7: # lei
			for i in 14:
				var a := TAU * i / 14.0
				k.sphere("toon", Transform3D(Basis(), n + Vector3(cos(a) * (R + 0.02), -0.02 - absf(sin(a)) * 0.0, sin(a) * (R + 0.02))), Vector3(0.05, 0.04, 0.05), Color.from_hsv(fposmod(i * 0.15, 1.0), 0.5, 1.0), 4, 8)
		8: # tie
			k.box("toon", Transform3D(Basis(), n + Vector3(0, -0.12, -R - 0.025)), Vector3(0.06, 0.24, 0.015), Color(0.85, 0.25, 0.3), 0.01)
			k.box("toon", Transform3D(Basis(), n + Vector3(0, 0, -R - 0.03)), Vector3(0.07, 0.05, 0.02), Color(0.75, 0.2, 0.25), 0.01)
		9: # medal
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.4), n + Vector3(-0.05, -0.06, -R - 0.015)), Vector3(0.04, 0.16, 0.008), Color(0.3, 0.5, 0.95), 0.0)
			k.box("toon", Transform3D(Basis(Vector3.BACK, -0.4), n + Vector3(0.05, -0.06, -R - 0.015)), Vector3(0.04, 0.16, 0.008), Color(0.95, 0.3, 0.3), 0.0)
			k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), n + Vector3(0, -0.15, -R - 0.03)), 0.05, 0.015, Color(1.0, 0.8, 0.25), 14)
		10: # bell
			k.torus("toon", Transform3D(Basis(), n), R + 0.012, 0.025, Color(0.85, 0.25, 0.25), 20, 4)
			k.sphere("toon", Transform3D(Basis(), n + Vector3(0, -0.06, -R - 0.04)), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.82, 0.3), 5, 10)

func _build_backpack(k: MeshKit, idx: int) -> void:
	match idx:
		1:
			k.box("toon", Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.4, 0.42, 0.2), Color(0.95, 0.55, 0.25), 0.07)
			k.box("toon", Transform3D(Basis(), Vector3(0, -0.08, 0.21)), Vector3(0.3, 0.16, 0.05), Color(0.95, 0.75, 0.3), 0.03)
		2: # jetpack
			for s in [-1.0, 1.0]:
				k.cylinder("toon", Transform3D(Basis(), Vector3(s * 0.11, 0, 0.12)), 0.09, 0.42, Color(0.75, 0.78, 0.85), 14)
				k.cylinder("toon", Transform3D(Basis(), Vector3(s * 0.11, 0.26, 0.12)), 0.0, 0.12, Color(0.9, 0.3, 0.3), 14, 0.09)
				k.cylinder("emit", Transform3D(Basis(), Vector3(s * 0.11, -0.27, 0.12)), 0.06, 0.12, Color(1.5, 0.8, 0.2), 10, 0.01)
		3: # turtle shell
			k.sphere("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.06)), Vector3(0.38, 0.22, 0.42), Color(0.35, 0.65, 0.3), 6, 14, true)
			for i in 5:
				k.sphere("toon", Transform3D(Basis(), Vector3(-0.15 + i * 0.075, (i % 2) * 0.1 - 0.05, 0.24)), Vector3(0.07, 0.07, 0.03), Color(0.55, 0.8, 0.4), 4, 8)
		4: # teddy
			k.sphere("toon", Transform3D(Basis(), Vector3(0, -0.05, 0.14)), Vector3(0.18, 0.2, 0.14), Color(0.7, 0.5, 0.35), 6, 12)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 0.2, 0.15)), Vector3(0.14, 0.13, 0.12), Color(0.7, 0.5, 0.35), 6, 12)
			for s in [-1.0, 1.0]:
				k.sphere("toon", Transform3D(Basis(), Vector3(s * 0.1, 0.3, 0.15)), Vector3(0.05, 0.05, 0.04), Color(0.6, 0.42, 0.3), 4, 8)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 0.18, 0.27)), Vector3(0.05, 0.04, 0.03), Color(0.9, 0.75, 0.6), 4, 8)
		5: # guitar case
			k.box("toon", Transform3D(Basis(Vector3.BACK, 0.35), Vector3(0, 0.05, 0.1)), Vector3(0.24, 0.75, 0.12), OUT.lightened(0.15), 0.06)
		6: # rocket
			k.cylinder("toon", Transform3D(Basis(), Vector3(0, 0.05, 0.14)), 0.12, 0.45, Color.WHITE, 14)
			k.cylinder("toon", Transform3D(Basis(), Vector3(0, 0.36, 0.14)), 0.12, 0.18, Color(0.95, 0.3, 0.3), 14, 0.0)
			k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.1, 0.27)), 0.05, 0.01, Color(0.4, 0.7, 1.0), 12)
		7: # cardboard box
			k.box("toon", Transform3D(Basis(), Vector3(0, 0.02, 0.15)), Vector3(0.42, 0.42, 0.3), Color(0.8, 0.62, 0.4), 0.02)
			k.box("toon", Transform3D(Basis(), Vector3(0, 0.235, 0.15)), Vector3(0.44, 0.01, 0.06), Color(0.85, 0.78, 0.6), 0.0)
		8: # wings
			for s in [-1.0, 1.0]:
				k.sphere("toon", Transform3D(Basis(Vector3.BACK, s * 0.5), Vector3(s * 0.24, 0.12, 0.12)), Vector3(0.3, 0.14, 0.05), Color.WHITE, 6, 12)
				k.sphere("toon", Transform3D(Basis(Vector3.BACK, s * 0.3), Vector3(s * 0.2, -0.02, 0.12)), Vector3(0.22, 0.1, 0.045), Color(0.92, 0.95, 1.0), 6, 12)
		9: # balloon
			k.box("toon", Transform3D(Basis(), Vector3(0, 0.45, 0.12)), Vector3(0.005, 0.9, 0.005), Color.WHITE, 0.0)
			k.sphere("toon", Transform3D(Basis(), Vector3(0, 1.0, 0.12)), Vector3(0.2, 0.24, 0.2), Color(1.0, 0.35, 0.45), 8, 14)
		10: # disc stack
			for i in 6:
				k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.15 + i * 0.0, 0.08 + i * 0.03)), 0.16, 0.012, Color.from_hsv(i / 6.0, 0.3, 0.95), 18)

func _build_cape(k: MeshKit, idx: int) -> void:
	if idx == 0:
		return
	var cols := [Color.WHITE, Color(0.9, 0.2, 0.25), Color(0.5, 0.25, 0.7), Color(0.12, 0.15, 0.35), Color(0.9, 0.95, 1.0),
		Color(0.2, 0.18, 0.22), Color(1, 1, 1), Color(0.35, 0.65, 0.3), Color(1.0, 0.8, 0.3), Color(0.97, 0.97, 0.97), Color(1, 1, 1)]
	var c: Color = cols[idx]
	var segs := 5
	for i in segs:
		var y := -i * 0.16
		var w := 0.5 + i * 0.06
		var cc := c
		if idx == 6:
			cc = Color.from_hsv(i / float(segs), 0.6, 1.0)
		elif idx == 10:
			cc = Color.WHITE if i % 2 == 0 else OUT
		k.box("toon", Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, y - 0.08, i * 0.02)), Vector3(w, 0.17, 0.02), cc, 0.008)
	if idx == 3:
		for i in 7:
			k.sphere("emit", Transform3D(Basis(), Vector3(-0.2 + i * 0.07, -0.15 - (i % 3) * 0.2, 0.08)), Vector3(0.015, 0.015, 0.01), Color(1.5, 1.4, 0.8), 3, 6)
	if idx == 5:
		for s in [-1.0, 1.0]:
			k.box("toon", Transform3D(Basis(Vector3.BACK, s * 0.6), Vector3(s * 0.32, -0.1, 0.03)), Vector3(0.25, 0.08, 0.02), c, 0.01)

# ------------------------------------------------------------------ animation
## Called every frame by the owner. vel = world velocity; yaw is applied by the owner.
func animate(delta: float, vel: Vector3, grounded: bool) -> void:
	_time += delta
	var local_vel := global_transform.basis.inverse() * vel
	var accel := (vel - _prev_vel) / maxf(delta, 0.001)
	_prev_vel = vel
	var acc_local := global_transform.basis.inverse() * accel
	# spring lean toward movement / against acceleration
	var target := Vector2(clampf(-local_vel.z * 0.06 - acc_local.z * 0.012, -0.35, 0.35), clampf(local_vel.x * 0.05 + acc_local.x * 0.01, -0.3, 0.3))
	_lean_v += (target - _lean) * 120.0 * delta
	_lean_v *= exp(-9.0 * delta)
	_lean += _lean_v * delta
	# squash on landing
	if grounded and not on_floor:
		_squash_v -= clampf(-_prev_vel.y, 0.0, 8.0) * 0.6
	on_floor = grounded
	_squash_v += (-_squash) * 220.0 * delta
	_squash_v *= exp(-10.0 * delta)
	_squash += _squash_v * delta
	var speed := Vector2(vel.x, vel.z).length()
	_walk_phase += delta * (4.0 + speed * 2.6) * (1.0 if speed > 0.2 else 0.0)
	var waddle := sin(_walk_phase) * minf(speed, 4.0) * 0.035
	var bob := absf(sin(_walk_phase)) * minf(speed, 4.0) * 0.018
	var breathe := sin(_time * 2.2) * 0.012
	wobble.rotation = Vector3(-_lean.x, 0, -_lean.y + waddle)
	var sq := clampf(_squash + breathe, -0.25, 0.25)
	wobble.scale = Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)
	wobble.position.y = bob
	# feet
	var step := sin(_walk_phase) * minf(speed, 4.0) * 0.06
	if foot_l:
		foot_l.position = Vector3(-0.16, 0.06 + maxf(0.0, step) * 0.6, -0.04 - step)
		foot_r.position = Vector3(0.16, 0.06 + maxf(0.0, -step) * 0.6, -0.04 + step)
	# arms
	var swing := sin(_walk_phase) * minf(speed, 4.0) * 0.18
	var la := Vector3(swing, 0, -0.25)
	var ra := Vector3(-swing, 0, 0.25)
	if carrying:
		la = Vector3(-1.3, 0.2, -0.1)
		ra = Vector3(-1.3, -0.2, 0.1)
	if not grounded:
		la = Vector3(0, 0, -1.2 + sin(_time * 20.0) * 0.2)
		ra = Vector3(0, 0, 1.2 - sin(_time * 20.0) * 0.2)
	if emote != "":
		emote_t += delta
		var t := emote_t
		match emote:
			"wave":
				ra = Vector3(0, 0, 2.6 + sin(t * 12.0) * 0.35)
			"dance":
				la = Vector3(0, 0, -2.2 + sin(t * 10.0) * 0.6)
				ra = Vector3(0, 0, 2.2 + sin(t * 10.0 + 1.5) * 0.6)
				wobble.rotation.y = sin(t * 8.0) * 0.5
				wobble.position.y = absf(sin(t * 8.0)) * 0.12
			"point":
				ra = Vector3(-1.5, 0, 0.1)
			"facepalm":
				ra = Vector3(-2.3, 0.6, 0.6)
				wobble.rotation.x = 0.25
			"cheer":
				la = Vector3(0, 0, -2.8)
				ra = Vector3(0, 0, 2.8)
				wobble.position.y = absf(sin(t * 9.0)) * 0.18
			"shrug":
				la = Vector3(0, 0, -1.0 - sin(t * 6.0) * 0.2)
				ra = Vector3(0, 0, 1.0 + sin(t * 6.0) * 0.2)
		if emote_t > 2.6:
			emote = ""
	if arm_l:
		arm_l.rotation = arm_l.rotation.lerp(la, clampf(delta * 14.0, 0.0, 1.0))
		arm_r.rotation = arm_r.rotation.lerp(ra, clampf(delta * 14.0, 0.0, 1.0))
	# cape & backpack sway
	if cape:
		cape.rotation.x = clampf(-local_vel.z * 0.12, -0.2, 1.1) + sin(_time * 3.0) * 0.05
	# blink
	_blink -= delta
	if _blink < 0.0:
		_blink = randf_range(2.0, 5.0)
	if eyes:
		eyes.scale.y = 0.1 if _blink < 0.12 else 1.0
	if talk_t > 0.0:
		talk_t -= delta

func play_emote(e: String) -> void:
	emote = e
	emote_t = 0.0

func bump(strength: float) -> void:
	_squash_v -= strength
	_lean_v += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * 2.0
