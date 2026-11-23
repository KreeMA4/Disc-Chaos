class_name WorldBuilder
extends RefCounted
## Builds the 3D level from LevelLayout + LevelState: merged prop meshes (few draw calls),
## walls with doors/windows, floors, ceilings, shelves with A-Z dividers & banners, posters,
## stash props, lights, environment and collision.

const MERGE_CHUNK := 8.0
## Small clutter merged into short-visibility-range meshes (cheap LOD: they vanish at distance).
const DETAIL_PROPS := ["snack", "soda", "cable", "controller", "headphones", "cushion", "pizza_box", "books", "plant_small", "trophy", "ball", "laundry", "skateboard", "shopping_basket", "cobweb"]

static var _mats := {}

static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: Material
	match name:
		"toon":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/toon.gdshader")
		"toon_nocull":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/toon.gdshader")
		"emit":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/emissive.gdshader")
		"glass":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/glass.gdshader")
		"sky":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/sky_window.gdshader")
		"blob":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/blob_shadow.gdshader")
		"ghost":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/ghost.gdshader")
		"outline":
			m = ShaderMaterial.new()
			m.shader = load("res://shaders/outline.gdshader")
		_:
			if name.begins_with("screen"):
				m = ShaderMaterial.new()
				m.shader = load("res://shaders/screen.gdshader")
				(m as ShaderMaterial).set_shader_parameter("seed", float(name.substr(6)) * 1.37)
	_mats[name] = m
	return m

static func toon_with_outline() -> Material:
	var key := "toon_outlined"
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = (mat("toon") as ShaderMaterial).duplicate()
	var o: ShaderMaterial = mat("outline")
	m.next_pass = o
	_mats[key] = m
	return m

