extends Node
## Headless test runner. Run as a scene so autoloads exist:
##   godot --headless --path . res://tests/test_runner.tscn -- --suite=all
## Exit code 0 = pass. Each suite prints PASS/FAIL lines.

var failures := 0
var suite := "all"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite = a.substr(8)
	get_tree().create_timer(900.0).timeout.connect(func(): print("WATCHDOG TIMEOUT"); get_tree().quit(3))
	await get_tree().process_frame
	var suites := {
		"scripts": preload("res://tests/suite_scripts.gd"),
		"levels": preload("res://tests/suite_levels.gd"),
		"gameplay": preload("res://tests/suite_gameplay.gd"),
		"sweep": preload("res://tests/suite_sweep.gd"),
		"reg_misc": preload("res://tests/reg_misc.gd"),
		"reg_targeting": preload("res://tests/reg_targeting.gd"),
		"reg_world": preload("res://tests/reg_world.gd"),
	}
	for name in suites:
		if suite != "all" and suite != name:
			continue
		print("=== SUITE ", name, " ===")
		var s = suites[name].new()
		s.runner = self
		add_child(s)
		await s.run()
	print("=== RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures, " ===")
	get_tree().quit(0 if failures == 0 else 1)

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)
