extends Node
## Cover art service.
## - Builds per-level texture-array atlases (front covers, spines, disc labels) so thousands of
##   items share a handful of materials and draw calls.
## - Renders high-resolution parts on demand for held/inspected items (>= 512 px tall).
## - Caches everything under user://covercache/ and honours override PNGs:
##     res://covers_override/<game_id>_<part>.png  (part: front, back, spine, disc, steelbook)
##     res://covers_override/<game_id>_<edition>_<part>.png  (edition: std, steel, ce, gold)
##   and the same names under user://covers_override/ (handy on a phone).

signal progress(frac: float, text: String)

const PAINTER := preload("res://scripts/covers/cover_painter.gd")
const COVER_CELL := Vector2i(96, 136)
const SPINE_CELL := Vector2i(204, 20)
const LABEL_CELL := Vector2i(96, 96)
const HIRES_H := 528
const FONT_FILES := ["lilita-one", "fredoka", "fredoka-regular", "bungee", "press-start-2p", "creepster",
	"orbitron", "racing-sans-one", "permanent-marker", "black-ops-one", "monoton", "righteous"]

var fonts := {}
var noise_tex: Texture2D
var headless := false

var covers_arr: Texture2DArray
var spines_arr: Texture2DArray
var labels_arr: Texture2DArray
var cover_index := {}    # pid -> cell
var label_index := {}    # disc uid -> cell

# shared materials
var mm_mats := {}        # mode -> ShaderMaterial (multimesh)
var single_mats := {}    # mode -> ShaderMaterial (instance uniforms)

var _vp: SubViewport
var _painter: Control
var _busy := false
var _hires_cache := {}   # key -> Texture2D
var _hires_order: Array = []
var _hires_queue: Array = []
var _hires_waiters := {} # key -> Array[Callable]

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	for f in FONT_FILES:
		var path := "res://assets/fonts/%s.woff2" % f
		if ResourceLoader.exists(path):
			fonts[f] = load(path)
	var fl := FastNoiseLite.new()
	fl.frequency = 0.08
	fl.fractal_octaves = 3
	var img := fl.get_seamless_image(128, 128)
	img.convert(Image.FORMAT_RGBA8)
	noise_tex = ImageTexture.create_from_image(img)
	_make_materials()
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(64, 64)
	add_child(_vp)
	_painter = Control.new()
	_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_painter)
	_set_placeholder_arrays()

func _make_materials() -> void:
	var mm := load("res://shaders/item_mm.gdshader")
	var single := load("res://shaders/item_single.gdshader")
	for mode in 4:
		var a := ShaderMaterial.new()
		a.shader = mm
		a.set_shader_parameter("mode", mode)
		mm_mats[mode] = a
		var b := ShaderMaterial.new()
		b.shader = single
		b.set_shader_parameter("mode", mode)
		single_mats[mode] = b

func _set_placeholder_arrays() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.85))
	var arr := Texture2DArray.new()
	arr.create_from_images([img])
	covers_arr = arr
	spines_arr = arr
	labels_arr = arr
	_apply_arrays(Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1), Vector2(1, 1))

func _apply_arrays(cg: Vector2, cc: Vector2, sg: Vector2, sc: Vector2, lg: Vector2, lc: Vector2) -> void:
	for m in mm_mats.values() + single_mats.values():
		m.set_shader_parameter("covers", covers_arr)
		m.set_shader_parameter("spines", spines_arr)
		m.set_shader_parameter("labels", labels_arr)
		m.set_shader_parameter("cover_grid", cg)
		m.set_shader_parameter("cover_cell", cc)
		m.set_shader_parameter("spine_grid", sg)
		m.set_shader_parameter("spine_cell", sc)
		m.set_shader_parameter("label_grid", lg)
		m.set_shader_parameter("label_cell", lc)

func set_dust(amount: float) -> void:
	for m in mm_mats.values() + single_mats.values():
		m.set_shader_parameter("dust_amount", amount)

# ======================================================================== overrides
func _override(t: Dictionary, edition: int, part: String) -> Texture2D:
	var names := ["%s_%s_%s" % [t.gid, String(Defs.EDITION_SHORT[edition]).to_lower(), part], "%s_%s" % [t.gid, part]]
	if part == "front" and edition == Defs.E_STEEL:
		names.insert(1, "%s_steelbook" % t.gid)
	for n in names:
		var rp := "res://covers_override/%s.png" % n
		if ResourceLoader.exists(rp):
			var tex = load(rp)
			if tex is Texture2D:
				return tex
		var up := "user://covers_override/%s.png" % n
		if FileAccess.file_exists(up):
			var img := Image.load_from_file(up)
			if img:
				return ImageTexture.create_from_image(img)
	return null

static func format_aspect(fmt: int, kind: int) -> float:
	var s := Defs.item_size(kind, fmt)
	return s.x / s.y