# ======================================================================== entry
static func build(root: Node3D, L: LevelLayout, st: LevelState, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131 + 7
	var pd := Settings.preset()
	var out := {"stash_nodes": {}, "mirror": null, "sun": null, "env": null, "screens": []}
	_environment(root, L, pd, out)
	var statics := StaticBody3D.new()
	statics.name = "WorldCollision"
	statics.collision_layer = Defs.LAYER_WORLD
	statics.collision_mask = 0
	root.add_child(statics)
	# --- architecture
	var arch := MeshKit.new()
	arch.ao_strength = 0.3
	for r in L.rooms:
		_floor(arch, r, rng, statics)
		_ceiling(arch, r, statics)
	for seg in L.wall_segments():
		_wall(arch, seg, L, rng, statics)
	for w in L.windows:
		_window(arch, w, L, rng)
	_emit_kit(root, arch, "Architecture", false, pd)
	# --- props, merged per chunk
	var kits := {}
	var blobs := MeshKit.new()
	blobs.uv_mode = true
	blobs.ao_enabled = false
	var screen_i := 0
	for i in L.props.size():
		var pr: Dictionary = L.props[i]
		var t: String = pr.type
		if t == "poster":
			_poster(root, pr, rng)
			continue
		if t == "label":
			_label(root, pr)
			continue
		if pr.has("stash"):
			out.stash_nodes[pr.stash] = _stash_node(root, pr, rng, statics, pd)
			continue
		var c := Vector2i(floori(pr.pos.x / MERGE_CHUNK), floori(pr.pos.z / MERGE_CHUNK))
		var detail: bool = t in DETAIL_PROPS
		var kc: Variant = c if not detail else Vector3i(c.x, c.y, 1)
		if not kits.has(kc):
			kits[kc] = MeshKit.new()
		var k: MeshKit = kits[kc]
		k.ao_floor = 0.0
		k.remap = {"screen": "screen%d" % (screen_i % 4)}
		screen_i += 1
		var xf := Transform3D(Basis(Vector3.UP, pr.yaw), pr.pos)
		if rng.randf() > float(pd.detail) and t in ["snack", "soda", "cable", "controller", "headphones", "cushion"]:
			continue
		PropFactory.build(k, t, xf, pr.params, rng)
		if pr.obstacle >= 0:
			var box: AABB = L.obstacles[pr.obstacle]
			_collider(statics, box)
			if box.position.y < 0.05:
				_blob(blobs, Vector3(box.get_center().x, 0.012, box.get_center().z), Vector2(box.size.x + 0.35, box.size.z + 0.35))
	for c in kits:
		var detail_kit: bool = c is Vector3i
		var nodes := _emit_kit(root, kits[c], "Props_%d_%d%s" % [c.x, c.y, "_detail" if detail_kit else ""], true, pd)
		for n in nodes:
			n.visibility_range_end = (11.0 if detail_kit else 34.0) * float(pd.vis_mult)
			n.visibility_range_end_margin = 1.5
			if detail_kit:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# --- shelves
	var shelf_kit := MeshKit.new()
	for i in L.shelf_slots.size():
		var slot: Dictionary = L.shelf_slots[i]
		_shelf_unit(shelf_kit, slot, rng, statics, slot.used, L.name in ["store", "warehouse"])
		_blob(blobs, Vector3(slot.pos.x, 0.012, slot.pos.z), Vector2(1.5, 0.6))
	_shelf_labels(root, shelf_kit, L, st)
	_emit_kit(root, shelf_kit, "Shelves", true, pd)
	# blob shadows
	var bm := blobs.build_mesh("m")
	if bm:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat("blob")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "BlobShadows"
		root.add_child(mi)
	# --- lights
	var lights: Array = L.lights.duplicate()
	lights.sort_custom(func(a, b): return a.energy * a.range > b.energy * b.range)
	var budget: int = pd.lights
	if L.name == "store" or L.name == "warehouse":
		budget = int(budget * 2.5)
	for i in mini(lights.size(), budget):
		var l: Dictionary = lights[i]
		var o := OmniLight3D.new()
		o.position = l.pos
		o.light_color = l.color
		o.light_energy = l.energy
		o.omni_range = l.range
		o.omni_attenuation = 1.2
		o.shadow_enabled = false
		o.light_specular = 0.3
		o.distance_fade_enabled = true
		o.distance_fade_begin = 18.0
		o.distance_fade_length = 6.0
		root.add_child(o)
	# --- mirror
	if not L.mirror.is_empty():
		out.mirror = _mirror(root, L.mirror, pd)
	return out

# ======================================================================== environment
static func _environment(root: Node3D, L: LevelLayout, pd: Dictionary, out: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = L.env.sky_top
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = L.env.ambient
	env.ambient_light_energy = L.env.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = pd.glow
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.03
	if L.env.fog:
		env.fog_enabled = true
		env.fog_light_color = L.env.fog_color
		env.fog_density = L.env.fog_density
		env.fog_aerial_perspective = 0.0
	we.environment = env
	root.add_child(we)
	out.env = env
	if L.env.get("dust", false) and int(Settings.get_value("preset")) >= 1:
		var dust := GPUParticles3D.new()
		dust.amount = 220 if int(Settings.get_value("preset")) >= 2 else 110
		dust.lifetime = 9.0
		dust.preprocess = 9.0
		dust.visibility_aabb = AABB(Vector3(L.bounds.position.x, 0, L.bounds.position.y), Vector3(L.bounds.size.x, 3.0, L.bounds.size.y))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(L.bounds.size.x * 0.5, 1.3, L.bounds.size.y * 0.5)
		pm.gravity = Vector3(0, -0.01, 0)
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.05
		pm.direction = Vector3(1, 0.2, 0)
		pm.spread = 180.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.3
		pm.scale_min = 0.5
		pm.scale_max = 1.2
		dust.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.012, 0.012)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(1.0, 0.92, 0.75, 0.55)
		qm.material = dm
		dust.draw_pass_1 = qm
		dust.position = Vector3(L.bounds.get_center().x, 1.4, L.bounds.get_center().y)
		dust.name = "Dust"
		root.add_child(dust)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 38, 0)
	sun.light_color = L.env.sun
	sun.light_energy = L.env.sun_energy
	sun.shadow_enabled = pd.shadows
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if L.bounds.get_area() < 90.0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 14.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.light_specular = 0.25
	root.add_child(sun)
	out.sun = sun

# ======================================================================== architecture
static func _collider(statics: StaticBody3D, box: AABB) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position = box.get_center()
	statics.add_child(cs)

