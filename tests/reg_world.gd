extends Node
## M1 / audit A2: the playable area is closed.
## Before the fix every window was a hole in the visible wall with no collider, so players walked
## out of the map through the storefront (and fell forever, with no recovery).
var runner

func run() -> void:
	_is_inside_unit()
	for lv in [1, 2, 3, 4, 5, 6]:
		await _level_openings(lv)
	await _walk_out_store()
	await _recovery()

func _is_inside_unit() -> void:
	var L := LevelLayout.new()
	L.add_room("a", Rect2(0, 0, 4, 4))
	L.add_room("b", Rect2(4, 0, 4, 4))
	runner.check(L.is_inside(Vector3(2, 0, 2)), "A2: point inside a room is inside")
	runner.check(L.is_inside(Vector3(4.0, 0, 2)), "A2: shared edge between rooms is inside")
	runner.check(L.is_inside(Vector3(-0.2, 0, 2)), "A2: within wall thickness of the outer wall is inside")
	runner.check(not L.is_inside(Vector3(-2.0, 0, 2)), "A2: 2 m outside the building is outside")
	runner.check(not L.is_inside(Vector3(300, 0, 300)), "A2: far away is outside")
	for lv in [1, 2, 3, 4, 5, 6]:
		var def := Levels.get_def(lv, 300, 5)
		var Lv := Layouts.build(def, 5)
		var all_in := true
		for sp in Lv.spawns:
			all_in = all_in and Lv.is_inside(sp)
		runner.check(all_in and not Lv.spawns.is_empty(), "A2: every spawn point of level %d is inside" % lv)

func _level_openings(lv: int) -> void:
	var main := await TestUtil.boot(get_tree(), lv)
	var L: LevelLayout = Game.layout
	var space: PhysicsDirectSpaceState3D = Game.level_root.get_world_3d().direct_space_state
	var open_windows := 0
	for w in L.windows:
		var wall_pt := Vector3(w.pos.x, w.sill + w.height * 0.5, w.pos.y)
		var rc := L.bounds.get_center()
		var inward := Vector3(rc.x - wall_pt.x, 0, rc.y - wall_pt.z)
		inward = Vector3(signf(inward.x) if absf(inward.x) > absf(inward.z) else 0.0, 0, signf(inward.z) if absf(inward.z) >= absf(inward.x) else 0.0)
		var q := PhysicsRayQueryParameters3D.create(wall_pt + inward * 0.6, wall_pt - inward * 1.2, Defs.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			open_windows += 1
	runner.check(open_windows == 0, "A2: level %d - all %d window openings are solid (%d open)" % [lv, L.windows.size(), open_windows])
	# doors must stay walk-through: at least one perpendicular axis is free at hip height
	var blocked_doors := 0
	for d in L.doors:
		var c := Vector3(d.pos.x, 1.0, d.pos.y)
		var free := false
		for ax in [Vector3.RIGHT, Vector3.BACK]:
			var q2 := PhysicsRayQueryParameters3D.create(c - ax * 0.7, c + ax * 0.7, Defs.LAYER_WORLD)
			if space.intersect_ray(q2).is_empty():
				free = true
		if not free:
			blocked_doors += 1
	runner.check(blocked_doors == 0, "A2: level %d - all %d doorways stay open (%d blocked)" % [lv, L.doors.size(), blocked_doors])
	await TestUtil.shutdown(get_tree(), main)

func _walk_out_store() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var p: Player = Game.local_player
	var L: LevelLayout = Game.layout
	var w: Dictionary = L.windows[1]   # the wide storefront window with the low sill
	p.global_position = Vector3(w.pos.x, 0.05, w.pos.y - 2.0)
	p.look_yaw = PI   # face +Z (outside)
	p.touch_move = Vector2(0, -1)
	await TestUtil.frames(get_tree(), 150)
	p.touch_move = Vector2.ZERO
	runner.check(p.global_position.z <= L.bounds.end.y + 0.25, "A2: walking into the storefront window stops at the glass (z=%.2f, wall at %.2f)" % [p.global_position.z, L.bounds.end.y])
	runner.check(p.oob_recoveries == 0, "A2: the glass stops the player; the recovery guard was not needed")
	# the same through every window of the level, from inside, towards the nearest outside
	var escaped := 0
	for ww in L.windows:
		var rc := L.bounds.get_center()
		var inward := Vector2(rc.x - ww.pos.x, rc.y - ww.pos.y)
		inward = Vector2(signf(inward.x), 0) if absf(inward.x) > absf(inward.y) else Vector2(0, signf(inward.y))
		var start := Vector3(ww.pos.x + inward.x * 1.2, 0.05, ww.pos.y + inward.y * 1.2)
		p.global_position = start
		p.velocity = Vector3.ZERO
		p.look_yaw = atan2(inward.x, inward.y)   # facing out through the window
		p.touch_move = Vector2(0, -1)
		await TestUtil.frames(get_tree(), 90)
		p.touch_move = Vector2.ZERO
		if not L.is_inside(p.global_position, 0.0) and p.oob_recoveries == 0:
			escaped += 1
	runner.check(escaped == 0, "A2: no window of the store can be walked through (%d of %d escaped)" % [escaped, L.windows.size()])
	await TestUtil.shutdown(get_tree(), main)

func _recovery() -> void:
	var main := await TestUtil.boot(get_tree(), 1)
	var p: Player = Game.local_player
	await TestUtil.frames(get_tree(), 30)
	var good := p.global_position
	p.global_position = Vector3(300, 1, 300)
	await TestUtil.frames(get_tree(), 3)
	runner.check(Game.layout.is_inside(p.global_position) and p.oob_recoveries == 1, "A2: a player placed far outside the map is brought back")
	runner.check(p.global_position.distance_to(good) < 1.0, "A2: ...to the last good floor position (%.2f m away)" % p.global_position.distance_to(good))
	p.global_position = Vector3(p.global_position.x, -30, p.global_position.z)
	await TestUtil.frames(get_tree(), 3)
	runner.check(p.global_position.y > -1.0 and p.oob_recoveries == 2, "A2: a player that fell through the world is brought back")
	var before := p.oob_recoveries
	await TestUtil.frames(get_tree(), 60)
	runner.check(p.oob_recoveries == before, "A2: normal standing never triggers recovery")
	await TestUtil.shutdown(get_tree(), main)
