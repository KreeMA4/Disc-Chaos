class_name MeshKit
extends RefCounted
## Procedural geometry builder. Accumulates triangles into per-channel arrays so a whole room's
## props merge into a handful of meshes (one per material channel). Vertex colors carry the
## base color multiplied by a fake ambient-occlusion term (darker near the floor / under things).
##
## Godot uses clockwise winding for front faces; tri() auto-orients against an outward hint.

var ch: Dictionary = {} # channel -> {v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array}
var ao_enabled := true
var ao_floor := 0.0      # world y of the floor for AO
var ao_strength := 0.38
var uv_mode := false     # item meshes encode face ids in UV.x

func _arr(name: String) -> Dictionary:
	if not ch.has(name):
		ch[name] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array()}
	return ch[name]

func _ao(p: Vector3) -> float:
	if not ao_enabled:
		return 1.0
	var h := p.y - ao_floor
	return lerpf(1.0 - ao_strength, 1.0, clampf(h / 0.55, 0.0, 1.0))

func tri(c: String, a: Vector3, b: Vector3, d: Vector3, na: Vector3, nb: Vector3, nd: Vector3, col: Color, outward: Vector3,
		uva := Vector2.ZERO, uvb := Vector2.ZERO, uvd := Vector2.ZERO) -> void:
	var A := _arr(c)
	var cr := (b - a).cross(d - a)
	if cr.dot(outward) > 0.0:
		var t := b; b = d; d = t
		var tn := nb; nb = nd; nd = tn
		var tu := uvb; uvb = uvd; uvd = tu
	A.v.append(a); A.v.append(b); A.v.append(d)
	A.n.append(na); A.n.append(nb); A.n.append(nd)
	A.c.append(col * Color(_ao(a), _ao(a), _ao(a), 1.0))
	A.c.append(col * Color(_ao(b), _ao(b), _ao(b), 1.0))
	A.c.append(col * Color(_ao(d), _ao(d), _ao(d), 1.0))
	A.uv.append(uva); A.uv.append(uvb); A.uv.append(uvd)

func quad(c: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, col: Color,
		u0 := Vector2.ZERO, u1 := Vector2.ZERO, u2 := Vector2.ZERO, u3 := Vector2.ZERO) -> void:
	tri(c, p0, p1, p2, n, n, n, col, n, u0, u1, u2)
	tri(c, p0, p2, p3, n, n, n, col, n, u0, u2, u3)