static func _floor(k: MeshKit, r: Dictionary, rng: RandomNumberGenerator, statics: StaticBody3D) -> void:
	var rect: Rect2 = r.rect
	var style: String = r.floor
	var y := -0.05
	_collider(statics, AABB(Vector3(rect.position.x - 0.3, -0.4, rect.position.y - 0.3), Vector3(rect.size.x + 0.6, 0.4, rect.size.y + 0.6)))
	match style:
		"wood", "attic":
			var base := Color(0.78, 0.56, 0.36) if style == "wood" else Color(0.62, 0.46, 0.32)
			var pw := 0.22
			var n := int(ceil(rect.size.x / pw))
			for i in n:
				var x := rect.position.x + (i + 0.5) * pw
				var w := minf(pw, rect.end.x - (x - pw * 0.5))
				var col := base.lerp(base.darkened(0.18), rng.randf())
				var z0 := rect.position.y
				while z0 < rect.end.y - 0.01:
					var len := minf(rng.randf_range(1.2, 2.6), rect.end.y - z0)
					k.box("toon", Transform3D(Basis(), Vector3(x, y, z0 + len * 0.5)), Vector3(w - 0.006, 0.1, len - 0.006), col, 0.0)
					col = base.lerp(base.darkened(0.2), rng.randf())
					z0 += len
		"tile":
			var ts := 0.6
			k.box("toon", Transform3D(Basis(), Vector3(rect.get_center().x, -0.06, rect.get_center().y)), Vector3(rect.size.x, 0.1, rect.size.y), Color(0.55, 0.5, 0.48), 0.0)
			var ca: Color = r.get("tile_a", Color(0.96, 0.9, 0.78))
			var cb: Color = r.get("tile_b", Color(0.62, 0.8, 0.82))
			var up := Vector3.UP
			for i in int(ceil(rect.size.x / ts)):
				for j in int(ceil(rect.size.y / ts)):
					var col: Color = ca if (i + j) % 2 == 0 else cb
					col = col.darkened(rng.randf() * 0.04)
					var x0: float = rect.position.x + i * ts + 0.008
					var z0: float = rect.position.y + j * ts + 0.008
					var x1: float = minf(rect.position.x + (i + 1) * ts, rect.end.x) - 0.008
					var z1: float = minf(rect.position.y + (j + 1) * ts, rect.end.y) - 0.008
					k.quad("toon", Vector3(x0, -0.005, z0), Vector3(x1, -0.005, z0), Vector3(x1, -0.005, z1), Vector3(x0, -0.005, z1), up, col)
		"carpet":
			k.box("toon", Transform3D(Basis(), Vector3(rect.get_center().x, y, rect.get_center().y)), Vector3(rect.size.x, 0.1, rect.size.y), r.get("carpet", Color(0.55, 0.62, 0.78)), 0.0)
		"concrete":
			var tsz := 1.0
			for i in int(ceil(rect.size.x / tsz)):
				for j in int(ceil(rect.size.y / tsz)):
					var col := Color(0.66, 0.66, 0.68).lerp(Color(0.58, 0.58, 0.6), rng.randf())
					var c := Vector3(rect.position.x + (i + 0.5) * tsz, y, rect.position.y + (j + 0.5) * tsz)
					var sz := Vector3(minf(tsz, rect.end.x - (c.x - tsz * 0.5)) - 0.01, 0.1, minf(tsz, rect.end.y - (c.z - tsz * 0.5)) - 0.01)
					k.box("toon", Transform3D(Basis(), c + Vector3((sz.x - tsz) * 0.5 + 0.005, 0, (sz.z - tsz) * 0.5 + 0.005)), sz, col, 0.0)
		_:
			k.box("toon", Transform3D(Basis(), Vector3(rect.get_center().x, y, rect.get_center().y)), Vector3(rect.size.x, 0.1, rect.size.y), Color(0.8, 0.7, 0.6), 0.0)

static func _ceiling(k: MeshKit, r: Dictionary, statics: StaticBody3D) -> void:
	var rect: Rect2 = r.rect
	var h: float = r.height
	k.box("ceiling", Transform3D(Basis(), Vector3(rect.get_center().x, h + 0.05, rect.get_center().y)), Vector3(rect.size.x + 0.2, 0.1, rect.size.y + 0.2), r.ceiling, 0.0)
	_collider(statics, AABB(Vector3(rect.position.x, h, rect.position.y), Vector3(rect.size.x, 0.3, rect.size.y)))

