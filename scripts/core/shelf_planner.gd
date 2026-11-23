class_name ShelfPlanner
extends RefCounted
## Turns products + candidate shelf unit slots into platform sections and A–Z buckets.
## Each product gets exactly one target bucket. Buckets fill shelf rows; leftover row width is
## spread across the row's buckets as slack.

const UNITS := {
	"case_shelf": {"width": 1.2, "rows": 5, "row_h": 0.31, "depth": 0.27, "base": 0.10, "height": 1.78, "board": 0.025},
	"tall_shelf": {"width": 1.2, "rows": 4, "row_h": 0.47, "depth": 0.33, "base": 0.10, "height": 2.06, "board": 0.025},
	"cabinet": {"width": 1.2, "rows": 4, "row_h": 0.38, "depth": 0.36, "base": 0.14, "height": 1.85, "board": 0.02},
}
const POST := 0.045
const SLACK := 1.32

static func unit_type_for_format(fmt: int) -> String:
	match fmt:
		Defs.F_LONGBOX, Defs.F_BIGBOX: return "tall_shelf"
		Defs.F_CEBOX: return "cabinet"
	return "case_shelf"

static func row_width(type: String) -> float:
	return float(UNITS[type].width) - POST * 2.0

## Local transform (in unit space) of the front-left corner of a row's top surface.
static func row_origin(type: String, row: int) -> Transform3D:
	var u: Dictionary = UNITS[type]
	var y := float(u.base) + row * float(u.row_h) + float(u.board) * 0.5
	return Transform3D(Basis(), Vector3(-row_width(type) * 0.5, y, float(u.depth) * 0.5))

static func unit_xf(slot: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, slot.yaw), slot.pos)

## Returns true on success. Fills state.sections / state.buckets and product.bucket.
static func plan(state: LevelState, layout: LevelLayout, bucket_target: int, one_section_per_unit := true) -> bool:
	state.sections.clear()
	state.buckets.clear()
	for s in layout.shelf_slots:
		s.used = false
		s.sections = []
	# group products into sections
	var groups := {} # key -> {label, platform, kind, fmt, products: []}
	var order: Array = []
	for p in state.products:
		var t: Dictionary = Catalog.titles[p.title]
		var key: String
		var fmt: int = Defs.PLATFORMS[t.platform].format
		if p.edition == Defs.E_CE:
			key = "CE"
			fmt = Defs.F_CEBOX
		else:
			key = "P%d" % t.platform
		if not groups.has(key):
			groups[key] = {"label": "Collector's Editions" if key == "CE" else Defs.PLATFORMS[t.platform].name,
				"platform": -1 if key == "CE" else t.platform, "fmt": fmt, "products": []}
			order.append(key)
		groups[key].products.append(p)
	order.sort_custom(func(a, b):
		if a == "CE": return false
		if b == "CE": return true
		return int(a.substr(1)) < int(b.substr(1)))
	# cursor per unit type
	var cursors := {} # type -> {slot_i, row, x}
	for key in order:
		var g: Dictionary = groups[key]
		var type := unit_type_for_format(g.fmt)
		var sec := {"id": state.sections.size(), "label": g.label, "platform": g.platform, "kind": type,
			"buckets": [], "color": Color(0.9, 0.75, 0.4) if key == "CE" else Defs.PLATFORMS[g.platform].banner}
		state.sections.append(sec)
		var prods: Array = g.products
		prods.sort_custom(func(a, b): return a.sort < b.sort)
		var bucket_lists: Array
		if key == "CE":
			bucket_lists = _ce_buckets(prods, bucket_target, type)
		else:
			bucket_lists = _letter_buckets(prods, bucket_target, type, state)
		if not cursors.has(type):
			cursors[type] = {"slot": _next_slot(layout, type, -1), "row": UNITS[type].rows - 1, "x": 0.0, "row_buckets": []}
		var cur: Dictionary = cursors[type]
		# Start each section on a fresh row (and fresh unit if requested and possible)
		if cur.x > 0.0:
			_finish_row(state, layout, cur, type)
			_advance_row(layout, cur, type)
		if one_section_per_unit and cur.row != UNITS[type].rows - 1:
			var nxt := _next_slot(layout, type, cur.slot)
			if nxt >= 0:
				cur.slot = nxt
				cur.row = UNITS[type].rows - 1
				cur.x = 0.0
		for bl in bucket_lists:
			var need: float = bl.width
			if cur.slot < 0:
				push_error("ShelfPlanner: out of %s units in layout %s" % [type, layout.name])
				return false
			if cur.x + need > row_width(type) + 0.0001:
				_finish_row(state, layout, cur, type)
				_advance_row(layout, cur, type)
				if cur.slot < 0:
					push_error("ShelfPlanner: out of %s units in layout %s" % [type, layout.name])
					return false
			var slot: Dictionary = layout.shelf_slots[cur.slot]
			slot.used = true
			if not (slot.sections as Array).has(sec.id):
				slot.sections.append(sec.id)
			var b := {"id": state.buckets.size(), "section": sec.id, "label": bl.label, "unit": cur.slot,
				"row": cur.row, "x": cur.x, "width": need, "depth": UNITS[type].depth - 0.01,
				"height": UNITS[type].row_h - UNITS[type].board - 0.01, "items": [], "xf": Transform3D()}
			state.buckets.append(b)
			sec.buckets.append(b.id)
			cur.row_buckets.append(b.id)
			cur.x += need
			for p in bl.products:
				p.bucket = b.id
		_finish_row(state, layout, cur, type)
	return true

