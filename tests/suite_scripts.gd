extends Node
## Every script parses, every scene loads and instantiates.
var runner

func _collect(dir: String, ext: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_collect(dir.path_join(f), ext, out)
		elif f.ends_with(ext):
			out.append(dir.path_join(f))
		f = d.get_next()

func run() -> void:
	var scripts: Array = []
	_collect("res://scripts", ".gd", scripts)
	_collect("res://tests", ".gd", scripts)
	var bad := 0
	for p in scripts:
		var s = load(p)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			bad += 1
			print("    bad script: ", p)
	runner.check(bad == 0, "%d scripts parse" % scripts.size())
	var scenes: Array = []
	_collect("res://scenes", ".tscn", scenes)
	_collect("res://tests", ".tscn", scenes)
	var bad_sc := 0
	for p in scenes:
		var ps = load(p)
		if ps == null or not (ps is PackedScene) or not ps.can_instantiate():
			bad_sc += 1
			print("    bad scene: ", p)
	runner.check(bad_sc == 0, "%d scenes load" % scenes.size())