static func _wall(k: MeshKit, seg: Dictionary, L: LevelLayout, rng: RandomNumberGenerator, statics: StaticBody3D) -> void:
	var a: Vector2 = seg.a
	var dir: Vector2 = seg.dir
	var length: float = seg.len
	var h: float = seg.h
	var col: Color = seg.color
	var room: Dictionary = L.rooms[seg.room]
	var yaw := -atan2(dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	var holes: Array = seg.holes.duplicate()
	holes.sort_custom(func(x, y): return x.t0 < y.t0)
	var pieces: Array = [] # [t0, t1, y0, y1]
	var t := 0.0
	for ho in holes:
		var t0 := clampf(ho.t0, 0.0, length)
		var t1 := clampf(ho.t1, 0.0, length)
		if t0 > t:
			pieces.append([t, t0, 0.0, h])
		if ho.y0 > 0.01:
			pieces.append([t0, t1, 0.0, ho.y0])
		if ho.y1 < h:
			pieces.append([t0, t1, ho.y1, h])
		t = maxf(t, t1)
	if t < length:
		pieces.append([t, length, 0.0, h])
	var wt := LevelLayout.WALL_T
	var style: String = room.get("wall_style", "plain")
	var lower := col.darkened(0.12).lerp(Color(0.95, 0.9, 0.82), 0.2)
	for pc in pieces:
		var mid_t: float = (pc[0] + pc[1]) * 0.5
		var w: float = pc[1] - pc[0]
		if w < 0.01:
			continue
		var y0: float = pc[2]
		var y1: float = pc[3]
		var p2 := a + dir * mid_t
		# wainscot below 0.95 m, wall color above
		var split := 0.95
		if y0 < split and y1 > split and style != "bare":
			k.box("toon", Transform3D(basis, Vector3(p2.x, (y0 + split) * 0.5, p2.y)), Vector3(w, split - y0, wt), lower, 0.0)
			_wall_upper(k, basis, p2, w, split, y1, wt, col, style, rng)
			k.box("toon", Transform3D(basis, Vector3(p2.x, split, p2.y)), Vector3(w, 0.04, wt + 0.04), room.trim, 0.01)
		else:
			_wall_upper(k, basis, p2, w, y0, y1, wt, col if y0 >= split or style == "bare" else lower, style if y0 >= split else "plain", rng)
		if y0 < 0.01:
			k.box("toon", Transform3D(basis, Vector3(p2.x, 0.06, p2.y)), Vector3(w, 0.12, wt + 0.05), room.trim.darkened(0.05), 0.01)
		if y1 >= h - 0.01:
			k.box("toon", Transform3D(basis, Vector3(p2.x, h - 0.04, p2.y)), Vector3(w, 0.08, wt + 0.06), room.trim, 0.01)
		# collision
		var ext := LevelLayout._rotated_extent(Vector3(w, y1 - y0, wt + 0.04), yaw)
		_collider(statics, AABB(Vector3(p2.x - ext.x * 0.5, y0, p2.y - ext.z * 0.5), Vector3(ext.x, y1 - y0, ext.z)))
		if w > 0.8 and y1 - y0 > 1.2:
			_occluder(statics.get_parent(), Transform3D(basis, Vector3(p2.x, (y0 + y1) * 0.5, p2.y)), Vector3(w, y1 - y0, 0.05))
	# door frames
	for ho in holes:
		if ho.window:
			continue
		var pm = a + dir * ((ho.t0 + ho.t1) * 0.5)
		var dw: float = ho.t1 - ho.t0
		for s in [-1.0, 1.0]:
			var pp = pm + dir * (dw * 0.5 * s)
			k.box("toon", Transform3D(basis, Vector3(pp.x, ho.y1 * 0.5, pp.y)), Vector3(0.08, ho.y1, wt + 0.06), room.trim, 0.01)
		k.box("toon", Transform3D(basis, Vector3(pm.x, ho.y1, pm.y)), Vector3(dw + 0.16, 0.08, wt + 0.06), room.trim, 0.01)

static func _wall_upper(k: MeshKit, basis: Basis, p2: Vector2, w: float, y0: float, y1: float, wt: float, col: Color, style: String, rng: RandomNumberGenerator) -> void:
	if style == "stripes" and w > 0.3:
		var n := int(round(w / 0.22))
		var sw := w / n
		for i in n:
			var off := -w * 0.5 + (i + 0.5) * sw
			var pc := Vector3(p2.x, (y0 + y1) * 0.5, p2.y) + basis * Vector3(off, 0, 0)
			k.box("toon", Transform3D(basis, pc), Vector3(sw, y1 - y0, wt), col if i % 2 == 0 else col.lightened(0.12), 0.0)
	elif style == "planks" and w > 0.3:
		var n2 := int(round((y1 - y0) / 0.2))
		var ph := (y1 - y0) / maxi(n2, 1)
		for i in n2:
			var pc2 := Vector3(p2.x, y0 + (i + 0.5) * ph, p2.y)
			k.box("toon", Transform3D(basis, pc2), Vector3(w, ph - 0.008, wt), col.lerp(col.darkened(0.15), rng.randf()), 0.003)
	else:
		k.box("toon", Transform3D(basis, Vector3(p2.x, (y0 + y1) * 0.5, p2.y)), Vector3(w, y1 - y0, wt), col, 0.0)

static func _window(k: MeshKit, w: Dictionary, L: LevelLayout, rng: RandomNumberGenerator) -> void:
	# find the wall orientation at this window
	var room := L.room_at(w.pos + Vector2(0.05, 0.05))
	var axis_x := false
	for r in L.rooms:
		var rect: Rect2 = r.rect
		if absf(w.pos.y - rect.position.y) < 0.05 or absf(w.pos.y - rect.end.y) < 0.05:
			axis_x = true
	var yaw := 0.0 if axis_x else PI * 0.5
	var basis := Basis(Vector3.UP, yaw)
	var c := Vector3(w.pos.x, w.sill + w.height * 0.5, w.pos.y)
	var inward := Vector3.ZERO
	# inward normal: towards the room center
	var rc := L.bounds.get_center()
	for r in L.rooms:
		var rect: Rect2 = r.rect
		if rect.grow(0.1).has_point(w.pos):
			rc = rect.get_center()
	var to_c := Vector3(rc.x - w.pos.x, 0, rc.y - w.pos.y)
	inward = (basis * Vector3.BACK) * signf((basis * Vector3.BACK).dot(to_c))
	var trim := Color(0.98, 0.97, 0.94)
	var fw := 0.07
	k.box("toon", Transform3D(basis, c + Vector3(0, w.height * 0.5, 0)), Vector3(w.width + fw * 2, fw, 0.2), trim, 0.01)
	k.box("toon", Transform3D(basis, c - Vector3(0, w.height * 0.5, 0) + inward * 0.06), Vector3(w.width + fw * 3, fw, 0.32), trim, 0.01)
	for s in [-1.0, 1.0]:
		k.box("toon", Transform3D(basis, c + basis * Vector3(s * (w.width * 0.5 + fw * 0.5), 0, 0)), Vector3(fw, w.height + fw, 0.2), trim, 0.01)
	k.box("toon", Transform3D(basis, c), Vector3(0.04, w.height, 0.05), trim, 0.005)
	k.box("toon", Transform3D(basis, c), Vector3(w.width, 0.04, 0.05), trim, 0.005)
	# sky plane outside
	var outward := -inward
	k.plane("sky", Transform3D(Basis.looking_at(inward, Vector3.UP), c + outward * 0.9) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), Vector2(w.width + 2.2, w.height + 1.6), Color.WHITE, false, 0)
	k.plane("glass", Transform3D(basis, c), Vector2(w.width, w.height), Color(0.8, 0.9, 1.0), true)
	# curtains
	var cc := Color.from_hsv(rng.randf(), 0.35, 0.95)
	for s in [-1.0, 1.0]:
		var cp := c + basis * Vector3(s * (w.width * 0.5 + 0.18), 0.1, 0) + inward * 0.12
		k.box("toon", Transform3D(basis, cp), Vector3(0.3, w.height + 0.5, 0.05), cc, 0.02)
		for f in 3:
			k.box("toon", Transform3D(basis, cp + basis * Vector3(-0.1 + f * 0.1, 0, 0.02)), Vector3(0.04, w.height + 0.48, 0.05), cc.darkened(0.08), 0.02)
	k.box("toon", Transform3D(basis, c + Vector3(0, w.height * 0.5 + 0.18, 0) + inward * 0.14), Vector3(w.width + 0.9, 0.03, 0.03), Color(0.4, 0.3, 0.25), 0.01)