# --------------------------------------------------------------------------- bevelled box
## size = full size; r = bevel radius. face_ids: {"+x":id,...} for uv_mode (face id goes in uv.x
## integer part). Non-listed faces and bevels use face 3 (plain).
func box(c: String, xf: Transform3D, size: Vector3, col: Color, r := 0.0, face_ids := {}, face_cols := {}) -> void:
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	var hi := h - Vector3(r, r, r)
	var b := xf.basis
	var o := xf.origin
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# faces
	for ax in 3:
		for s in [-1.0, 1.0]:
			var key: String = ("+" if s > 0 else "-") + String(["x", "y", "z"][ax])
			var u_ax := (ax + 1) % 3
			var v_ax := (ax + 2) % 3
			var n: Vector3 = axes[ax] * s
			var pts: Array = []
			for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var p := Vector3.ZERO
				p[ax] = h[ax] * s
				p[u_ax] = hi[u_ax] * k[0]
				p[v_ax] = hi[v_ax] * k[1]
				pts.append(p)
			var fcol: Color = face_cols.get(key, col)
			var fid: int = face_ids.get(key, 3)
			var uvs: Array = []
			for p in pts:
				uvs.append(_face_uv(key, p, hi if r > 0.0 else h, fid) if uv_mode else Vector2.ZERO)
			var wn := (b * n).normalized()
			var w: Array = []
			for p in pts:
				w.append(o + b * p)
			tri(c, w[0], w[1], w[2], wn, wn, wn, fcol, wn, uvs[0], uvs[1], uvs[2])
			tri(c, w[0], w[2], w[3], wn, wn, wn, fcol, wn, uvs[0], uvs[2], uvs[3])
	if r <= 0.0005:
		return
	var plain_uv := Vector2(3.5, 0.5)
	# edges
	for a in 3:
		for bb in range(a + 1, 3):
			var cax := 3 - a - bb
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var pts: Array = []
					var ns: Array = []
					for sc in [-1.0, 1.0]:
						var p1 := Vector3.ZERO
						p1[a] = h[a] * sa; p1[bb] = hi[bb] * sb; p1[cax] = hi[cax] * sc
						var p2 := Vector3.ZERO
						p2[a] = hi[a] * sa; p2[bb] = h[bb] * sb; p2[cax] = hi[cax] * sc
						pts.append(p1); ns.append(axes[a] * sa)
						pts.append(p2); ns.append(axes[bb] * sb)
					var outv := Vector3.ZERO
					outv[a] = sa; outv[bb] = sb
					var wo: Vector3 = (b * outv).normalized()
					var W: Array = []
					var N: Array = []
					for i in 4:
						W.append(o + b * pts[i])
						N.append((b * ns[i]).normalized())
					# pts order: p1(c-), p2(c-), p1(c+), p2(c+)
					tri(c, W[0], W[1], W[3], N[0], N[1], N[3], col, wo, plain_uv, plain_uv, plain_uv)
					tri(c, W[0], W[3], W[2], N[0], N[3], N[2], col, wo, plain_uv, plain_uv, plain_uv)
	# corners
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px := Vector3(h.x * sx, hi.y * sy, hi.z * sz)
				var py := Vector3(hi.x * sx, h.y * sy, hi.z * sz)
				var pz := Vector3(hi.x * sx, hi.y * sy, h.z * sz)
				var wo := (b * Vector3(sx, sy, sz)).normalized()
				tri(c, o + b * px, o + b * py, o + b * pz, (b * Vector3(sx, 0, 0)).normalized(),
					(b * Vector3(0, sy, 0)).normalized(), (b * Vector3(0, 0, sz)).normalized(), col, wo, plain_uv, plain_uv, plain_uv)

func _face_uv(key: String, p: Vector3, h: Vector3, fid: int) -> Vector2:
	var u := 0.5
	var v := 0.5
	match key:
		"+z":
			u = (p.x + h.x) / (2.0 * h.x); v = (h.y - p.y) / (2.0 * h.y)
		"-z":
			u = (h.x - p.x) / (2.0 * h.x); v = (h.y - p.y) / (2.0 * h.y)
		"-x":
			u = (h.y - p.y) / (2.0 * h.y); v = (p.z + h.z) / (2.0 * h.z)
		"+x":
			u = (h.z - p.z) / (2.0 * h.z); v = (h.y - p.y) / (2.0 * h.y)
		"+y":
			u = (p.x + h.x) / (2.0 * h.x); v = (p.z + h.z) / (2.0 * h.z)
		"-y":
			u = (p.x + h.x) / (2.0 * h.x); v = (h.z - p.z) / (2.0 * h.z)
	u = clampf(u, 0.002, 0.998)
	v = clampf(v, 0.002, 0.998)
	return Vector2(float(fid) + u, v)

