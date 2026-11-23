class_name LevelLayout
extends RefCounted
## Pure-data description of a level's geometry: rooms, walls, props, obstacles, surfaces,
## shelf units, stashes, lights and spawn points. Built by layout builders, consumed by
## WorldBuilder (visuals/collision), MessGen (item placement) and tests (validation).

const WALL_T := 0.16

var name := ""
var rooms: Array = []        # {name, rect: Rect2 (x,z,w,d), height, floor, wall, ceiling, dim}
var doors: Array = []        # {pos: Vector2, width, height, axis: "x"|"z"}
var windows: Array = []      # {pos: Vector2, axis, width, height, sill, sky}
var props: Array = []        # {type, pos: Vector3, yaw, params, size, obstacle_idx}
var obstacles: Array = []    # AABB (world)
var surfaces: Array = []     # {rect: Rect2 (x,z,w,d), y, room}
var shelf_slots: Array = []  # {pos: Vector3, yaw, type, room, used}
var stashes: Array = []      # {id, type, pos: Vector3, yaw, spill: Vector3, prop}
var lights: Array = []       # {type, pos, color, energy, range, shadow}
var spawns: Array = []       # Vector3
var mirror := {}             # {pos, yaw}
var sort_tables: Array = []  # {pos, yaw, size: Vector2, cells: Vector2i}
var carts: Array = []        # {pos, yaw}
var pile_zones: Array = []   # {rect: Rect2, weight}
var env := {"ambient": Color(1.0, 0.86, 0.72), "ambient_energy": 0.55, "sun": Color(1.0, 0.9, 0.75),
	"sun_energy": 0.9, "fog": false, "fog_color": Color(0.8, 0.7, 0.6), "fog_density": 0.0,
	"dust": false, "flashlight": false, "sky_top": Color(0.35, 0.6, 0.95), "sky_horizon": Color(0.95, 0.85, 0.75)}
var bounds := Rect2()

# ------------------------------------------------------------------ building API
func add_room(rname: String, rect: Rect2, height := 2.7, floor_style := "wood", wall := Color(0.95, 0.88, 0.78), ceiling := Color(0.98, 0.96, 0.92)) -> int:
	rooms.append({"name": rname, "rect": rect, "height": height, "floor": floor_style, "wall": wall,
		"ceiling": ceiling, "wall_style": "plain", "trim": Color(0.98, 0.97, 0.94)})
	bounds = rect if rooms.size() == 1 else bounds.merge(rect)
	pile_zones.append({"rect": rect.grow(-0.45), "weight": rect.get_area(), "room": rooms.size() - 1})
	return rooms.size() - 1

func add_door(pos: Vector2, width := 1.0, height := 2.1) -> void:
	doors.append({"pos": pos, "width": width, "height": height})

func add_window(pos: Vector2, width := 1.2, height := 1.1, sill := 0.9) -> void:
	windows.append({"pos": pos, "width": width, "height": height, "sill": sill})

func add_prop(type: String, pos: Vector3, yaw_deg := 0.0, params := {}) -> int:
	var spec := PropFactory.spec(type, params)
	var size: Vector3 = spec.size
	var yaw := deg_to_rad(yaw_deg)
	var entry := {"type": type, "pos": pos, "yaw": yaw, "params": params, "size": size, "obstacle": -1}
	if spec.get("collide", false):
		var ext := _rotated_extent(size, yaw)
		var box := AABB(Vector3(pos.x - ext.x * 0.5, pos.y, pos.z - ext.z * 0.5), Vector3(ext.x, size.y, ext.z))
		obstacles.append(box)
		entry.obstacle = obstacles.size() - 1
	if spec.has("surface"):
		var sfc: Dictionary = spec.surface
		var sext := _rotated_extent(Vector3(sfc.w, 0, sfc.d), yaw)
		var off: Vector3 = Basis(Vector3.UP, yaw) * sfc.get("offset", Vector3.ZERO)
		surfaces.append({"rect": Rect2(pos.x + off.x - sext.x * 0.5, pos.z + off.z - sext.z * 0.5, sext.x, sext.z),
			"y": pos.y + float(sfc.h), "room": room_at(Vector2(pos.x, pos.z))})
	props.append(entry)
	return props.size() - 1

