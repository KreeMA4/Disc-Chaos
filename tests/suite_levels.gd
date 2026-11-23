extends Node
## Generates every level, validates it and solves it with the bot. Prints playtime estimates.
var runner
var report: Array = []

func run() -> void:
	var ids := [1, 2, 3, 4, 5, 6, 106, 206]
	for id0 in ids:
		var id: int = id0 % 100
		var wh_items: int = [400, 150, 1200][id0 / 100]
		var def := Levels.get_def(id, wh_items, 77 + id0)
		if not Layouts.IMPLEMENTED.has(def.layout):
			continue
		for seed in [1, 2]:
			await get_tree().process_frame
			_test_level(def, seed)
	var f := FileAccess.open("res://tests/out/level_report.txt", FileAccess.WRITE) if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out")) == OK else null
	if f:
		f.store_string("\n".join(report))
	print("\n".join(report))

func _test_level(def: Dictionary, seed: int) -> void:
	var tag := "L%d(%s) seed %d" % [def.id, def.layout, seed]
	var t0 := Time.get_ticks_msec()
	var L := Layouts.build(def, seed)
	var st := MessGen.build(def, L, seed)
	var gen_ms := Time.get_ticks_msec() - t0
	var n_items := st.items.filter(func(i): return i.kind != Defs.K_CART).size()
	runner.check(st.products.size() > 0, "%s generated %d products / %d items in %d ms" % [tag, st.products.size(), n_items, gen_ms])
	runner.check(absf(n_items - def.target_items) <= def.target_items * 0.12 + 6, "%s item count %d near target %d" % [tag, n_items, def.target_items])
	# --- every disc has exactly one correct case
	var disc_owner := {}
	var ok_discs := true
	for p in st.products:
		var box: LevelState.Item = st.items[p.disc_box]
		if box.kind != Defs.K_CASE:
			ok_discs = false
		for d in p.discs:
			if disc_owner.has(d) or st.items[d].kind != Defs.K_DISC:
				ok_discs = false
			disc_owner[d] = p.pid
	var all_discs := st.items.filter(func(i): return i.kind == Defs.K_DISC)
	runner.check(ok_discs and disc_owner.size() == all_discs.size(), "%s every disc (%d) has exactly one correct case" % [tag, all_discs.size()])
	# --- every product has exactly one valid bucket with room
	var ok_b := true
	var need := {}
	for p in st.products:
		if p.bucket < 0 or p.bucket >= st.buckets.size():
			ok_b = false
			continue
		var b: Dictionary = st.buckets[p.bucket]
		var s: Vector3 = st.size_of(st.items[p.root])
		if s.y > b.height + 0.001 or s.x > b.depth + 0.04:
			ok_b = false
			print("    too big for bucket: pid ", p.pid)
		need[p.bucket] = need.get(p.bucket, 0.0) + st.thickness_of(p.root)
	for bid in need:
		if need[bid] > st.buckets[bid].width + 0.0001:
			ok_b = false
			print("    bucket overflow ", bid, " need ", need[bid], " width ", st.buckets[bid].width)
	runner.check(ok_b, "%s every product has one target slot with room (%d buckets)" % [tag, st.buckets.size()])
	# --- buckets are sorted A-Z: target ranges don't overlap within a section
	var sorted_ok := true
	for sec in st.sections:
		if sec.platform < 0:
			continue  # Collector's section is grouped by platform, A-Z inside each bucket
		var last := ""
		for bid in sec.buckets:
			var keys: Array = st.products.filter(func(p): return p.bucket == bid).map(func(p): return p.sort)
			keys.sort()
			if keys.is_empty():
				continue
			if keys[0] < last:
				sorted_ok = false
			last = keys[keys.size() - 1]
	runner.check(sorted_ok, "%s bucket ranges are A–Z ordered" % tag)
	# --- nothing inside walls / outside the map
	var bad := 0
	for it in st.items:
		if it.kind == Defs.K_CART:
			continue
		if it.parent >= 0 or it.bucket >= 0 or it.stash >= 0 or it.table >= 0:
			continue
		var p: Vector3 = it.xf.origin
		if not _valid_point(L, p):
			bad += 1
			if bad < 5:
				print("    bad spawn uid ", it.uid, " at ", p)
	for s in L.stashes:
		if not L.is_free(s.spill, 0.1) and not _valid_point(L, s.spill):
			bad += 1
			print("    bad stash spill ", s.id, " ", s.spill)
	for b in st.buckets:
		var o: Vector3 = (b.xf as Transform3D).origin
		if L.room_at(Vector2(o.x, o.z)) < 0:
			bad += 1
			print("    bucket outside map ", b.id, " ", o)
	for sp in L.spawns:
		if not L.is_free(sp + Vector3(0, 0.1, 0), 0.3):
			bad += 1
			print("    bad player spawn ", sp)
	runner.check(bad == 0, "%s nothing spawns in walls/obstacles or outside the map" % tag)
	# --- serialization round trip
	var bytes := st.serialize()
	var st2 := MessGen.build(def, Layouts.build(def, seed), seed)
	st2.deserialize(bytes)
	runner.check(st2.checksum() == st.checksum(), "%s save/sync round-trip (%d bytes)" % [tag, bytes.size()])
	# --- bot solve
	var start: Vector3 = L.spawns[0] if not L.spawns.is_empty() else Vector3.ZERO
	var bot := BotSolver.new(st, start)
	var t1 := Time.get_ticks_msec()
	var solved := bot.solve()
	runner.check(solved and bot.log_errors.is_empty(), "%s bot solves 100%% (%d/%d) in %d ms %s" % [tag, st.solved_count, st.products.size(), Time.get_ticks_msec() - t1, str(bot.log_errors.slice(0, 3))])
	var solo_min := bot.time / 60.0
	var four_min := solo_min / (4.0 * 0.82)
	if seed == 1:
		report.append("%-28s products %4d items %4d stashes %2d | est. solo %6.1f min | 4 players %5.1f min | walked %5.0f m" % [
			"L%d %s" % [def.id, def.name if def.id != 6 else "Warehouse x%d" % def.target_items], st.products.size(), n_items, L.stashes.size(), solo_min, four_min, bot.walked])

func _valid_point(L: LevelLayout, p: Vector3) -> bool:
	var r := L.room_at(Vector2(p.x, p.z))
	if r < 0:
		return false
	if p.y < -0.01 or p.y > float(L.rooms[r].height):
		return false
	for box in L.obstacles:
		var b: AABB = box
		if p.x > b.position.x and p.x < b.end.x and p.z > b.position.z and p.z < b.end.z:
			if p.y < b.end.y - 0.03:
				return false
	return true
