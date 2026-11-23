class_name ItemMeshes
extends RefCounted
## Procedural meshes for every item render key. Faces are encoded in UV.x (see item shaders).
## Keys: case_<fmt>, case_<fmt>_open, cebox, cebox_open, disc_<fmt>, artbook, figure, poster, manual.

static var _cache := {}

static func render_key(it: LevelState.Item) -> String:
	match it.kind:
		Defs.K_CASE:
			return "case_%d%s" % [it.fmt, "_open" if it.open else ""]
		Defs.K_CEBOX:
			return "cebox_open" if it.open else "cebox"
		Defs.K_DISC:
			return "disc_%d" % it.fmt
		Defs.K_ARTBOOK: return "artbook"
		Defs.K_FIGURE: return "figure"
		Defs.K_POSTER: return "poster"
		Defs.K_MANUAL: return "manual"
	return ""

static func mesh(key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new()
	k.uv_mode = true
	k.ao_enabled = false
	var parts := key.split("_")
	match parts[0]:
		"case":
			var fmt := int(parts[1])
			if parts.size() > 2:
				_case_open(k, fmt)
			else:
				_case_closed(k, fmt)
		"cebox":
			if key == "cebox_open":
				_box_open(k, Defs.FORMAT_SIZE[Defs.F_CEBOX])
			else:
				_box_closed(k, Defs.FORMAT_SIZE[Defs.F_CEBOX], 0.01)
		"disc":
			var fmt := int(parts[1])
			var r: float = Defs.DISC_RADIUS[fmt]
			k.cylinder("m", Transform3D(), r, Defs.DISC_THICK, Color.WHITE, 32, -1.0, true, r * 0.1, 0, 1, 2)
		"artbook":
			var s: Vector3 = Defs.PIECE_SIZE[Defs.K_ARTBOOK]
			k.box("m", Transform3D(), s, Color.WHITE, 0.004, {"+z": 0, "-z": 1, "-x": 2})
		"manual":
			var s: Vector3 = Defs.PIECE_SIZE[Defs.K_MANUAL]
			k.box("m", Transform3D(), s, Color.WHITE, 0.002, {"+z": 0, "-z": 1})
		"poster":
			var s: Vector3 = Defs.PIECE_SIZE[Defs.K_POSTER]
			k.cylinder("m", Transform3D(), s.x * 0.5, s.y, Color.WHITE, 14, -1.0, true, 0.0, 3, 3, 0)
		"figure":
			_figure(k)
	var m := k.build_mesh("m")
	_cache[key] = m
	return m

static func _case_closed(k: MeshKit, fmt: int) -> void:
	var s: Vector3 = Defs.FORMAT_SIZE[fmt]
	var bev := 0.0035 if fmt != Defs.F_JEWEL else 0.0015
	if fmt == Defs.F_LONGBOX or fmt == Defs.F_BIGBOX:
		_box_closed(k, s, 0.004)
		return
	k.box("m", Transform3D(), s, Color.WHITE, bev, {"+z": 0, "-z": 1, "-x": 2})
	if fmt == Defs.F_JEWEL:
		# hinge ridge
		k.box("m", Transform3D(Basis(), Vector3(-s.x * 0.5 + 0.004, 0, 0)), Vector3(0.006, s.y * 0.98, s.z * 1.04), Color.WHITE, 0.001)

static func _box_closed(k: MeshKit, s: Vector3, bev: float) -> void:
	k.box("m", Transform3D(), s, Color.WHITE, bev, {"+z": 0, "-z": 1, "-x": 2})

static func _case_open(k: MeshKit, fmt: int) -> void:
	var s: Vector3 = Defs.FORMAT_SIZE[fmt]
	if fmt == Defs.F_LONGBOX or fmt == Defs.F_BIGBOX:
		_box_open(k, s)
		return
	var half := s.z * 0.5
	# back panel (stays in place), cover art underneath, plain inside with a disc hub
	k.box("m", Transform3D(Basis(), Vector3(0, 0, -s.z * 0.25)), Vector3(s.x, s.y, half), Color.WHITE, 0.002, {"-z": 1})
	k.cylinder("m", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -s.z * 0.25 + half * 0.5 + 0.002)), 0.016, 0.004, Color.WHITE, 12)
	k.cylinder("m", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -s.z * 0.25 + half * 0.5 + 0.001)), 0.05, 0.002, Color(0.8, 0.8, 0.8), 20)
	# hinge strip (spine)
	k.box("m", Transform3D(Basis(), Vector3(-s.x * 0.5 - s.z * 0.5, 0, -s.z * 0.25)), Vector3(s.z, s.y, half), Color.WHITE, 0.0015, {"-z": 2})
	# front panel flipped open to the left, cover art facing down
	k.box("m", Transform3D(Basis(), Vector3(-s.x - s.z, 0, -s.z * 0.25)), Vector3(s.x, s.y, half), Color.WHITE, 0.002, {"-z": 0})
	# inner clips on the front panel (paper insert holder)
	k.box("m", Transform3D(Basis(), Vector3(-s.x - s.z, s.y * 0.42, -s.z * 0.25 + half * 0.5 + 0.001)), Vector3(s.x * 0.5, 0.01, 0.002), Color.WHITE, 0.0)