static func _blob(k: MeshKit, center: Vector3, size: Vector2) -> void:
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), center)
	k.plane("m", xf, size, Color(1, 1, 1, 1), false, 0)

static func _occluder(root: Node, xf: Transform3D, size: Vector3) -> void:
	var oi := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = size
	oi.occluder = bo
	oi.transform = xf
	root.add_child(oi)

# ======================================================================== emitting merged meshes
static func _emit_kit(root: Node3D, k: MeshKit, base_name: String, casts: bool, pd: Dictionary) -> Array:
	var out: Array = []
	for chn in k.ch.keys():
		var m := k.build_mesh(chn)
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.name = "%s_%s" % [base_name, chn]
		match chn:
			"toon":
				mi.material_override = toon_with_outline() if pd.outlines and base_name.begins_with("Props") else mat("toon")
			"ceiling":
				mi.material_override = mat("toon")
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"emit":
				mi.material_override = mat("emit")
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"glass":
				mi.material_override = mat("glass")
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"sky":
				mi.material_override = mat("sky")
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_:
				mi.material_override = mat(chn)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not casts and chn == "toon" and base_name == "Architecture":
			# walls must not block the overhead key light from reaching the room
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		out.append(mi)
	return out

# ======================================================================== shelves
static func _shelf_unit(k: MeshKit, slot: Dictionary, rng: RandomNumberGenerator, statics: StaticBody3D, used: bool, merch := false) -> void:
	var u: Dictionary = ShelfPlanner.UNITS[slot.type]
	var xf := ShelfPlanner.unit_xf(slot)
	var W: float = u.width
	var D: float = u.depth
	var H: float = u.height
	var wood := Color(0.93, 0.88, 0.8) if slot.type != "cabinet" else Color(0.3, 0.24, 0.22)
	if slot.type == "tall_shelf":
		wood = Color(0.7, 0.5, 0.34)
	var post := ShelfPlanner.POST
	# sides, back, top, base
	for s in [-1.0, 1.0]:
		k.box("toon", xf * Transform3D(Basis(), Vector3(s * (W * 0.5 - post * 0.5), H * 0.5, 0)), Vector3(post, H, D + 0.02), wood.darkened(0.05), 0.0)
	k.box("toon", xf * Transform3D(Basis(), Vector3(0, H * 0.5, -D * 0.5 + 0.01)), Vector3(W, H, 0.02), wood.darkened(0.15), 0.0)
	k.box("toon", xf * Transform3D(Basis(), Vector3(0, H - 0.015, 0)), Vector3(W + 0.04, 0.03, D + 0.04), wood, 0.0)
	k.box("toon", xf * Transform3D(Basis(), Vector3(0, u.base * 0.5, 0.0)), Vector3(W, u.base, D), wood.darkened(0.1), 0.0)
	for r in int(u.rows):
		var y: float = u.base + r * u.row_h
		k.box("toon", xf * Transform3D(Basis(), Vector3(0, y, 0)), Vector3(W - post * 2, u.board, D), wood, 0.0)
	if slot.type == "cabinet":
		k.plane("glass", xf * Transform3D(Basis(), Vector3(0, H * 0.5, D * 0.5 + 0.02)), Vector2(W - 0.02, H - 0.1), Color.WHITE, true)
		k.box("emit", xf * Transform3D(Basis(), Vector3(0, H - 0.04, D * 0.3)), Vector3(W - 0.15, 0.015, 0.02), Color(1.0, 0.95, 0.85) * 1.4, 0.0)
	var ext := LevelLayout._rotated_extent(Vector3(W, H, D), slot.yaw)
	_collider(statics, AABB(Vector3(slot.pos.x - ext.x * 0.5, 0, slot.pos.z - ext.z * 0.5), Vector3(ext.x, u.base + 0.01, ext.z)))
	for s in [-1.0, 1.0]:
		var sp: Vector3 = xf * Vector3(s * (W * 0.5 - post * 0.5), 0, 0)
		var pext := LevelLayout._rotated_extent(Vector3(post, H, D), slot.yaw)
		_collider(statics, AABB(Vector3(sp.x - pext.x * 0.5, 0, sp.z - pext.z * 0.5), Vector3(pext.x, H, pext.z)))
	_occluder(statics.get_parent(), xf * Transform3D(Basis(), Vector3(0, H * 0.5, -D * 0.5 + 0.01)), Vector3(W - 0.05, H - 0.05, 0.02))
	var backp: Vector3 = xf * Vector3(0, 0, -D * 0.5 + 0.01)
	var back_ext := LevelLayout._rotated_extent(Vector3(W, H, 0.04), slot.yaw)
	_collider(statics, AABB(Vector3(backp.x - back_ext.x * 0.5, 0, backp.z - back_ext.z * 0.5), Vector3(back_ext.x, H, back_ext.z)))
	for r in int(u.rows):
		var y2: float = u.base + r * u.row_h
		var bp: Vector3 = xf * Vector3(0, y2, 0)
		_collider(statics, AABB(Vector3(slot.pos.x - ext.x * 0.5, y2 - u.board * 0.5, slot.pos.z - ext.z * 0.5), Vector3(ext.x, u.board, ext.z)))
	if not used:
		# decorative unit: books, figurines, plants on its rows
		for r in int(u.rows):
			var y3: float = u.base + r * u.row_h + u.board * 0.5
			var x := -W * 0.5 + post + 0.03
			while x < W * 0.5 - post - 0.2:
				var pick := rng.randf()
				var lxf := xf * Transform3D(Basis(), Vector3(x + 0.1, y3, -0.02))
				if merch:
					# boxed consoles, controllers and accessories for sale
					var bw := rng.randf_range(0.14, 0.3)
					var bh := rng.randf_range(0.1, minf(0.26, float(u.row_h) - 0.06))
					var bc := Color.from_hsv(rng.randf(), 0.55, 0.9)
					k.box("toon", xf * Transform3D(Basis(), Vector3(x + bw * 0.5, y3 + bh * 0.5, -0.03)), Vector3(bw, bh, 0.2), bc, 0.0)
					k.box("toon", xf * Transform3D(Basis(), Vector3(x + bw * 0.5, y3 + bh * 0.6, 0.071)), Vector3(bw * 0.7, bh * 0.35, 0.002), bc.lightened(0.45), 0.0)
					x += bw + 0.03
				elif pick < 0.7:
					PropFactory.build(k, "books", lxf, {}, rng)
					x += 0.42
				elif pick < 0.78:
					PropFactory.build(k, "plant_small", lxf, {}, rng)
					x += 0.25
				elif pick < 0.88:
					PropFactory.build(k, "trophy", lxf, {}, rng)
					x += 0.18
				else:
					x += 0.3

