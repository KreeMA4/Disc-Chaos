class_name MessGen
extends RefCounted
## Deterministically builds a LevelState for a level definition + layout + seed:
## picks products, creates items, plans shelves, then wrecks everything.

const FLAT_CELL := 0.05

static func build(def: Dictionary, layout: LevelLayout, seed: int) -> LevelState:
	var st := LevelState.new()
	st.level_id = def.id
	st.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + int(def.id) * 1009
	_select_products(st, def, rng)
	_create_items(st)
	if not ShelfPlanner.plan(st, layout, def.get("bucket", 8), def.id != 5):
		push_error("MessGen: shelf planning failed for level %d" % def.id)
	_make_tables(st, layout)
	_make_stashes(st, layout)
	_make_carts(st, layout)
	_wreck(st, def, layout, rng)
	st.recheck_all()
	st.rebuild_index()
	return st

# ------------------------------------------------------------------ products
static func _items_for(t: Dictionary, edition: int) -> int:
	var n: int = t.discs
	var fmt: int = Defs.PLATFORMS[t.platform].format
	if edition == Defs.E_CE:
		return 2 + n + 3
	if fmt == Defs.F_BIGBOX:
		return 1 + n + 1
	return 1 + n

static func _select_products(st: LevelState, def: Dictionary, rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	for p in def.platforms:
		for t in Catalog.titles_for_platform(p):
			if not def.multi and t.discs > 1:
				continue
			pool.append(t)
	# deterministic shuffle
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	var total := 0
	var target: int = def.target_items
	var used := {}
	# round-robin by platform so every section gets content
	var per_plat := {}
	for t in pool:
		if not per_plat.has(t.platform):
			per_plat[t.platform] = []
		per_plat[t.platform].append(t)
	var plats: Array = def.platforms.duplicate()
	var idx := {}
	for p in plats:
		idx[p] = 0
	var weights := {}
	for p in plats:
		weights[p] = 1.0
	if def.id == 1:
		weights[Defs.P_PIP] = 0.45
	var progress_guard := 0
	while total < target and progress_guard < 100000:
		progress_guard += 1
		var any := false
		for p in plats:
			if total >= target:
				break
			if rng.randf() > weights[p]:
				continue
			var lst: Array = per_plat.get(p, [])
			if idx[p] >= lst.size():
				continue
			any = true
			var t: Dictionary = lst[idx[p]]
			idx[p] += 1
			var eds: Array = [Defs.E_STANDARD]
			for e in t.editions:
				if e == Defs.E_STEEL and def.steel and rng.randf() < 0.75:
					eds.append(e)
				elif e == Defs.E_CE and def.ce and rng.randf() < 0.85:
					eds.append(e)
				elif e == Defs.E_GH and def.gh and rng.randf() < 0.6:
					eds.append(e)
			# sometimes only the special edition is in this collection
			if eds.size() > 1 and rng.randf() < 0.3:
				eds.remove_at(0)
			for e in eds:
				var key := "%d:%d" % [t.idx, e]
				if used.has(key):
					continue
				used[key] = true
				var pid := st.products.size()
				var name: String = t.name
				st.products.append({"pid": pid, "title": t.idx, "edition": e, "root": -1, "disc_box": -1,
					"discs": [], "pieces": [], "bucket": -1, "fmt": Defs.PLATFORMS[t.platform].format,
					"sort": "%s|%d|%s" % [Defs.sort_name(name), e, t.gid], "solved": false})
				total += _items_for(t, e)
		if not any:
			break

static func _create_items(st: LevelState) -> void:
	for p in st.products:
		var t: Dictionary = Catalog.titles[p.title]
		var fmt: int = p.fmt
		var pid: int = p.pid
		if p.edition == Defs.E_CE:
			var box := st.new_item(Defs.K_CEBOX, pid, Defs.F_CEBOX)
			var inner_fmt := fmt if fmt in [Defs.F_MODERN, Defs.F_JEWEL] else Defs.F_MODERN
			var inner := st.new_item(Defs.K_CASE, pid, inner_fmt)
			p.root = box.uid
			p.disc_box = inner.uid
			for i in t.discs:
				var d := st.new_item(Defs.K_DISC, pid, inner_fmt, i)
				p.discs.append(d.uid)
			for k in [Defs.K_ARTBOOK, Defs.K_FIGURE, Defs.K_POSTER]:
				var piece := st.new_item(k, pid, Defs.F_CEBOX)
				p.pieces.append(piece.uid)
			# assemble solved
			for d in p.discs:
				_put(st, d, inner.uid)
			_put(st, inner.uid, box.uid)
			for pc in p.pieces:
				_put(st, pc, box.uid)
		else:
			var root := st.new_item(Defs.K_CASE, pid, fmt)
			p.root = root.uid
			p.disc_box = root.uid
			for i in t.discs:
				var d := st.new_item(Defs.K_DISC, pid, fmt, i)
				p.discs.append(d.uid)
				_put(st, d.uid, root.uid)
			if fmt == Defs.F_BIGBOX:
				var m := st.new_item(Defs.K_MANUAL, pid, fmt)
				p.pieces.append(m.uid)
				_put(st, m.uid, root.uid)

static func _put(st: LevelState, child: int, cont: int) -> void:
	var c: LevelState.Item = st.items[child]
	var k: LevelState.Item = st.items[cont]
	c.parent = cont
	k.contents.append(child)
	c.xf = st.slot_xf(k, c, k.contents.size() - 1)

static func _make_tables(st: LevelState, layout: LevelLayout) -> void:
	for t in layout.sort_tables:
		var xf := Transform3D(Basis(Vector3.UP, t.yaw), t.pos)
		st.tables.append({"id": st.tables.size(), "xf": xf, "cells": t.cells,
			"cell_size": Vector2(t.size.x / t.cells.x, t.size.y / t.cells.y), "occupied": {}, "height": t.height})

static func _make_stashes(st: LevelState, layout: LevelLayout) -> void:
	for s in layout.stashes:
		st.stashes.append({"id": s.id, "items": [], "revealed": false, "spill": s.spill, "type": s.type, "pos": s.pos})

static func _make_carts(st: LevelState, layout: LevelLayout) -> void:
	for c in layout.carts:
		var it := st.new_item(Defs.K_CART, -1, 0)
		it.xf = Transform3D(Basis(Vector3.UP, c.yaw), c.pos)

# ------------------------------------------------------------------ the mess
class Heights:
	var h := {}
	func top(box_min: Vector2, box_max: Vector2) -> float:
		var y := 0.0
		for x in range(floori(box_min.x / MessGen.FLAT_CELL), floori(box_max.x / MessGen.FLAT_CELL) + 1):
			for z in range(floori(box_min.y / MessGen.FLAT_CELL), floori(box_max.y / MessGen.FLAT_CELL) + 1):
				y = maxf(y, h.get(Vector2i(x, z), 0.0))
		return y
	func put(box_min: Vector2, box_max: Vector2, y: float) -> void:
		for x in range(floori(box_min.x / MessGen.FLAT_CELL), floori(box_max.x / MessGen.FLAT_CELL) + 1):
			for z in range(floori(box_min.y / MessGen.FLAT_CELL), floori(box_max.y / MessGen.FLAT_CELL) + 1):
				h[Vector2i(x, z)] = maxf(h.get(Vector2i(x, z), 0.0), y)

static func _detach_raw(st: LevelState, uid: int) -> void:
	var it: LevelState.Item = st.items[uid]
	if it.parent >= 0:
		var k: LevelState.Item = st.items[it.parent]
		k.contents.remove_at(k.contents.find(uid))
		it.parent = -1
		for i in k.contents.size():
			var c: LevelState.Item = st.items[k.contents[i]]
			c.xf = st.slot_xf(k, c, i)

static func _wreck(st: LevelState, def: Dictionary, layout: LevelLayout, rng: RandomNumberGenerator) -> void:
	var heights := Heights.new()
	var loose: Array = []      # uids needing a floor/surface spot
	var level: int = def.id
	var hard := clampf((level - 1) / 4.0, 0.0, 1.0)
	# 1) CE pieces scattered, CE inner cases separated
	for p in st.products:
		if p.edition != Defs.E_CE:
			continue
		var box: LevelState.Item = st.items[p.root]
		for pc in p.pieces:
			if rng.randf() < 0.75:
				_detach_raw(st, pc)
				loose.append(pc)
		if rng.randf() < 0.7:
			_detach_raw(st, p.disc_box)
			loose.append(p.disc_box)
		box.open = rng.randf() < 0.6
	# 2) big-box manuals wander off
	for p in st.products:
		if p.fmt == Defs.F_BIGBOX and p.edition != Defs.E_CE:
			for pc in p.pieces:
				if rng.randf() < 0.55:
					_detach_raw(st, pc)
					loose.append(pc)
	# 3) loose discs
	var all_discs: Array = []
	for p in st.products:
		all_discs.append_array(p.discs)
	for d in all_discs:
		if rng.randf() < 0.42 + 0.1 * hard:
			_detach_raw(st, d)
			loose.append(d)
	# 4) wrong-case swaps among discs still in cases (cycles keep capacity intact)
	var in_case: Array = all_discs.filter(func(d): return st.items[d].parent >= 0)
	var swap_n := int(in_case.size() * (0.28 + 0.1 * hard))
	var chosen: Array = []
	for i in swap_n:
		if in_case.is_empty():
			break
		var k := rng.randi() % in_case.size()
		chosen.append(in_case[k])
		in_case.remove_at(k)
	if chosen.size() >= 2:
		var parents: Array = chosen.map(func(d): return st.items[d].parent)
		for d in chosen:
			_detach_raw(st, d)
		for i in chosen.size():
			var target: int = parents[(i + 1) % parents.size()]
			_put(st, chosen[i], target)
	# 5) two discs in one case: move some loose discs into cases with spare capacity
	var cases: Array = []
	for p in st.products:
		cases.append(p.disc_box)
	for i in int(loose.size() * 0.06):
		var d: int = loose[rng.randi() % loose.size()]
		if st.items[d].kind != Defs.K_DISC or st.items[d].parent >= 0:
			continue
		var c: int = cases[rng.randi() % cases.size()]
		var ci: LevelState.Item = st.items[c]
		if ci.parent < 0 and st.capacity_ok(st.items[d], ci):
			loose.erase(d)
			_put(st, d, c)
	# 6) roots: some correctly shelved, some wrongly shelved, the rest on the floor
	var roots: Array = []
	for p in st.products:
		roots.append(p.root)
	for p in st.products:
		if st.items[p.disc_box].parent < 0 and p.disc_box != p.root:
			pass
	var free_roots: Array = []
	for p in st.products:
		var r := rng.randf()
		var root: LevelState.Item = st.items[p.root]
		if r < 0.06:
			_shelve_raw(st, p.root, p.bucket)
		elif r < 0.10:
			var b := rng.randi() % st.buckets.size()
			if st.buckets[b].section == st.buckets[p.bucket].section and b != p.bucket or rng.randf() < 0.4:
				if not _shelve_raw(st, p.root, b):
					free_roots.append(p.root)
			else:
				free_roots.append(p.root)
		else:
			free_roots.append(p.root)
	# CE inner cases that are loose also need spots (already in loose)
	# 7) open cases lying around
	for u in free_roots:
		var it: LevelState.Item = st.items[u]
		if it.kind == Defs.K_CASE and rng.randf() < 0.33:
			it.open = true
	for u in loose:
		var it: LevelState.Item = st.items[u]
		if it.kind == Defs.K_CASE and rng.randf() < 0.4:
			it.open = true
	var to_place: Array = free_roots + loose
	# shuffle
	for i in range(to_place.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = to_place[i]; to_place[i] = to_place[j]; to_place[j] = tmp
	# 8) hide some in stashes
	var stash_cap := 7 if level < 5 else 14
	if not st.stashes.is_empty():
		var hide_n := mini(int(to_place.size() * (0.06 + 0.05 * hard)), st.stashes.size() * stash_cap)
		var hidden := 0
		var si := 0
		while hidden < hide_n and not to_place.is_empty():
			var s: Dictionary = st.stashes[si % st.stashes.size()]
			si += 1
			if (s.items as Array).size() >= stash_cap:
				continue
			var u: int = to_place.pop_back()
			st.items[u].stash = s.id
			s.items.append(u)
			hidden += 1
	# 9) place everything else: piles, scatter, surfaces
	var pile_centers: Array = []
	var n_piles := maxi(3, to_place.size() / 14)
	for i in n_piles:
		var c := layout.random_floor_point(rng, 0.55)
		if c != Vector3.INF:
			pile_centers.append(c)
	for u in to_place:
		var r := rng.randf()
		var placed := false
		if r < 0.14 and not layout.surfaces.is_empty():
			placed = _place_on_surface(st, layout, heights, u, rng)
		if not placed and r < 0.72 and not pile_centers.is_empty():
			var c: Vector3 = pile_centers[rng.randi() % pile_centers.size()]
			for attempt in 8:
				var off := Vector2(rng.randfn(0.0, 0.32), rng.randfn(0.0, 0.32))
				var p := c + Vector3(off.x, 0, off.y)
				if layout.is_free(p, 0.12):
					_place_flat(st, heights, u, p, rng)
					placed = true
					break
		if not placed:
			for attempt in 6:
				var p := layout.random_floor_point(rng, 0.14)
				if p != Vector3.INF:
					_place_flat(st, heights, u, p, rng)
					placed = true
					break
		if not placed:
			# fall back to a spawn point area
			var sp: Vector3 = layout.spawns[0] if not layout.spawns.is_empty() else Vector3.ZERO
			_place_flat(st, heights, u, sp + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), rng)

static func _shelve_raw(st: LevelState, uid: int, bid: int) -> bool:
	if not st.bucket_has_room(bid, uid):
		return false
	var it: LevelState.Item = st.items[uid]
	it.bucket = bid
	it.open = false if it.kind == Defs.K_CASE else it.open
	var arr: Array = st.buckets[bid].items
	arr.append(uid)
	arr.sort_custom(func(a, c): return st.sort_key_of(a) < st.sort_key_of(c))
	var cursor := 0.006
	var i := 0
	for u in arr:
		st.items[u].xf = st.bucket_item_xf(bid, i, u, cursor)
		cursor += st.thickness_of(u)
		i += 1
	return true

static func _lying_basis(st: LevelState, it: LevelState.Item, rng: RandomNumberGenerator) -> Array:
	# returns [basis, up_extent]
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	var s := st.size_of(it)
	match it.kind:
		Defs.K_DISC:
			if rng.randf() < 0.4:
				return [yaw * Basis(Vector3.RIGHT, PI), s.y]
			return [yaw, s.y]
		Defs.K_CEBOX, Defs.K_FIGURE:
			return [yaw, s.y]
		Defs.K_POSTER:
			return [yaw * Basis(Vector3.BACK, PI * 0.5), s.x]
		Defs.K_CASE:
			if it.fmt in [Defs.F_BIGBOX, Defs.F_LONGBOX] and rng.randf() < 0.5:
				return [yaw, s.y]
			if it.open and LevelState.is_flip_case(it):
				return [yaw * Basis(Vector3.RIGHT, -PI * 0.5), s.z]
			if rng.randf() < 0.3:
				return [yaw * Basis(Vector3.RIGHT, PI * 0.5), s.z]
			return [yaw * Basis(Vector3.RIGHT, -PI * 0.5), s.z]
	return [yaw * Basis(Vector3.RIGHT, -PI * 0.5), s.z]

static func _place_flat(st: LevelState, heights: Heights, uid: int, p: Vector3, rng: RandomNumberGenerator, base_y := 0.0) -> void:
	var it: LevelState.Item = st.items[uid]
	var lb := _lying_basis(st, it, rng)
	var basis: Basis = lb[0]
	var up: float = lb[1]
	# footprint (world XZ) of the local AABB rotated
	var box := st.local_aabb(it)
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in 8:
		var corner := box.get_endpoint(i)
		var w := basis * corner
		mn = Vector2(minf(mn.x, w.x), minf(mn.y, w.z))
		mx = Vector2(maxf(mx.x, w.x), maxf(mx.y, w.z))
	# local box min along up after rotation
	var miny := 1e9
	var maxy := -1e9
	for i in 8:
		var w2 := basis * box.get_endpoint(i)
		miny = minf(miny, w2.y)
		maxy = maxf(maxy, w2.y)
	mn += Vector2(p.x, p.z)
	mx += Vector2(p.x, p.z)
	var y := maxf(heights.top(mn, mx), base_y)
	if y > 0.9 + base_y:
		y = base_y  # avoid towers: just overlap on the floor
	var center_y := y - miny + 0.001
	it.xf = Transform3D(basis, Vector3(p.x, center_y, p.z))
	heights.put(mn, mx, y + (maxy - miny))

static func _place_on_surface(st: LevelState, layout: LevelLayout, heights: Heights, uid: int, rng: RandomNumberGenerator) -> bool:
	var s: Dictionary = layout.surfaces[rng.randi() % layout.surfaces.size()]
	var r: Rect2 = s.rect
	if r.size.x < 0.25 or r.size.y < 0.25:
		return false
	for attempt in 6:
		var p := Vector3(rng.randf_range(r.position.x + 0.1, r.end.x - 0.1), s.y, rng.randf_range(r.position.y + 0.1, r.end.y - 0.1))
		if layout.is_free_on_surface(p, 0.12):
			_place_flat(st, heights, uid, Vector3(p.x, 0, p.z), rng, s.y)
			return true
	return false