func add_shelf_slot(pos: Vector3, yaw_deg: float, type := "case_shelf") -> void:
	var yaw := deg_to_rad(yaw_deg)
	shelf_slots.append({"pos": pos, "yaw": yaw, "type": type, "room": room_at(Vector2(pos.x, pos.z)), "used": false})
	var u: Dictionary = ShelfPlanner.UNITS[type]
	var ext := _rotated_extent(Vector3(u.width, u.height, u.depth + 0.12), yaw)
	obstacles.append(AABB(Vector3(pos.x - ext.x * 0.5, 0, pos.z - ext.z * 0.5), Vector3(ext.x, u.height, ext.z)))

## Place `count` shelf units side by side along a wall. side: "n","s","w","e" = wall at
## z=rect.top, z=rect.bottom, x=rect.left, x=rect.right of `rect`; start = offset along the wall.
func shelf_run(rect: Rect2, side: String, start: float, count: int, type := "case_shelf", gap := 0.04) -> void:
	var u: Dictionary = ShelfPlanner.UNITS[type]
	var off: float = u.depth * 0.5 + 0.1
	for i in count:
		var t: float = start + i * (u.width + gap) + u.width * 0.5
		match side:
			"n": add_shelf_slot(Vector3(rect.position.x + t, 0, rect.position.y + off), 0, type)
			"s": add_shelf_slot(Vector3(rect.position.x + t, 0, rect.end.y - off), 180, type)
			"w": add_shelf_slot(Vector3(rect.position.x + off, 0, rect.position.y + t), 90, type)
			"e": add_shelf_slot(Vector3(rect.end.x - off, 0, rect.position.y + t), -90, type)

func add_stash(type: String, pos: Vector3, yaw_deg := 0.0, params := {}) -> int:
	var pidx := add_prop(type, pos, yaw_deg, params)
	var spec := PropFactory.spec(type, params)
	var yaw := deg_to_rad(yaw_deg)
	var spill: Vector3 = pos + Basis(Vector3.UP, yaw) * spec.get("spill", Vector3(0, 0.3, 0.6))
	var id := stashes.size()
	stashes.append({"id": id, "type": type, "pos": pos, "yaw": yaw, "spill": spill, "prop": pidx})
	props[pidx]["stash"] = id
	return id

func add_light(pos: Vector3, color := Color(1.0, 0.8, 0.55), energy := 1.2, range_m := 5.0, shadow := false) -> void:
	lights.append({"type": "omni", "pos": pos, "color": color, "energy": energy, "range": range_m, "shadow": shadow})

func add_sort_table(pos: Vector3, yaw_deg := 0.0) -> void:
	add_prop("sort_table", pos, yaw_deg)
	sort_tables.append({"pos": pos, "yaw": deg_to_rad(yaw_deg), "size": Vector2(1.6, 0.8), "cells": Vector2i(6, 3), "height": 0.78})

func add_cart(pos: Vector3, yaw_deg := 0.0) -> void:
	carts.append({"pos": pos, "yaw": deg_to_rad(yaw_deg)})

# ------------------------------------------------------------------ queries
func room_at(p: Vector2) -> int:
	for i in rooms.size():
		if (rooms[i].rect as Rect2).has_point(p):
			return i
	return -1

func is_free(p: Vector3, radius := 0.12, wall_margin := 0.2) -> bool:
	var r := room_at(Vector2(p.x, p.z))
	if r < 0:
		return false
	var rect: Rect2 = rooms[r].rect
	if not rect.grow(-wall_margin).has_point(Vector2(p.x, p.z)):
		# allow if inside another room (door overlap zone)
		var ok := false
		for rm in rooms:
			if (rm.rect as Rect2).grow(-wall_margin).has_point(Vector2(p.x, p.z)):
				ok = true
		if not ok:
			return false
	if p.y < -0.01 or p.y > float(rooms[r].height) - 0.05:
		return false
	for box in obstacles:
		var b: AABB = box
		if p.x > b.position.x - radius and p.x < b.end.x + radius and p.z > b.position.z - radius and p.z < b.end.z + radius:
			if p.y < b.end.y + 0.02 and p.y > b.position.y - radius:
				return false
	return true

