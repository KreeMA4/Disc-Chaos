extends Node
## M1 regression tests for small fixes: C9 validator, C7 layout. (B13/B15 live in reg_saves.)
var runner

func run() -> void:
	_c9_validator_vertical_range()
	_c7_desk_items_sit_on_desks()

## C9: the level validator treated a raised obstacle (desk-top PC tower at y=0.77) as a
## full-height column, so a floor item underneath was reported as "inside an obstacle".
func _c9_validator_vertical_range() -> void:
	var suite = load("res://tests/suite_levels.gd").new()
	var L := LevelLayout.new()
	L.add_room("t", Rect2(0, 0, 10, 10), 2.7)
	L.obstacles.append(AABB(Vector3(2, 0.77, 2), Vector3(1, 0.48, 1)))   # raised: y 0.77..1.25
	L.obstacles.append(AABB(Vector3(6, 0.0, 6), Vector3(1, 0.9, 1)))     # floor-standing
	runner.check(suite._valid_point(L, Vector3(2.5, 0.003, 2.5)), "C9: floor item under a raised obstacle is valid")
	runner.check(not suite._valid_point(L, Vector3(2.5, 1.0, 2.5)), "C9: point inside the raised obstacle is still invalid")
	runner.check(not suite._valid_point(L, Vector3(6.5, 0.4, 6.5)), "C9: point inside a floor-standing obstacle is still invalid")
	runner.check(suite._valid_point(L, Vector3(6.5, 1.0, 6.5)), "C9: item resting on top of a floor-standing obstacle is valid")
	runner.check(not suite._valid_point(L, Vector3(20, 0.1, 20)), "C9: point outside every room is invalid")
	suite.free()

## C7: the den's PC tower hung 0.14 m off the end of its desk. Every desk-top PC part in every level
## must sit fully inside the footprint of the desk under it.
func _c7_desk_items_sit_on_desks() -> void:
	var checked := 0
	var bad: Array = []
	for lv in [1, 2, 3, 4, 5, 6]:
		var L := Layouts.build(Levels.get_def(lv, 300, 5), 5)
		for p in L.props:
			if p.type != "monitor" and p.type != "pc_tower":
				continue
			if p.pos.y < 0.7 or p.pos.y > 0.85:
				continue   # not on a 0.76 m desk
			var pe := LevelLayout._rotated_extent(p.size, p.yaw)
			var pr := Rect2(p.pos.x - pe.x * 0.5, p.pos.z - pe.z * 0.5, pe.x, pe.z)
			var desk_rect := Rect2()
			var found := false
			for d in L.props:
				if d.type != "desk":
					continue
				var de := LevelLayout._rotated_extent(d.size, d.yaw)
				var dr := Rect2(d.pos.x - de.x * 0.5, d.pos.z - de.z * 0.5, de.x, de.z)
				if dr.has_point(Vector2(p.pos.x, p.pos.z)):
					desk_rect = dr
					found = true
			checked += 1
			if not found or not desk_rect.grow(0.02).encloses(pr):
				bad.append("L%d %s at %s" % [lv, p.type, str(p.pos)])
	runner.check(checked >= 4, "C7: found the desk-top PC parts to check (%d)" % checked)
	runner.check(bad.is_empty(), "C7: every monitor / PC tower sits inside its desk's footprint %s" % str(bad))
	# the two den monitors and the tower do not overlap each other
	var L2 := Layouts.build(Levels.get_def(2, 300, 5), 5)
	var rects: Array = []
	for p in L2.props:
		if (p.type == "monitor" or p.type == "pc_tower") and p.pos.x > 13.0:
			var pe := LevelLayout._rotated_extent(p.size, p.yaw)
			rects.append(Rect2(p.pos.x - pe.x * 0.5, p.pos.z - pe.z * 0.5, pe.x, pe.z))
	var overlap := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-0.03).intersects(rects[j]):
				overlap += 1
	runner.check(rects.size() == 3 and overlap == 0, "C7: the den's two monitors and PC tower do not overlap (%d parts, %d overlaps)" % [rects.size(), overlap])