# --------------------------------------------------------------------------- cylinder
## Cylinder along local Y, centered. ring_hole > 0 makes an annulus (disc with a hole).
func cylinder(c: String, xf: Transform3D, radius: float, height: float, col: Color, segs := 16,
		top_r := -1.0, caps := true, ring_hole := 0.0, face_top := 3, face_bottom := 3, face_side := 3, side_col := Color(-1, 0, 0)) -> void:
	if top_r < 0.0:
		top_r = radius
	var b := xf.basis
	var o := xf.origin
	var hh := height * 0.5
	var scol := col if side_col.r < 0.0 else side_col
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var slope := (radius - top_r) / maxf(height, 0.001)
		var n0 := (b * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (b * (d1 + Vector3(0, slope, 0))).normalized()
		var bl := o + b * (d0 * radius + Vector3(0, -hh, 0))
		var br := o + b * (d1 * radius + Vector3(0, -hh, 0))
		var tl := o + b * (d0 * top_r + Vector3(0, hh, 0))
		var tr := o + b * (d1 * top_r + Vector3(0, hh, 0))
		var su0 := Vector2(face_side + float(i) / segs, 1.0)
		var su1 := Vector2(face_side + float(i + 1) / segs - 0.001, 1.0)
		var wo := (n0 + n1).normalized()
		tri(c, bl, br, tr, n0, n1, n1, scol, wo, su0, su1, Vector2(su1.x, 0.0))
		tri(c, bl, tr, tl, n0, n1, n0, scol, wo, su0, Vector2(su1.x, 0.0), Vector2(su0.x, 0.0))
		if ring_hole > 0.0:
			for s in [-1.0, 1.0]:
				var rr: float = top_r if s > 0 else radius
				var y: float = hh * s
				var n: Vector3 = (b * Vector3(0, s, 0)).normalized()
				var fid: int = face_top if s > 0 else face_bottom
				var p0 := o + b * (d0 * rr + Vector3(0, y, 0))
				var p1 := o + b * (d1 * rr + Vector3(0, y, 0))
				var p2 := o + b * (d1 * ring_hole + Vector3(0, y, 0))
				var p3 := o + b * (d0 * ring_hole + Vector3(0, y, 0))
				var uv0 := _disc_uv(d0 * rr, rr, fid, s)
				var uv1 := _disc_uv(d1 * rr, rr, fid, s)
				var uv2 := _disc_uv(d1 * ring_hole, rr, fid, s)
				var uv3 := _disc_uv(d0 * ring_hole, rr, fid, s)
				tri(c, p0, p1, p2, n, n, n, col, n, uv0, uv1, uv2)
				tri(c, p0, p2, p3, n, n, n, col, n, uv0, uv2, uv3)
			# inner hole wall
			var hn0 := (b * -d0).normalized()
			var hn1 := (b * -d1).normalized()
			var ib0 := o + b * (d0 * ring_hole + Vector3(0, -hh, 0))
			var ib1 := o + b * (d1 * ring_hole + Vector3(0, -hh, 0))
			var it0 := o + b * (d0 * ring_hole + Vector3(0, hh, 0))
			var it1 := o + b * (d1 * ring_hole + Vector3(0, hh, 0))
			var ps := Vector2(face_side + 0.5, 0.5)
			tri(c, ib0, ib1, it1, hn0, hn1, hn1, scol, -wo, ps, ps, ps)
			tri(c, ib0, it1, it0, hn0, hn1, hn0, scol, -wo, ps, ps, ps)
		elif caps:
			var ct := o + b * Vector3(0, hh, 0)
			var cb := o + b * Vector3(0, -hh, 0)
			var nt := (b * Vector3.UP).normalized()
			var nb := -nt
			if top_r > 0.0005:
				tri(c, ct, tl, tr, nt, nt, nt, col, nt, _disc_uv(Vector3.ZERO, top_r, face_top, 1), _disc_uv(d0 * top_r, top_r, face_top, 1), _disc_uv(d1 * top_r, top_r, face_top, 1))
			if radius > 0.0005:
				tri(c, cb, bl, br, nb, nb, nb, col, nb, _disc_uv(Vector3.ZERO, radius, face_bottom, -1), _disc_uv(d0 * radius, radius, face_bottom, -1), _disc_uv(d1 * radius, radius, face_bottom, -1))

func _disc_uv(p: Vector3, r: float, fid: int, s: float) -> Vector2:
	if not uv_mode:
		return Vector2.ZERO
	var u := p.x / maxf(r, 0.0001) * 0.5 + 0.5
	var v := p.z / maxf(r, 0.0001) * 0.5 + 0.5
	if s < 0:
		u = 1.0 - u
	return Vector2(float(fid) + clampf(u, 0.001, 0.999), clampf(v, 0.001, 0.999))

# --------------------------------------------------------------------------- sphere / ellipsoid
func sphere(c: String, xf: Transform3D, radius: Vector3, col: Color, rings := 8, segs := 12, hemi := false) -> void:
	var b := xf.basis
	var o := xf.origin
	var ring_end := rings / 2 if hemi else rings
	for j in ring_end:
		var t0 := PI * float(j) / rings
		var t1 := PI * float(j + 1) / rings
		for i in segs:
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var u00 := Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0))
			var u01 := Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1))
			var u10 := Vector3(sin(t1) * cos(a0), cos(t1), sin(t1) * sin(a0))
			var u11 := Vector3(sin(t1) * cos(a1), cos(t1), sin(t1) * sin(a1))
			var p00 := o + b * (u00 * radius)
			var p01 := o + b * (u01 * radius)
			var p10 := o + b * (u10 * radius)
			var p11 := o + b * (u11 * radius)
			var n00 := (b * (u00 / radius)).normalized()
			var n01 := (b * (u01 / radius)).normalized()
			var n10 := (b * (u10 / radius)).normalized()
			var n11 := (b * (u11 / radius)).normalized()
			var wo := (b * ((u00 + u11) * 0.5)).normalized()
			if j > 0:
				tri(c, p00, p01, p11, n00, n01, n11, col, wo)
			if j < rings - 1:
				tri(c, p00, p11, p10, n00, n11, n10, col, wo)

