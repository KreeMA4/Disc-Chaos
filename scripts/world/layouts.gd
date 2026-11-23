class_name Layouts
extends RefCounted
## Hand-designed level layouts with seeded decorative variation.

const IMPLEMENTED := ["bedroom"]

static func build(def: Dictionary, seed: int) -> LevelLayout:
	var L := LevelLayout.new()
	L.name = def.layout
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 99
	match def.layout:
		"bedroom": _bedroom(L, rng)
		"living": _living(L, rng)
		"basement": _basement(L, rng)
		"attic": _attic(L, rng)
		"store": _store(L, rng)
		"warehouse": _warehouse(L, rng, def)
		_: _bedroom(L, rng)
	return L

# ------------------------------------------------------------------ helpers
static func poster(L: LevelLayout, pos: Vector3, yaw: float, w := 0.6, h := 0.85, rng: RandomNumberGenerator = null) -> void:
	L.props.append({"type": "poster", "pos": pos, "yaw": deg_to_rad(yaw), "params": {"w": w, "h": h, "seed": rng.randi() if rng else 0},
		"size": Vector3(w, h, 0.01), "obstacle": -1})

static func label(L: LevelLayout, pos: Vector3, yaw: float, text: String, size := 64, color := Color.WHITE) -> void:
	L.props.append({"type": "label", "pos": pos, "yaw": deg_to_rad(yaw), "params": {"text": text, "size": size, "color": color},
		"size": Vector3(0.1, 0.1, 0.1), "obstacle": -1})

static func clutter(L: LevelLayout, rng: RandomNumberGenerator, n: int, types := ["snack", "soda", "pizza_box", "cable", "laundry", "controller", "books", "headphones", "cushion", "soda", "snack"]) -> void:
	for i in n:
		var p := L.random_floor_point(rng, 0.3)
		if p == Vector3.INF:
			continue
		var t: String = types[rng.randi() % types.size()]
		var params := {}
		if t == "pizza_box":
			params = {"stack": 1 + rng.randi() % 3}
		elif t == "soda":
			params = {"tipped": rng.randf() < 0.5}
		L.add_prop(t, p, rng.randf() * 360.0, params)

static func surface_clutter(L: LevelLayout, rng: RandomNumberGenerator, n: int) -> void:
	if L.surfaces.is_empty():
		return
	for i in n:
		var s: Dictionary = L.surfaces[rng.randi() % L.surfaces.size()]
		var r: Rect2 = s.rect
		if r.size.x < 0.3:
			continue
		var p := Vector3(rng.randf_range(r.position.x + 0.08, r.end.x - 0.08), s.y, rng.randf_range(r.position.y + 0.08, r.end.y - 0.08))
		var t: String = ["soda", "snack", "controller", "plant_small", "headphones", "trophy", "soda"][rng.randi() % 7]
		L.add_prop(t, p, rng.randf() * 360.0)

static func ceiling_lamp(L: LevelLayout, x: float, z: float, h: float, energy := 1.1, rng_ := 6.0, col := Color(1.0, 0.82, 0.6)) -> void:
	L.add_prop("ceiling_lamp", Vector3(x, h - 0.35, z), 0)
	L.add_light(Vector3(x, h - 0.55, z), col, energy, rng_)

