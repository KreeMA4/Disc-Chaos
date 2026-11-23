extends Node
## M1 regression tests for small fixes: C9 validator, (later commits add B13, B15, C7).
var runner

func run() -> void:
	_c9_validator_vertical_range()

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