static func _shelf_labels(root: Node3D, k: MeshKit, L: LevelLayout, st: LevelState) -> void:
	# lip strips colored by section, dividers with letter tabs, banners on top
	var banner_done := {}
	for b in st.buckets:
		var sec: Dictionary = st.sections[b.section]
		var xf: Transform3D = b.xf
		var col: Color = sec.color
		# lip strip along the front edge of this bucket
		k.box("toon", xf * Transform3D(Basis(), Vector3(b.width * 0.5, -0.004, 0.008)), Vector3(b.width - 0.004, 0.03, 0.012), col, 0.0)
		# divider plate at the left edge + tab
		var dv := xf * Transform3D(Basis(), Vector3(0.002, b.height * 0.42, -b.depth * 0.5))
		k.box("toon", dv, Vector3(0.004, b.height * 0.84, b.depth * 0.95), Color(0.98, 0.98, 1.0), 0.0)
		var tab := xf * Transform3D(Basis(), Vector3(0.002, b.height * 0.8, 0.02))
		k.box("toon", tab, Vector3(0.006, 0.07, 0.06), col.lightened(0.3), 0.0)
		var lab := Label3D.new()
		lab.text = b.label
		lab.font = Covers.fonts.get("lilita-one")
		lab.font_size = 40
		lab.pixel_size = 0.0011
		lab.outline_size = 10
		lab.modulate = Color(0.15, 0.1, 0.2)
		lab.outline_modulate = Color(1, 1, 1)
		lab.transform = xf * Transform3D(Basis(), Vector3(0.012, b.height * 0.8, 0.055))
		lab.visibility_range_end = 6.0 * float(Settings.preset().vis_mult)
		lab.double_sided = false
		root.add_child(lab)
		var key := "%d_%d" % [b.unit, b.section]
		if not banner_done.has(key):
			banner_done[key] = true
			var slot: Dictionary = L.shelf_slots[b.unit]
			var uxf := ShelfPlanner.unit_xf(slot)
			var u: Dictionary = ShelfPlanner.UNITS[slot.type]
			var secs: Array = slot.get("sections", [])
			var idx := secs.find(b.section)
			var n := maxi(secs.size(), 1)
			var bw: float = (u.width - 0.05) / n
			var bx: float = -u.width * 0.5 + 0.025 + bw * (idx + 0.5)
			var bxf := uxf * Transform3D(Basis(), Vector3(bx, u.height + 0.13, u.depth * 0.5 - 0.02))
			k.box("toon", bxf, Vector3(bw - 0.02, 0.24, 0.03), col, 0.0)
			k.box("emit", bxf * Transform3D(Basis(), Vector3(0, 0, 0.016)), Vector3(bw - 0.06, 0.2, 0.002), col.lightened(0.15) * 0.9, 0.0)
			var bl := Label3D.new()
			bl.text = sec.label
			bl.font = Covers.fonts.get("lilita-one")
			bl.font_size = 64
			bl.pixel_size = 0.0016
			bl.outline_size = 14
			bl.width = (bw - 0.08) / bl.pixel_size
			bl.autowrap_mode = TextServer.AUTOWRAP_OFF
			bl.modulate = Color(1, 1, 1) if col.get_luminance() < 0.6 else Color(0.12, 0.1, 0.18)
			bl.outline_modulate = Color(0, 0, 0, 0.35)
			bl.transform = bxf * Transform3D(Basis(), Vector3(0, 0, 0.02))
			bl.visibility_range_end = 28.0
			root.add_child(bl)
			var fit := (bw - 0.1) / maxf(0.01, bl.font.get_string_size(sec.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * bl.pixel_size)
			if fit < 1.0:
				bl.pixel_size *= fit

# ======================================================================== posters, labels, stash props, mirror
static func _poster(root: Node3D, pr: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: float = pr.params.w
	var h: float = pr.params.h
	var t_idx: int = int(pr.params.seed) % Catalog.titles.size()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.9, 0.88)
	mi.material_override = m
	var yaw: float = pr.yaw
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), pr.pos + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.012))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var tex := Covers.get_hires(t_idx, Defs.E_STANDARD, "poster", 0, Defs.F_MODERN, Defs.K_CASE, func(tx):
		if is_instance_valid(mi):
			m.albedo_texture = tx
			m.albedo_color = Color(0.92, 0.9, 0.88))
	if tex:
		m.albedo_texture = tex

