extends SceneTree
func _init():
	create_timer(50).timeout.connect(func(): print("WATCHDOG TIMEOUT"); quit(3))
	await process_frame
	var cat = root.get_node("Catalog")
	print("titles: ", cat.titles.size())
	for i in 14:
		var t = cat.titles[i * 34]
		print("  ", t.gid, " | ", t.name, " | ", Defs.GENRE_NAMES[t.genre], " | ", t.year, " discs=", t.discs, " eds=", t.editions)
	var def = Levels.get_def(1)
	var L = Layouts.build(def, 1)
	var st = MessGen.build(def, L, 1)
	print("products ", st.products.size(), " items ", st.items.size(), " sections ", st.sections.size(), " buckets ", st.buckets.size())
	for b in st.buckets:
		print("  bucket ", b.label, " sec ", b.section, " n_target ", st.products.filter(func(p): return p.bucket == b.id).size(), " w ", snapped(b.width, 0.01))
	quit(0)