static func _next_slot(layout: LevelLayout, type: String, after: int) -> int:
	for i in range(after + 1, layout.shelf_slots.size()):
		if layout.shelf_slots[i].type == type:
			return i
	return -1

static func _advance_row(layout: LevelLayout, cur: Dictionary, type: String) -> void:
	cur.x = 0.0
	cur.row -= 1
	if cur.row < 0:
		cur.slot = _next_slot(layout, type, cur.slot)
		cur.row = UNITS[type].rows - 1

## Spread leftover row width over the row's buckets and compute final transforms.
static func _finish_row(state: LevelState, layout: LevelLayout, cur: Dictionary, type: String) -> void:
	var ids: Array = cur.row_buckets
	if ids.is_empty():
		return
	var used := 0.0
	for id in ids:
		used += state.buckets[id].width
	var extra := maxf(0.0, row_width(type) - used) / ids.size()
	var x := 0.0
	for id in ids:
		var b: Dictionary = state.buckets[id]
		b.width += extra
		b.x = x
		var slot: Dictionary = layout.shelf_slots[b.unit]
		var origin := row_origin(type, b.row)
		origin.origin.x += x
		b.xf = unit_xf(slot) * origin
		x += b.width
	cur.row_buckets = []

static func _thick(p: Dictionary) -> float:
	var fmt: int = p.fmt
	var s: Vector3 = Defs.FORMAT_SIZE[Defs.F_CEBOX if p.edition == Defs.E_CE else fmt]
	return s.z + 0.003

static func _width_for(prods: Array) -> float:
	var w := 0.0
	for p in prods:
		w += _thick(p)
	return w * SLACK + 0.03

static func _letter_buckets(prods: Array, target: int, type: String, state: LevelState) -> Array:
	# group by letter
	var letters: Array = []
	var by_letter := {}
	for p in prods:
		var l := Defs.letter_of(Catalog.titles[p.title].name)
		if not by_letter.has(l):
			by_letter[l] = []
			letters.append(l)
		by_letter[l].append(p)
	var out: Array = []
	var cur: Array = []
	var cur_letters: Array = []
	var maxw := row_width(type)
	for l in letters:
		var lp: Array = by_letter[l]
		if lp.size() > target or _width_for(lp) > maxw:
			if not cur.is_empty():
				out.append(_mk_bucket(cur, cur_letters))
				cur = []
				cur_letters = []
			# split a big letter into chunks
			var chunk: Array = []
			for p in lp:
				chunk.append(p)
				if chunk.size() >= target or _width_for(chunk) > maxw * 0.9:
					out.append(_mk_split(chunk))
					chunk = []
			if not chunk.is_empty():
				out.append(_mk_split(chunk))
			continue
		if cur.size() + lp.size() > target or _width_for(cur + lp) > maxw:
			if not cur.is_empty():
				out.append(_mk_bucket(cur, cur_letters))
			cur = []
			cur_letters = []
		cur.append_array(lp)
		cur_letters.append(l)
	if not cur.is_empty():
		out.append(_mk_bucket(cur, cur_letters))
	return out

static func _mk_bucket(prods: Array, letters: Array) -> Dictionary:
	var label: String = letters[0] if letters.size() == 1 else "%s–%s" % [letters[0], letters[letters.size() - 1]]
	return {"label": label, "products": prods.duplicate(), "width": _width_for(prods)}

static func _mk_split(prods: Array) -> Dictionary:
	var a := Defs.sort_name(Catalog.titles[prods[0].title].name).replace(" ", "")
	var b := Defs.sort_name(Catalog.titles[prods[prods.size() - 1].title].name).replace(" ", "")
	var la := a.substr(0, 2).capitalize() if a.length() > 1 else a
	var lb := b.substr(0, 2).capitalize() if b.length() > 1 else b
	return {"label": "%s–%s" % [la, lb] if la != lb else la, "products": prods.duplicate(), "width": _width_for(prods)}

static func _ce_buckets(prods: Array, target: int, type: String) -> Array:
	var by_plat := {}
	var plats: Array = []
	for p in prods:
		var pl: int = Catalog.titles[p.title].platform
		if not by_plat.has(pl):
			by_plat[pl] = []
			plats.append(pl)
		by_plat[pl].append(p)
	plats.sort()
	var out: Array = []
	var maxw := row_width(type)
	for pl in plats:
		var chunk: Array = []
		for p in by_plat[pl]:
			chunk.append(p)
			if _width_for(chunk) > maxw * 0.92:
				chunk.pop_back()
				out.append({"label": Defs.PLATFORMS[pl].code, "products": chunk.duplicate(), "width": _width_for(chunk)})
				chunk = [p]
		if not chunk.is_empty():
			out.append({"label": Defs.PLATFORMS[pl].code, "products": chunk.duplicate(), "width": _width_for(chunk)})
	return out