# ======================================================================== atlases
func _grid_for(count: int, cell: Vector2i) -> Dictionary:
	# smallest square power-of-two page (<= 2048) that holds all cells, else multiple 2048 layers
	var size := 256
	while size < 2048:
		var g := Vector2i(size / cell.x, size / cell.y)
		if g.x * g.y >= count:
			break
		size *= 2
	var grid := Vector2i(size / cell.x, size / cell.y)
	var per := grid.x * grid.y
	var layers := int(ceil(float(maxi(count, 1)) / per))
	return {"size": size, "grid": grid, "per": per, "layers": layers}

func build_level_atlases(st: LevelState) -> void:
	cover_index.clear()
	label_index.clear()
	var cover_jobs: Array = []
	var spine_jobs: Array = []
	var label_jobs: Array = []
	for p in st.products:
		var t: Dictionary = Catalog.titles[p.title]
		var root: LevelState.Item = st.items[p.root]
		cover_index[p.pid] = cover_jobs.size()
		var part := "steel" if p.edition == Defs.E_STEEL else "front"
		var rs := Defs.item_size(root.kind, root.fmt)
		cover_jobs.append({"part": part, "title": t, "edition": p.edition, "vaspect": rs.x / rs.y,
			"override": _override(t, p.edition, "front")})
		spine_jobs.append({"part": "spine", "title": t, "edition": p.edition, "vaspect": rs.y / rs.z,
			"override": _override(t, p.edition, "spine"), "override_rotate": true})
		for i in (p.discs as Array).size():
			label_index[p.discs[i]] = label_jobs.size()
			label_jobs.append({"part": "label", "title": t, "edition": p.edition, "disc": i, "vaspect": 1.0,
				"override": _override(t, p.edition, "disc")})
	var key := "%d_%d_%d_%d" % [Defs.CATALOG_VERSION, st.level_id, st.seed, st.products.size()]
	var cg := _grid_for(cover_jobs.size(), COVER_CELL)
	var sg := _grid_for(spine_jobs.size(), SPINE_CELL)
	var lg := _grid_for(label_jobs.size(), LABEL_CELL)
	if headless:
		_set_placeholder_arrays()
		return
	progress.emit(0.0, "Painting cover art...")
	covers_arr = await _render_array(cover_jobs, COVER_CELL, cg, "c_" + key, 0.0, 0.5)
	spines_arr = await _render_array(spine_jobs, SPINE_CELL, sg, "s_" + key, 0.5, 0.7)
	labels_arr = await _render_array(label_jobs, LABEL_CELL, lg, "l_" + key, 0.7, 1.0)
	_apply_arrays(Vector2(cg.grid), Vector2(COVER_CELL) / cg.size, Vector2(sg.grid), Vector2(SPINE_CELL) / sg.size,
		Vector2(lg.grid), Vector2(LABEL_CELL) / lg.size)
	progress.emit(1.0, "Cover art ready")

func _render_array(jobs: Array, cell: Vector2i, g: Dictionary, cache_key: String, p0: float, p1: float) -> Texture2DArray:
	var images: Array = []
	var dir := "user://covercache"
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in g.layers:
		var path := "%s/%s_%d.png" % [dir, cache_key, layer]
		var img: Image = null
		if FileAccess.file_exists(path) and not Settings.get_value("dev_no_cover_cache", false):
			img = Image.load_from_file(path)
			if img and img.get_width() != g.size:
				img = null
		if img == null:
			var page: Array = []
			for i in range(layer * g.per, mini((layer + 1) * g.per, jobs.size())):
				var j: Dictionary = jobs[i].duplicate()
				var li: int = i - layer * g.per
				j.rect = Rect2(Vector2((li % g.grid.x) * cell.x, (li / g.grid.x) * cell.y), Vector2(cell))
				var va: float = j.get("vaspect", float(cell.x) / cell.y)
				if absf(va - float(cell.x) / cell.y) > 0.03:
					j.vsize = Vector2(cell.y * va, cell.y) if va < float(cell.x) / cell.y else Vector2(cell.x, cell.x / va)
				page.append(j)
			img = await _render_page(page, Vector2i(g.size, g.size))
			img.save_png(path)
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		images.append(img)
		progress.emit(lerpf(p0, p1, float(layer + 1) / g.layers), "Painting cover art...")
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	return arr

func _render_page(page: Array, size: Vector2i) -> Image:
	while _busy:
		await get_tree().process_frame
	_busy = true
	_vp.size = size
	for j in page:
		var cell = PAINTER.new()
		cell.setup(j, fonts, noise_tex)
		_painter.add_child(cell)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	for c in _painter.get_children():
		c.queue_free()
	_busy = false
	return img

# ======================================================================== hi-res
func hires_key(title_idx: int, edition: int, part: String, disc := 0) -> String:
	return "%s_%d_%s_%d" % [Catalog.titles[title_idx].gid, edition, part, disc]