static func _box_open(k: MeshKit, s: Vector3) -> void:
	var w := 0.006
	var h := s * 0.5
	# walls: front (art), back, spine side, right side, bottom
	k.box("m", Transform3D(Basis(), Vector3(0, 0, h.z - w * 0.5)), Vector3(s.x, s.y, w), Color.WHITE, 0.0015, {"+z": 0})
	k.box("m", Transform3D(Basis(), Vector3(0, 0, -h.z + w * 0.5)), Vector3(s.x, s.y, w), Color.WHITE, 0.0015, {"-z": 1})
	k.box("m", Transform3D(Basis(), Vector3(-h.x + w * 0.5, 0, 0)), Vector3(w, s.y, s.z), Color.WHITE, 0.0015, {"-x": 2})
	k.box("m", Transform3D(Basis(), Vector3(h.x - w * 0.5, 0, 0)), Vector3(w, s.y, s.z), Color.WHITE, 0.0015)
	k.box("m", Transform3D(Basis(), Vector3(0, -h.y + w * 0.5, 0)), Vector3(s.x, w, s.z), Color.WHITE, 0.0015)
	# lid standing up behind, hinged at the back top edge
	var lid := Transform3D(Basis(Vector3.RIGHT, -PI * 0.55), Vector3(0, h.y, -h.z)) * Transform3D(Basis(), Vector3(0, 0, h.z))
	k.box("m", lid, Vector3(s.x * 1.02, w, s.z * 1.02), Color.WHITE, 0.0015)

static func _figure(k: MeshKit) -> void:
	var s: Vector3 = Defs.PIECE_SIZE[Defs.K_FIGURE]
	k.cylinder("m", Transform3D(Basis(), Vector3(0, -s.y * 0.5 + 0.01, 0)), 0.045, 0.02, Color.WHITE, 14, -1.0, true, 0.0, 1, 1, 1)
	k.capsule("m", Transform3D(Basis(), Vector3(0, -0.01, 0)), 0.032, 0.12, Color.WHITE, 12)
	# eyes: face 0 = white, face 1 = dark (see item shader mode 3)
	for sx in [-0.012, 0.012]:
		k.cylinder("m", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx, 0.025, 0.03)), 0.009, 0.006, Color.WHITE, 8, -1.0, true, 0.0, 0, 0, 0)
		k.cylinder("m", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx + 0.002, 0.025, 0.0335)), 0.0045, 0.002, Color.WHITE, 6, -1.0, true, 0.0, 1, 1, 1)
	# stubby arms
	for sx in [-1.0, 1.0]:
		k.capsule("m", Transform3D(Basis(Vector3.BACK, sx * 0.6), Vector3(sx * 0.036, -0.015, 0.0)), 0.011, 0.05, Color.WHITE, 8)

## Collision shape extents for physics bodies.
static func collision_size(st: LevelState, it: LevelState.Item) -> Vector3:
	var box := st.local_aabb(it)
	var s := box.size
	return Vector3(maxf(s.x, 0.012), maxf(s.y, 0.012), maxf(s.z, 0.012))
