extends Node
## Dev tool: count triangles per node group after loading a level. -- --tri-count=<level>
func _ready() -> void:
	var lv := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tri-count="):
			lv = int(a.substr(12))
	await get_tree().create_timer(0.3).timeout
	Game.main.start_solo(lv)
	await Game.level_loaded
	var groups := {}
	_walk(Game.level_root, groups)
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a] > groups[b])
	var total := 0
	for k in keys:
		total += groups[k]
	for k in keys.slice(0, 25):
		print("%-40s %8d" % [k, groups[k]])
	print("TOTAL ", total)
	get_tree().quit()

func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var a = m.surface_get_arrays(i)
		var idx = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx else a[Mesh.ARRAY_VERTEX].size()) / 3
	return n

func _walk(n: Node, g: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh:
		var key := String(n.name).get_slice("_", 0) + "_" + String(n.name).get_slice("_", n.name.get_slice_count("_") - 1)
		g[key] = g.get(key, 0) + _tris(n.mesh)
	elif n is MultiMeshInstance3D:
		var mm: MultiMesh = n.multimesh
		var key2 := "MM_" + String(n.name).get_slice("_", 3) + ("_lod" if String(n.name).ends_with("lod") else "")
		g[key2] = g.get(key2, 0) + _tris(mm.mesh) * mm.visible_instance_count
	for c in n.get_children():
		_walk(c, g)