# ------------------------------------------------------------------ 1. bedroom
static func _bedroom(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	var W := 6.6
	var D := 5.4
	var H := 2.65
	var r := L.add_room("Bedroom", Rect2(0, 0, W, D), H, "wood", Color(0.62, 0.80, 0.86), Color(0.98, 0.96, 0.93))
	L.rooms[r].wall_style = "stripes"
	L.add_window(Vector2(3.0, 0.0), 1.3, 1.1, 0.95)
	L.add_window(Vector2(W, 3.5), 1.1, 1.0, 1.0)
	# furniture
	L.add_prop("bed", Vector3(1.25, 0, 1.15), 0, {"color": Color(0.45, 0.55, 0.95), "color2": Color(1.0, 0.75, 0.4)})
	L.add_stash("nightstand", Vector3(2.2, 0, 0.3), 0)
	L.add_prop("lamp_desk", Vector3(2.2, 0.55, 0.25), 0, {"color": Color(1, 0.5, 0.4)})
	L.add_light(Vector3(2.2, 1.0, 0.45), Color(1.0, 0.78, 0.5), 0.6, 3.0)
	L.add_stash("dresser", Vector3(4.5, 0, 0.28), 0)
	L.add_prop("wardrobe", Vector3(5.85, 0, 0.32), 0, {"color": Color(0.98, 0.95, 0.9)})
	L.add_prop("desk", Vector3(6.22, 0, 1.75), -90)
	L.add_prop("monitor", Vector3(6.35, 0.765, 1.75), -90)
	L.add_prop("pc_tower", Vector3(6.3, 0.77, 2.3), -90)
	L.add_prop("lamp_desk", Vector3(6.35, 0.765, 1.15), -90, {"color": Color(0.3, 0.8, 0.9)})
	L.add_prop("gaming_chair", Vector3(5.6, 0, 1.75), 90, {"color": Color(0.9, 0.35, 0.4)})
	L.add_prop("tv_stand", Vector3(3.3, 0, 5.15), 180)
	L.add_prop("tv", Vector3(3.3, 0.5, 5.2), 180)
	L.add_prop("console", Vector3(2.85, 0.5, 5.1), 180, {"color": Color(0.95, 0.95, 0.97)})
	L.add_stash("beanbag", Vector3(2.7, 0, 3.9), 20, {"color": Color(1.0, 0.55, 0.3)})
	L.add_stash("beanbag", Vector3(4.0, 0, 4.0), -25, {"color": Color(0.45, 0.8, 0.55)})
	L.add_prop("rug_round", Vector3(3.3, 0, 3.2), 0, {"r": 1.35, "color": Color(0.95, 0.6, 0.65), "color2": Color(1.0, 0.85, 0.55)})
	L.add_prop("rug", Vector3(1.3, 0, 2.6), 0, {"w": 1.6, "d": 1.0, "color": Color(0.5, 0.75, 0.6)})
	L.add_prop("plant_big", Vector3(0.38, 0, 5.0), 0)
	L.add_prop("lamp_floor", Vector3(6.25, 0, 4.95), 0)
	L.add_light(Vector3(6.25, 1.5, 4.85), Color(1.0, 0.75, 0.45), 0.8, 3.5)
	L.add_prop("guitar", Vector3(5.2, 0, 5.2), 180)
	L.add_prop("skateboard", Vector3(5.3, 0, 3.0), 30, {"color": Color(0.3, 0.6, 1.0)})
	L.add_prop("speaker", Vector3(2.3, 0.5, 5.1), 180)
	L.add_prop("speaker", Vector3(4.3, 0.5, 5.1), 180)
	L.add_prop("ball", Vector3(1.0, 0, 4.4), 0, {"color": Color(1.0, 0.55, 0.2)})
	L.add_prop("mirror_frame", Vector3(0.08, 0, 4.0), 90, {"color": Color(1.0, 0.8, 0.4)})
	L.mirror = {"pos": Vector3(0.12, 0.95, 4.0), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	L.add_prop("door", Vector3(5.2, 0, D - 0.04), 180)
	# shelves: two units on the west wall + spare on the north wall
	L.add_shelf_slot(Vector3(0.16, 0, 2.05), 90, "case_shelf")
	L.add_shelf_slot(Vector3(0.16, 0, 3.3), 90, "case_shelf")
	L.add_shelf_slot(Vector3(3.55, 0, 0.16), 0, "case_shelf")
	for s in L.shelf_slots:
		var ext := LevelLayout._rotated_extent(Vector3(1.2, 1.8, 0.3), s.yaw)
		L.obstacles.append(AABB(Vector3(s.pos.x - ext.x * 0.5, 0, s.pos.z - ext.z * 0.5), Vector3(ext.x, 1.8, ext.z)))
	L.add_sort_table(Vector3(3.3, 0, 2.2), 0)
	# wall decor
	L.add_prop("string_lights", Vector3(1.25, 2.25, 0.05), 0, {"len": 2.4})
	L.add_prop("string_lights", Vector3(W - 0.05, 2.3, 3.0), -90, {"len": 3.6})
	L.add_prop("figure_shelf", Vector3(1.2, 1.6, 0.11), 0)
	L.add_prop("figure_shelf", Vector3(6.49, 1.45, 4.3), -90)
	poster(L, Vector3(4.6, 1.75, 0.02), 0, 0.6, 0.85, rng)
	poster(L, Vector3(6.58, 1.6, 0.9), -90, 0.5, 0.7, rng)
	poster(L, Vector3(2.0, 1.75, D - 0.02), 180, 0.55, 0.8, rng)
	poster(L, Vector3(0.02, 1.85, 0.9), 90, 0.5, 0.7, rng)
	L.add_prop("radiator", Vector3(3.0, 0, 0.1), 0)
	ceiling_lamp(L, 3.3, 2.7, H, 1.3, 7.0)
	L.add_prop("cable", Vector3(5.6, 0, 2.6), 10)
	L.add_prop("cable", Vector3(3.0, 0, 4.8), 90, {"color": Color(0.9, 0.9, 0.9)})
	L.add_prop("laundry", Vector3(5.6, 0, 0.95), 0)
	L.add_prop("pizza_box", Vector3(1.9, 0.0, 3.5), 15, {"stack": 2})
	L.spawns = [Vector3(4.7, 0, 2.9), Vector3(5.2, 0, 3.5), Vector3(5.0, 0, 2.5), Vector3(5.6, 0, 3.8)]
	clutter(L, rng, 16)
	surface_clutter(L, rng, 6)
	L.env.sun_energy = 0.85

# ------------------------------------------------------------------ stubs for later phases
static func _living(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	_bedroom(L, rng)

static func _basement(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	_bedroom(L, rng)

static func _attic(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	_bedroom(L, rng)

static func _store(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	_bedroom(L, rng)

static func _warehouse(L: LevelLayout, rng: RandomNumberGenerator, def: Dictionary) -> void:
	_bedroom(L, rng)