static func _label(root: Node3D, pr: Dictionary) -> void:
	var l := Label3D.new()
	l.text = pr.params.text
	l.font = Covers.fonts.get("lilita-one")
	l.font_size = pr.params.size
	l.pixel_size = 0.004
	l.outline_size = 12
	l.modulate = pr.params.color
	l.transform = Transform3D(Basis(Vector3.UP, pr.yaw), pr.pos)
	root.add_child(l)

static func _stash_node(root: Node3D, pr: Dictionary, rng: RandomNumberGenerator, statics: StaticBody3D, pd: Dictionary) -> Node3D:
	var k := MeshKit.new()
	PropFactory.build(k, pr.type, Transform3D(), pr.params, rng)
	var n := Node3D.new()
	n.name = "Stash_%d" % pr.stash
	n.transform = Transform3D(Basis(Vector3.UP, pr.yaw), pr.pos)
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	for chn in k.ch.keys():
		var mi := MeshInstance3D.new()
		mi.mesh = k.build_mesh(chn)
		mi.material_override = (toon_with_outline() if pd.outlines else mat("toon")) if chn == "toon" else mat(chn)
		body.add_child(mi)
	root.add_child(n)
	if pr.obstacle >= 0:
		_collider(statics, _obstacle_box(pr))
	# sparkle hint
	var sp := GPUParticles3D.new()
	sp.amount = 6
	sp.lifetime = 1.6
	sp.position = Vector3(0, 0.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.2, 0.35)
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(1.0, 0.95, 0.6)
	sp.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.012
	dm.height = 0.024
	dm.radial_segments = 6
	dm.rings = 3
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.95, 0.6)
	dm.material = em
	sp.draw_pass_1 = dm
	sp.name = "Sparkle"
	n.add_child(sp)
	return n

static func _obstacle_box(pr: Dictionary) -> AABB:
	var size: Vector3 = pr.size
	var ext := LevelLayout._rotated_extent(size, pr.yaw)
	return AABB(Vector3(pr.pos.x - ext.x * 0.5, pr.pos.y, pr.pos.z - ext.z * 0.5), Vector3(ext.x, size.y, ext.z))

static func _mirror(root: Node3D, m: Dictionary, pd: Dictionary) -> Node3D:
	var node := MirrorNode.new()
	node.size = m.size
	node.enabled_quality = pd.mirror
	node.transform = Transform3D(Basis(Vector3.UP, m.yaw), m.pos)
	root.add_child(node)
	return node