## Point on a raised surface (desk/bed) that doesn't intersect props standing on that surface.
func is_free_on_surface(p: Vector3, radius := 0.1) -> bool:
	for box in obstacles:
		var b: AABB = box
		if p.x > b.position.x - radius and p.x < b.end.x + radius and p.z > b.position.z - radius and p.z < b.end.z + radius:
			if p.y + 0.05 > b.position.y and p.y < b.end.y - 0.03:
				return false
	return true

func random_floor_point(rng: RandomNumberGenerator, radius := 0.15, tries := 60) -> Vector3:
	var total := 0.0
	for z in pile_zones:
		total += z.weight
	for t in tries:
		var pick := rng.randf() * total
		var zone: Dictionary = pile_zones[0]
		for z in pile_zones:
			pick -= z.weight
			if pick <= 0.0:
				zone = z
				break
		var r: Rect2 = zone.rect
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0.0, rng.randf_range(r.position.y, r.end.y))
		if is_free(p, radius):
			return p
	return Vector3.INF

func floor_point_in_room(rng: RandomNumberGenerator, room: int, radius := 0.15) -> Vector3:
	var r: Rect2 = (rooms[room].rect as Rect2).grow(-0.45)
	for t in 60:
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0.0, rng.randf_range(r.position.y, r.end.y))
		if is_free(p, radius):
			return p
	return Vector3.INF

func shelf_units_of(type: String) -> Array:
	return shelf_slots.filter(func(s): return s.type == type)

static func _rotated_extent(size: Vector3, yaw: float) -> Vector3:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	return Vector3(size.x * c + size.z * s, size.y, size.x * s + size.z * c)

## Wall segments after removing shared edges and door gaps.
## Returns [{a: Vector2, b: Vector2, h, room, color, holes:[{t0,t1,y0,y1,window}]}]
func wall_segments() -> Array:
	var out: Array = []
	var built: Array = [] # [a,b] segments already emitted
	for ri in rooms.size():
		var rect: Rect2 = rooms[ri].rect
		var p0 := rect.position
		var p1 := Vector2(rect.end.x, rect.position.y)
		var p2 := rect.end
		var p3 := Vector2(rect.position.x, rect.end.y)
		for e in [[p0, p1], [p1, p2], [p3, p2], [p0, p3]]:
			var intervals := [[0.0, 1.0]]
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var length := a.distance_to(b)
			for s in built:
				intervals = _subtract_collinear(intervals, a, b, s[0], s[1])
			for iv in intervals:
				if (iv[1] - iv[0]) * length < 0.05:
					continue
				var sa := a.lerp(b, iv[0])
				var sb := a.lerp(b, iv[1])
				var holes: Array = []
				var seg_len := sa.distance_to(sb)
				var dir := (sb - sa).normalized()
				for d in doors:
					var t := _proj_on_seg(d.pos, sa, sb)
					if t >= 0.0:
						holes.append({"t0": t - d.width * 0.5, "t1": t + d.width * 0.5, "y0": 0.0, "y1": d.height, "window": false})
				for w in windows:
					var t := _proj_on_seg(w.pos, sa, sb)
					if t >= 0.0:
						holes.append({"t0": t - w.width * 0.5, "t1": t + w.width * 0.5, "y0": w.sill, "y1": w.sill + w.height, "window": true})
				out.append({"a": sa, "b": sb, "h": rooms[ri].height, "room": ri, "color": rooms[ri].wall, "holes": holes, "len": seg_len, "dir": dir})
			built.append([a, b])
	return out

func _proj_on_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l := ab.length()
	if l < 0.001:
		return -1.0
	var t := (p - a).dot(ab) / l
	var closest := a + ab / l * t
	if closest.distance_to(p) > 0.2 or t < 0.0 or t > l:
		return -1.0
	return t

func _subtract_collinear(intervals: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Array:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return intervals
	# collinear check
	var n := Vector2(-ab.y, ab.x).normalized()
	if absf((c - a).dot(n)) > 0.02 or absf((d - a).dot(n)) > 0.02:
		return intervals
	var tc := (c - a).dot(ab) / l2
	var td := (d - a).dot(ab) / l2
	var lo := minf(tc, td)
	var hi := maxf(tc, td)
	var res: Array = []
	for iv in intervals:
		if hi <= iv[0] or lo >= iv[1]:
			res.append(iv)
			continue
		if lo > iv[0]:
			res.append([iv[0], lo])
		if hi < iv[1]:
			res.append([hi, iv[1]])
	return res