## Returns a cached texture immediately, or null and calls cb(tex) when ready.
func get_hires(title_idx: int, edition: int, part: String, disc := 0, fmt := Defs.F_MODERN, kind := Defs.K_CASE, cb := Callable()) -> Texture2D:
	if headless:
		return null
	var key := hires_key(title_idx, edition, part, disc)
	if _hires_cache.has(key):
		_touch(key)
		return _hires_cache[key]
	if cb.is_valid():
		if not _hires_waiters.has(key):
			_hires_waiters[key] = []
			_hires_queue.append({"key": key, "title": title_idx, "edition": edition, "part": part, "disc": disc, "fmt": fmt, "kind": kind})
		_hires_waiters[key].append(cb)
		if _hires_queue.size() == 1:
			_pump_hires()
	return null

func _touch(key: String) -> void:
	_hires_order.erase(key)
	_hires_order.append(key)
	while _hires_order.size() > 64:
		var old: String = _hires_order.pop_front()
		_hires_cache.erase(old)

func _pump_hires() -> void:
	while not _hires_queue.is_empty():
		var job: Dictionary = _hires_queue[0]
		var tex := await _render_hires(job)
		_hires_queue.pop_front()
		_hires_cache[job.key] = tex
		_touch(job.key)
		for cb in _hires_waiters.get(job.key, []):
			if cb.is_valid():
				cb.call(tex)
		_hires_waiters.erase(job.key)

func _render_hires(job: Dictionary) -> Texture2D:
	var t: Dictionary = Catalog.titles[job.title]
	var path := "user://covercache/hi_%d_%s.png" % [Defs.CATALOG_VERSION, job.key]
	var ov_part: String = {"front": "front", "steel": "front", "back": "back", "spine": "spine", "label": "disc", "poster": "front"}.get(job.part, job.part)
	var ov := _override(t, job.edition, ov_part)
	if ov and job.part != "spine":
		return ov
	if FileAccess.file_exists(path):
		var cimg := Image.load_from_file(path)
		if cimg:
			cimg.generate_mipmaps()
			return ImageTexture.create_from_image(cimg)
	var size := Vector2i(HIRES_H, HIRES_H)
	var s := Defs.item_size(job.kind, job.fmt)
	match job.part:
		"front", "steel", "back":
			size = Vector2i(int(HIRES_H * s.x / s.y), HIRES_H)
		"spine":
			size = Vector2i(HIRES_H, maxi(24, int(HIRES_H * s.z / s.y)))
		"poster":
			size = Vector2i(384, 544)
	var img := await _render_page([{"part": job.part, "title": t, "edition": job.edition, "disc": job.disc,
		"rect": Rect2(Vector2.ZERO, Vector2(size)), "override": ov if job.part == "spine" else null, "override_rotate": true}], size)
	img.save_png(path)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Pre-generate front covers for a list of titles (used on first launch / menus).
func warm_titles(title_ids: Array) -> void:
	for t in title_ids:
		get_hires(t, Defs.E_STANDARD, "front", 0, Defs.PLATFORMS[Catalog.titles[t].platform].format, Defs.K_CASE, func(_x): pass)

# ======================================================================== per-item helpers
func item_custom(st: LevelState, it: LevelState.Item) -> Color:
	var cell := float(cover_index.get(it.product, 0))
	var label := float(label_index.get(it.uid, 0))
	var flags := 0
	if it.product >= 0 and st.products[it.product].edition == Defs.E_STEEL and it.kind == Defs.K_CASE:
		flags |= 1
	if it.flags & 2:
		flags |= 2
	return Color(cell, label, float(flags), 0.0)

func item_plastic(st: LevelState, it: LevelState.Item) -> Color:
	if it.product < 0:
		return Color(0.8, 0.8, 0.8)
	var p: Dictionary = st.products[it.product]
	var t: Dictionary = Catalog.titles[p.title]
	var plat: Dictionary = Defs.PLATFORMS[t.platform]
	match it.kind:
		Defs.K_CASE:
			if p.edition == Defs.E_STEEL:
				return Color(0.62, 0.64, 0.7)
			if p.edition == Defs.E_CE:
				return Color(0.12, 0.12, 0.14)
			if it.fmt == Defs.F_JEWEL:
				return Color(0.75, 0.8, 0.85)
			if it.fmt == Defs.F_BIGBOX or it.fmt == Defs.F_LONGBOX:
				return CoverPalette.accent_of(t).lerp(plat.case, 0.4)
			return plat.case
		Defs.K_CEBOX:
			return CoverPalette.accent_of(t).darkened(0.3)
		Defs.K_FIGURE:
			return CoverPalette.accent_of(t)
		_:
			return CoverPalette.accent_of(t).lightened(0.3)

static func mode_for(kind: int) -> int:
	match kind:
		Defs.K_DISC: return 1
		Defs.K_FIGURE: return 3
		Defs.K_CASE, Defs.K_CEBOX: return 0
	return 2
