extends Node
## Generator sweep (M1 gate): runs the level validator + bot solver over many seeds.
## Default is the full 188-level sweep (~20 s headless); `-- --seeds=quick` runs a 38-level subset.
## Known regressions (seeds that once failed) are always included.
var runner

const KNOWN := [[2, 30]]    # L2 seed 30: validator false positive (C9)

func run() -> void:
	var full := not ("--seeds=quick" in OS.get_cmdline_user_args())
	var plan := {1: 40, 2: 40, 3: 40, 4: 40, 5: 14, 6: 14} if full else {1: 8, 2: 8, 3: 8, 4: 8, 5: 2, 6: 3}
	var suite = load("res://tests/suite_levels.gd").new()
	suite.runner = self
	add_child(suite)
	var t0 := Time.get_ticks_msec()
	var failing: Array = []
	var levels := 0
	var jobs: Array = []
	for lv in plan:
		for s in range(3, 3 + int(plan[lv])):
			jobs.append([lv, s])
	for k in KNOWN:
		if not jobs.has(k):
			jobs.append(k)
	for job in jobs:
		var lv: int = job[0]
		var seed: int = job[1]
		var def := Levels.get_def(lv, [150, 400, 900, 1500][seed % 4] if lv == 6 else 400, seed)
		var before := _fails
		_cur = "L%d seed %d" % [lv, seed]
		suite._test_level(def, seed)
		levels += 1
		if _fails > before:
			failing.append(_cur)
		await get_tree().process_frame
	runner.check(failing.is_empty(), "sweep: %d generated levels, %d checks, failing: %s (%d ms)" % [levels, _checks, str(failing), Time.get_ticks_msec() - t0])

# The inner suite reports through this object so one failure is attributable to its seed.
var _checks := 0
var _fails := 0
var _cur := ""
func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("    FAIL (", _cur, "): ", msg)