## Capsule-ish bean along Y: total height h, radius r.
func capsule(c: String, xf: Transform3D, r: float, h: float, col: Color, segs := 12) -> void:
	var mid := maxf(h - 2.0 * r, 0.0)
	cylinder(c, xf, r, mid, col, segs, -1.0, false)
	sphere(c, xf * Transform3D(Basis(), Vector3(0, mid * 0.5, 0)), Vector3(r, r, r), col, 8, segs, true)
	sphere(c, xf * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -mid * 0.5, 0)), Vector3(r, r, r), col, 8, segs, true)

func torus(c: String, xf: Transform3D, R: float, r: float, col: Color, segs := 16, sides := 8, arc := TAU) -> void:
	var b := xf.basis
	var o := xf.origin
	for i in segs:
		var a0 := arc * float(i) / segs
		var a1 := arc * float(i + 1) / segs
		for j in sides:
			var s0 := TAU * float(j) / sides
			var s1 := TAU * float(j + 1) / sides
			var pts: Array = []
			var ns: Array = []
			for pair in [[a0, s0], [a1, s0], [a1, s1], [a0, s1]]:
				var ca := Vector3(cos(pair[0]), 0, sin(pair[0]))
				var nrm: Vector3 = ca * cos(pair[1]) + Vector3(0, sin(pair[1]), 0)
				pts.append(o + b * (ca * R + nrm * r))
				ns.append((b * nrm).normalized())
			var wo: Vector3 = (ns[0] + ns[2]).normalized()
			tri(c, pts[0], pts[1], pts[2], ns[0], ns[1], ns[2], col, wo)
			tri(c, pts[0], pts[2], pts[3], ns[0], ns[2], ns[3], col, wo)

## Flat double-sided quad (decals, posters backs, wrappers). size x,y in local XY plane facing +Z.
func plane(c: String, xf: Transform3D, size: Vector2, col: Color, double := false, fid := 0) -> void:
	var b := xf.basis
	var o := xf.origin
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var p := [o + b * Vector3(-hx, -hy, 0), o + b * Vector3(hx, -hy, 0), o + b * Vector3(hx, hy, 0), o + b * Vector3(-hx, hy, 0)]
	var n := (b * Vector3.BACK).normalized()
	var u := [Vector2(fid, 1), Vector2(fid + 0.999, 1), Vector2(fid + 0.999, 0), Vector2(fid, 0)]
	quad(c, p[0], p[1], p[2], p[3], n, col, u[0], u[1], u[2], u[3])
	if double:
		quad(c, p[1], p[0], p[3], p[2], -n, col, u[1], u[0], u[3], u[2])

## A squashed blob (beanbags, pillows, plants) via ellipsoid with noise-free squash.
func blob(c: String, xf: Transform3D, size: Vector3, col: Color) -> void:
	sphere(c, xf, size * 0.5, col, 8, 14)

# --------------------------------------------------------------------------- output
func vertex_count() -> int:
	var n := 0
	for k in ch:
		n += ch[k].v.size()
	return n

func build_mesh(channel: String) -> ArrayMesh:
	if not ch.has(channel) or ch[channel].v.size() == 0:
		return null
	var A: Dictionary = ch[channel]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = A.v
	arrays[Mesh.ARRAY_NORMAL] = A.n
	arrays[Mesh.ARRAY_COLOR] = A.c
	arrays[Mesh.ARRAY_TEX_UV] = A.uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func clear() -> void:
	ch.clear()
