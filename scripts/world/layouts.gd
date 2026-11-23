class_name Layouts
extends RefCounted
## Hand-designed level layouts with seeded decorative variation.

const IMPLEMENTED := ["bedroom", "living", "basement", "attic", "store", "warehouse"]

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
		var near_spawn := false
		for sp in L.spawns:
			if Vector2(p.x - sp.x, p.z - sp.z).length() < 1.3:
				near_spawn = true
		if near_spawn:
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
	L.add_stash("tv_stand", Vector3(3.3, 0, 5.15), 180)
	L.add_prop("tv", Vector3(3.3, 0.5, 5.2), 180)
	L.add_prop("console", Vector3(2.85, 0.5, 5.1), 180, {"color": Color(0.95, 0.95, 0.97)})
	L.add_stash("beanbag", Vector3(2.45, 0, 3.9), 20, {"color": Color(1.0, 0.55, 0.3)})
	L.add_stash("beanbag", Vector3(4.45, 0, 4.1), -25, {"color": Color(0.45, 0.8, 0.55)})
	L.add_prop("rug_round", Vector3(3.3, 0, 3.2), 0, {"r": 1.35, "color": Color(0.95, 0.6, 0.65), "color2": Color(1.0, 0.85, 0.55)})
	L.add_prop("rug", Vector3(1.3, 0, 2.6), 0, {"w": 1.6, "d": 1.0, "color": Color(0.5, 0.75, 0.6)})
	L.add_prop("plant_big", Vector3(1.05, 0, 5.05), 0)
	L.add_prop("lamp_floor", Vector3(6.25, 0, 4.95), 0)
	L.add_light(Vector3(6.25, 1.5, 4.85), Color(1.0, 0.75, 0.45), 0.8, 3.5)
	L.add_prop("guitar", Vector3(5.2, 0, 5.2), 180)
	L.add_prop("skateboard", Vector3(5.3, 0, 3.0), 30, {"color": Color(0.3, 0.6, 1.0)})
	L.add_prop("speaker", Vector3(2.3, 0.5, 5.1), 180)
	L.add_prop("speaker", Vector3(4.3, 0.5, 5.1), 180)
	L.add_prop("ball", Vector3(1.0, 0, 4.4), 0, {"color": Color(1.0, 0.55, 0.2)})
	L.add_prop("mirror_frame", Vector3(0.08, 0, 4.5), 90, {"color": Color(1.0, 0.8, 0.4)})
	L.mirror = {"pos": Vector3(0.12, 0.95, 4.5), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	L.add_prop("door", Vector3(5.2, 0, D - 0.04), 180)
	# shelves: two units on the west wall + spare on the north wall
	L.add_shelf_slot(Vector3(0.16, 0, 2.05), 90, "case_shelf")
	L.add_shelf_slot(Vector3(0.16, 0, 3.3), 90, "case_shelf")
	L.add_shelf_slot(Vector3(3.55, 0, 0.16), 0, "case_shelf")
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
	L.spawns = [Vector3(4.7, 0, 2.9), Vector3(5.6, 0, 3.0), Vector3(5.0, 0, 2.4), Vector3(5.8, 0, 3.8)]
	clutter(L, rng, 16)
	surface_clutter(L, rng, 6)
	L.env.sun_energy = 0.85

# ------------------------------------------------------------------ 2. living room & game den
static func _living(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	var H := 2.75
	var liv := Rect2(0, 0, 8.0, 6.6)
	var den := Rect2(8.0, 0, 5.6, 6.6)
	var a := L.add_room("Living Room", liv, H, "wood", Color(0.96, 0.84, 0.66), Color(0.99, 0.97, 0.93))
	L.rooms[a].wall_style = "plain"
	var b := L.add_room("Game Den", den, H, "carpet", Color(0.45, 0.42, 0.7), Color(0.9, 0.88, 0.95))
	L.rooms[b].carpet = Color(0.35, 0.38, 0.6)
	L.rooms[b].wall_style = "stripes"
	L.add_door(Vector2(8.0, 3.3), 1.3)
	L.add_window(Vector2(2.2, 0.0), 1.4, 1.2, 0.9)
	L.add_window(Vector2(6.0, 6.6), 1.4, 1.2, 0.9)
	L.add_window(Vector2(13.6, 4.8), 1.0, 0.9, 1.1)
	# living room
	L.add_stash("tv_stand", Vector3(4.0, 0, 0.3), 0, {"color": Color(0.55, 0.38, 0.28)})
	L.add_prop("tv", Vector3(4.0, 0.5, 0.25), 0)
	L.add_prop("console", Vector3(3.4, 0.5, 0.35), 0, {"color": Color(0.95, 0.95, 0.97)})
	L.add_prop("console", Vector3(4.65, 0.5, 0.35), 0, {"color": Color(0.35, 0.2, 0.5)})
	L.add_prop("speaker_big", Vector3(2.65, 0, 0.32), 0)
	L.add_prop("speaker_big", Vector3(5.35, 0, 0.32), 0)
	L.add_prop("sofa", Vector3(4.0, 0, 5.85), 180, {"color": Color(0.85, 0.45, 0.4)})
	L.add_prop("coffee_table", Vector3(4.0, 0, 4.4), 0)
	L.add_prop("rug", Vector3(4.0, 0, 4.3), 0, {"w": 4.0, "d": 2.8, "color": Color(0.95, 0.8, 0.5), "color2": Color(0.5, 0.75, 0.7)})
	L.add_prop("armchair", Vector3(1.55, 0, 4.4), 90, {"color": Color(0.4, 0.65, 0.55)})
	L.add_stash("beanbag", Vector3(6.6, 0, 4.3), -30, {"color": Color(0.95, 0.75, 0.3)})
	L.add_stash("dresser", Vector3(7.2, 0, 0.3), 0, {"color": Color(0.75, 0.55, 0.4)})
	L.add_prop("fireplace", Vector3(0.3, 0, 5.6), 90)
	L.add_light(Vector3(0.7, 0.4, 5.6), Color(1.0, 0.55, 0.25), 1.0, 3.5)
	L.add_prop("lamp_floor", Vector3(7.6, 0, 6.2), 0)
	L.add_light(Vector3(7.5, 1.5, 6.1), Color(1.0, 0.75, 0.45), 0.9, 4.0)
	L.add_prop("plant_big", Vector3(0.45, 0, 0.45), 0)
	L.add_prop("plant_big", Vector3(7.6, 0, 3.0), 0, {"pot": Color(0.4, 0.6, 0.85)})
	L.add_prop("mirror_frame", Vector3(5.6, 0, 6.55), 180, {"color": Color(0.95, 0.75, 0.35)})
	L.mirror = {"pos": Vector3(5.6, 0.95, 6.5), "yaw": PI, "size": Vector2(0.8, 1.8)}
	L.shelf_run(liv, "w", 0.6, 3, "case_shelf")
	L.shelf_run(liv, "n", 6.0, 0, "case_shelf")
	L.add_sort_table(Vector3(6.0, 0, 1.6), 0)
	L.add_stash("cardboard_box", Vector3(6.2, 0, 0.45), 10, {"size": Vector3(0.6, 0.45, 0.5), "open": true})
	L.add_prop("figure_shelf", Vector3(4.0, 1.85, 0.11), 0)
	L.add_prop("string_lights", Vector3(4.0, 2.45, 0.06), 0, {"len": 5.0})
	poster(L, Vector3(1.2, 1.7, 0.02), 0, 0.6, 0.85, rng)
	poster(L, Vector3(7.98, 1.7, 1.2), -90, 0.6, 0.85, rng)
	poster(L, Vector3(2.6, 1.75, 6.58), 180, 0.55, 0.8, rng)
	ceiling_lamp(L, 4.0, 3.2, H, 1.3, 7.5)
	L.add_prop("cushion", Vector3(3.2, 0.45, 5.8), 0, {"color": Color(1.0, 0.9, 0.5)})
	L.add_prop("pizza_box", Vector3(4.4, 0.42, 4.4), 20, {"stack": 2})
	L.add_prop("soda", Vector3(3.6, 0.42, 4.3), 0)
	L.add_prop("controller", Vector3(3.9, 0.42, 4.6), 30)
	# den
	L.add_prop("desk", Vector3(13.25, 0, 1.6), -90, {"color": Color(0.25, 0.25, 0.3)})
	L.add_prop("monitor", Vector3(13.4, 0.765, 1.19), -90)
	L.add_prop("monitor", Vector3(13.4, 0.765, 1.78), -90)
	L.add_prop("pc_tower", Vector3(13.35, 0.77, 2.19), -90)   # on the desk (spans z 0.9-2.3), not hanging off its end
	L.add_prop("gaming_chair", Vector3(12.6, 0, 1.6), 90, {"color": Color(0.3, 0.85, 0.6)})
	L.add_prop("arcade", Vector3(8.9, 0, 0.5), 0, {"color": Color(0.9, 0.3, 0.45)})
	L.add_prop("arcade", Vector3(9.8, 0, 0.5), 0, {"color": Color(0.3, 0.5, 0.95)})
	L.add_prop("tv_stand", Vector3(11.4, 0, 0.3), 0, {"color": Color(0.2, 0.2, 0.25)})
	L.add_prop("tv", Vector3(11.4, 0.5, 0.25), 0)
	L.add_prop("console", Vector3(11.0, 0.5, 0.35), 0, {"color": Color(0.2, 0.2, 0.22)})
	L.add_stash("beanbag", Vector3(10.6, 0, 2.7), 20, {"color": Color(0.5, 0.35, 0.85)})
	L.add_stash("beanbag", Vector3(11.9, 0, 3.1), -20, {"color": Color(0.95, 0.45, 0.55)})
	L.add_prop("rug_round", Vector3(11.2, 0, 2.8), 0, {"r": 1.4, "color": Color(0.25, 0.25, 0.4), "color2": Color(0.9, 0.4, 0.6)})
	L.shelf_run(den, "s", 0.4, 4, "case_shelf")
	L.add_prop("neon_sign", Vector3(10.8, 2.05, 0.06), 0, {"color": Color(0.3, 0.9, 1.0)})
	label(L, Vector3(10.8, 2.05, 0.1), 0, "GAME ON", 80, Color(0.6, 1.0, 1.0))
	L.add_prop("string_lights", Vector3(13.54, 2.4, 3.3), -90, {"len": 5.5})
	L.add_light(Vector3(10.8, 1.8, 0.6), Color(0.4, 0.8, 1.0), 0.8, 4.0)
	L.add_light(Vector3(12.8, 1.6, 1.6), Color(0.6, 0.5, 1.0), 0.7, 3.5)
	poster(L, Vector3(8.02, 1.8, 5.4), 90, 0.55, 0.8, rng)
	poster(L, Vector3(13.58, 1.7, 3.9), -90, 0.5, 0.7, rng)
	ceiling_lamp(L, 11.0, 3.6, H, 1.0, 6.0, Color(0.95, 0.85, 1.0))
	L.add_prop("cable", Vector3(12.6, 0, 2.6), 80)
	L.add_prop("headphones", Vector3(13.2, 0.77, 2.1), 30)
	L.spawns = [Vector3(5.3, 0, 3.0), Vector3(6.0, 0, 3.1), Vector3(4.6, 0, 3.0), Vector3(6.8, 0, 3.0)]
	clutter(L, rng, 26)
	surface_clutter(L, rng, 8)

# ------------------------------------------------------------------ 3. basement collector's room
static func _basement(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	var H := 2.5
	var main := Rect2(0, 0, 10.5, 8.0)
	var store := Rect2(10.5, 0, 5.0, 4.2)
	var shop := Rect2(10.5, 4.2, 5.0, 3.8)
	var a := L.add_room("Collector's Room", main, H, "carpet", Color(0.32, 0.36, 0.55), Color(0.85, 0.83, 0.8))
	L.rooms[a].carpet = Color(0.55, 0.22, 0.25)
	L.rooms[a].wall_style = "planks"
	L.rooms[a].trim = Color(0.3, 0.22, 0.18)
	var b := L.add_room("Laundry", store, H, "concrete", Color(0.75, 0.78, 0.8), Color(0.8, 0.8, 0.8))
	var c := L.add_room("Workshop", shop, H, "concrete", Color(0.65, 0.6, 0.55), Color(0.8, 0.8, 0.8))
	L.rooms[c].wall_style = "planks"
	L.add_door(Vector2(10.5, 2.0), 1.1)
	L.add_door(Vector2(10.5, 6.2), 1.1)
	L.add_door(Vector2(13.0, 4.2), 1.1)
	L.add_window(Vector2(5.0, 0.0), 1.2, 0.45, 1.85)
	L.add_window(Vector2(13.0, 0.0), 1.0, 0.45, 1.85)
	L.env.ambient = Color(0.85, 0.75, 0.8)
	L.env.ambient_energy = 0.45
	L.env.sun_energy = 0.55
	# collector's room: glass cabinets, shelves
	L.shelf_run(main, "n", 1.4, 4, "cabinet")
	L.shelf_run(main, "w", 0.4, 0, "case_shelf")
	L.shelf_run(main, "w", 1.6, 5, "case_shelf")
	L.shelf_run(main, "s", 1.4, 3, "case_shelf")
	L.add_prop("sofa", Vector3(7.6, 0, 5.4), 0, {"color": Color(0.3, 0.32, 0.45)})
	L.add_prop("tv_stand", Vector3(7.6, 0, 7.7), 180, {"color": Color(0.2, 0.2, 0.25)})
	L.add_prop("tv", Vector3(7.6, 0.5, 7.75), 180)
	L.add_prop("console", Vector3(7.1, 0.5, 7.65), 180, {"color": Color(0.2, 0.22, 0.25)})
	L.add_prop("coffee_table", Vector3(7.6, 0, 6.55), 0)
	L.add_prop("arcade", Vector3(10.05, 0, 0.6), -90, {"color": Color(0.95, 0.75, 0.2)})
	L.add_prop("pinball", Vector3(9.7, 0, 3.6), -90, {"color": Color(0.85, 0.3, 0.7)})
	L.add_stash("beanbag", Vector3(5.6, 0, 6.6), 15, {"color": Color(0.35, 0.75, 0.6)})
	L.add_stash("trunk", Vector3(9.8, 0, 7.55), 180)
	L.add_prop("rug", Vector3(5.2, 0, 3.6), 0, {"w": 3.6, "d": 2.6, "color": Color(0.85, 0.75, 0.55), "color2": Color(0.4, 0.3, 0.5)})
	L.add_sort_table(Vector3(4.6, 0, 3.4), 0)
	L.add_sort_table(Vector3(6.9, 0, 2.8), 90)
	L.add_prop("figure_shelf", Vector3(7.5, 1.6, 0.11), 0)
	L.add_prop("figure_shelf", Vector3(7.5, 1.25, 0.11), 0)
	L.add_prop("neon_sign", Vector3(9.0, 1.9, 0.06), 0, {"color": Color(1.0, 0.4, 0.8)})
	label(L, Vector3(9.0, 1.9, 0.1), 0, "HALL OF DISCS", 64, Color(1.0, 0.75, 0.95))
	L.add_prop("string_lights", Vector3(5.2, 2.25, 0.06), 0, {"len": 6.0})
	L.add_prop("trophy", Vector3(7.2, 1.62, 0.11), 0)
	poster(L, Vector3(10.48, 1.5, 5.0), -90, 0.6, 0.85, rng)
	poster(L, Vector3(4.0, 1.55, 7.98), 180, 0.55, 0.8, rng)
	ceiling_lamp(L, 3.5, 3.8, H, 1.1, 6.0)
	ceiling_lamp(L, 7.5, 4.0, H, 1.0, 6.0)
	L.add_light(Vector3(5.2, 2.0, 0.6), Color(1.0, 0.9, 0.75), 0.8, 4.5)
	L.add_light(Vector3(9.0, 1.7, 0.5), Color(1.0, 0.4, 0.8), 0.6, 3.0)
	L.add_prop("mirror_frame", Vector3(0.08, 0, 7.3), 90, {"color": Color(0.8, 0.8, 0.85)})
	L.mirror = {"pos": Vector3(0.12, 0.95, 7.3), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	# laundry / storage
	L.add_prop("washer", Vector3(15.1, 0, 0.45), -90)
	L.add_prop("washer", Vector3(15.1, 0, 1.15), -90)
	L.add_prop("boiler", Vector3(14.9, 0, 3.4), 0)
	L.add_prop("pallet", Vector3(12.2, 0, 0.7), 0)
	L.add_prop("crate_stack", Vector3(11.9, 0.15, 0.7), 10)
	L.add_stash("cardboard_box", Vector3(12.6, 0.15, 0.75), -8, {"size": Vector3(0.55, 0.45, 0.5), "open": true})
	L.add_stash("cardboard_box", Vector3(11.0, 0, 3.7), 5, {"size": Vector3(0.6, 0.5, 0.5)})
	L.add_prop("laundry", Vector3(13.8, 0, 1.0), 0)
	L.add_prop("ironing_board", Vector3(13.4, 0, 3.6), 0)
	ceiling_lamp(L, 13.0, 2.0, H, 0.9, 4.5, Color(0.9, 0.95, 1.0))
	# workshop
	L.add_prop("workbench", Vector3(13.0, 0, 7.55), 180)
	L.add_stash("delivery_box", Vector3(11.2, 0, 4.9), 0)
	L.add_prop("crate_stack", Vector3(15.05, 0, 4.7), 0)
	L.add_prop("crate_stack", Vector3(15.05, 0, 5.4), 20)
	L.add_prop("suitcase", Vector3(14.6, 0, 6.6), 30)
	L.add_prop("fan", Vector3(11.0, 0, 7.4), 0)
	ceiling_lamp(L, 13.0, 6.0, H, 0.9, 4.5, Color(1.0, 0.9, 0.7))
	L.spawns = [Vector3(5.0, 0, 5.4), Vector3(5.8, 0, 5.0), Vector3(4.2, 0, 5.0), Vector3(3.4, 0, 5.6)]
	clutter(L, rng, 38)
	surface_clutter(L, rng, 10)

# ------------------------------------------------------------------ 4. retro attic
static func _attic(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	var H := 2.9
	var main := Rect2(0, 0, 12.5, 7.4)
	var nook := Rect2(12.5, 1.2, 4.6, 5.0)
	var a := L.add_room("Attic", main, H, "attic", Color(0.7, 0.55, 0.42), Color(0.55, 0.42, 0.32))
	L.rooms[a].wall_style = "planks"
	L.rooms[a].trim = Color(0.45, 0.32, 0.24)
	var b := L.add_room("Nook", nook, H, "attic", Color(0.66, 0.52, 0.4), Color(0.55, 0.42, 0.32))
	L.rooms[b].wall_style = "planks"
	L.rooms[b].trim = Color(0.45, 0.32, 0.24)
	L.add_door(Vector2(12.5, 3.7), 1.4, 2.3)
	L.add_window(Vector2(6.2, 0.0), 1.0, 0.9, 1.3)
	L.add_window(Vector2(17.1, 3.7), 0.8, 0.8, 1.3)
	L.env.ambient = Color(0.7, 0.62, 0.55)
	L.env.ambient_energy = 0.26
	L.env.sun = Color(1.0, 0.85, 0.6)
	L.env.sun_energy = 0.35
	L.env.fog = true
	L.env.fog_color = Color(0.55, 0.45, 0.35)
	L.env.fog_density = 0.05
	L.env.dust = true
	L.env.flashlight = true
	for i in 6:
		L.add_prop("rafter", Vector3(6.25, H - 0.12, 0.6 + i * 1.25), 0, {"len": 12.5})
	L.add_prop("rafter", Vector3(14.8, H - 0.12, 3.7), 90, {"len": 5.0})
	# shelves: tall shelves for long boxes / big boxes, case shelves for jewel & mini, cabinets
	L.shelf_run(main, "n", 0.3, 4, "tall_shelf")
	L.shelf_run(main, "n", 7.2, 3, "tall_shelf")
	L.shelf_run(main, "s", 0.3, 4, "case_shelf")
	L.shelf_run(main, "w", 1.6, 2, "tall_shelf")
	L.shelf_run(nook, "e", 0.6, 3, "cabinet")
	L.shelf_run(nook, "n", 0.3, 1, "cabinet")
	# props
	L.add_stash("dust_sheet", Vector3(6.4, 0, 3.4), 10)
	L.add_stash("dust_sheet", Vector3(9.4, 0, 5.6), -15)
	L.add_stash("trunk", Vector3(11.6, 0, 6.85), 180)
	L.add_stash("trunk", Vector3(5.6, 0, 6.85), 180)
	L.add_stash("suitcase", Vector3(10.8, 0, 2.6), 25)
	L.add_prop("old_tv", Vector3(11.85, 0, 1.0), -90)
	L.add_prop("old_tv", Vector3(11.85, 0.55, 1.0), -80)
	L.add_prop("rocking_chair", Vector3(9.6, 0, 3.4), -120)
	L.add_prop("easel", Vector3(2.0, 0, 4.0), 30)
	L.add_prop("clothes_rack", Vector3(7.9, 0, 6.85), 180)
	L.add_prop("globe", Vector3(11.6, 0.6, 6.85), 0)
	L.add_prop("crate_stack", Vector3(9.0, 0, 1.2), 15)
	L.add_prop("crate_stack", Vector3(3.6, 0, 3.0), -10)
	L.add_prop("cardboard_box", Vector3(4.4, 0, 3.4), 30, {"size": Vector3(0.5, 0.4, 0.45)})
	L.add_prop("fan", Vector3(0.5, 0, 6.8), 0)
	L.add_prop("rug_round", Vector3(7.4, 0, 3.4), 0, {"r": 1.3, "color": Color(0.6, 0.4, 0.35), "color2": Color(0.75, 0.65, 0.45)})
	L.add_sort_table(Vector3(7.6, 0, 2.3), 0)
	L.add_prop("arcade", Vector3(16.6, 0, 5.7), -90, {"color": Color(0.6, 0.5, 0.35)})
	L.add_prop("old_tv", Vector3(13.2, 0, 5.7), 160)
	L.add_stash("cardboard_box", Vector3(14.2, 0, 5.75), 180, {"size": Vector3(0.6, 0.45, 0.5), "open": true})
	for i in 7:
		L.add_prop("cobweb", Vector3(rng.randf_range(0.5, 12.0), H - 0.35, 0.06 if i % 2 == 0 else 7.34), 0 if i % 2 == 0 else 180)
	L.add_prop("mirror_frame", Vector3(0.08, 0, 5.6), 90, {"color": Color(0.7, 0.55, 0.3)})
	L.mirror = {"pos": Vector3(0.12, 0.95, 5.6), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	for p in [Vector3(3.0, H - 0.3, 3.7), Vector3(7.5, H - 0.3, 3.7), Vector3(10.8, H - 0.3, 4.5), Vector3(14.8, H - 0.3, 3.7)]:
		L.add_prop("bulb", p, 0)
		L.add_light(p - Vector3(0, 0.1, 0), Color(1.0, 0.78, 0.45), 1.0, 5.0)
	L.add_light(Vector3(6.2, 1.8, 0.8), Color(0.9, 0.9, 1.0), 0.6, 4.0)
	poster(L, Vector3(12.48, 1.7, 0.7), -90, 0.5, 0.7, rng)
	L.spawns = [Vector3(6.9, 0, 4.6), Vector3(7.8, 0, 4.7), Vector3(6.2, 0, 5.0), Vector3(8.6, 0, 4.4)]
	clutter(L, rng, 30, ["snack", "soda", "books", "laundry", "cable", "cushion", "books"])
	surface_clutter(L, rng, 6)

# ------------------------------------------------------------------ 5. Level Up Loot (game store)
static func _aisle(L: LevelLayout, x: float, z0: float, units: int, type := "case_shelf") -> void:
	var u: Dictionary = ShelfPlanner.UNITS[type]
	var half: float = u.depth * 0.5 + 0.015
	for i in units:
		L.add_shelf_slot(Vector3(x - half, 0, z0 + i * (u.width + 0.02) + u.width * 0.5), -90, type)
	for i in units:
		L.add_shelf_slot(Vector3(x + half, 0, z0 + i * (u.width + 0.02) + u.width * 0.5), 90, type)

static func _store(L: LevelLayout, rng: RandomNumberGenerator) -> void:
	var back := Rect2(0, 0, 26, 6.5)
	var floor := Rect2(0, 6.5, 26, 16)
	var a := L.add_room("Backroom", back, 3.0, "concrete", Color(0.78, 0.8, 0.84), Color(0.85, 0.85, 0.87))
	L.rooms[a].wall_style = "bare"
	var b := L.add_room("Level Up Loot", floor, 3.4, "tile", Color(0.99, 0.78, 0.55), Color(0.97, 0.95, 0.92))
	L.rooms[b].tile_a = Color(0.95, 0.88, 0.74)
	L.rooms[b].tile_b = Color(0.45, 0.72, 0.76)
	L.rooms[b].wall_style = "stripes"
	L.rooms[b].trim = Color(1.0, 0.55, 0.3)
	L.add_door(Vector2(4.0, 6.5), 1.6, 2.2)
	L.add_door(Vector2(22.0, 6.5), 1.6, 2.2)
	L.add_window(Vector2(4.5, 22.5), 6.0, 2.3, 0.35)
	L.add_window(Vector2(13.0, 22.5), 2.6, 2.5, 0.05)
	L.add_window(Vector2(21.5, 22.5), 6.0, 2.3, 0.35)
	L.env.ambient = Color(1.0, 0.9, 0.82)
	L.env.ambient_energy = 0.5
	L.env.sun_energy = 0.85
	# --- shelving, by zone (order matters: the planner fills zones in this order)
	L.zone = "new"
	L.shelf_run(floor, "w", 1.0, 5, "case_shelf")
	L.zone = "aisle"
	_aisle(L, 7.0, 8.6, 3)
	_aisle(L, 11.2, 8.6, 3)
	_aisle(L, 15.4, 8.6, 3)
	L.zone = "retro"
	L.shelf_run(floor, "e", 0.9, 4, "tall_shelf")
	L.shelf_run(floor, "e", 6.0, 3, "case_shelf")
	L.zone = "preowned"
	L.shelf_run(floor, "n", 6.0, 3, "case_shelf")
	L.zone = "ce"
	L.shelf_run(floor, "n", 10.3, 6, "cabinet")
	L.zone = ""
	# --- signage
	L.add_prop("neon_sign", Vector3(0.06, 2.75, 10.6), 90, {"color": Color(1.0, 0.35, 0.45)})
	label(L, Vector3(0.1, 2.75, 10.6), 90, "NEW RELEASES", 90, Color(1.0, 0.85, 0.9))
	L.add_prop("neon_sign", Vector3(25.94, 2.75, 11.2), -90, {"color": Color(0.4, 1.0, 0.6)})
	label(L, Vector3(25.9, 2.75, 11.2), -90, "RETRO ZONE", 90, Color(0.8, 1.0, 0.85))
	L.add_prop("neon_sign", Vector3(7.9, 2.75, 6.56), 0, {"color": Color(1.0, 0.7, 0.25)})
	label(L, Vector3(7.9, 2.75, 6.6), 0, "PRE-OWNED", 90, Color(1.0, 0.92, 0.7))
	L.add_prop("neon_sign", Vector3(14.3, 2.75, 6.56), 0, {"color": Color(0.9, 0.75, 0.35)})
	label(L, Vector3(14.3, 2.75, 6.6), 0, "COLLECTOR'S VAULT", 80, Color(1.0, 0.95, 0.75))
	L.add_prop("neon_sign", Vector3(13.0, 2.95, 22.44), 180, {"color": Color(0.35, 0.8, 1.0)})
	label(L, Vector3(13.0, 2.95, 22.4), 180, "LEVEL UP LOOT", 110, Color(0.85, 0.97, 1.0))
	# --- front of store
	L.add_prop("window_display", Vector3(4.5, 0, 21.95), 180)
	L.add_prop("window_display", Vector3(21.5, 0, 21.95), 180)
	L.add_prop("checkout", Vector3(20.0, 0, 19.3), 0)
	L.add_prop("monitor", Vector3(19.3, 1.02, 19.2), 180)
	L.add_prop("kiosk", Vector3(3.0, 0, 18.6), 0, {"color": Color(0.3, 0.75, 0.95)})
	L.add_prop("kiosk", Vector3(4.6, 0, 18.6), 0, {"color": Color(1.0, 0.45, 0.6)})
	L.add_prop("kiosk", Vector3(6.2, 0, 18.6), 0, {"color": Color(0.55, 0.85, 0.35)})
	L.add_stash("bargain_bin", Vector3(10.6, 0, 18.4), 0)
	L.add_stash("bargain_bin", Vector3(15.4, 0, 18.4), 0)
	L.add_prop("display_table", Vector3(13.0, 0, 16.0), 0, {"color": Color(1.0, 0.55, 0.3)})
	L.add_prop("display_table", Vector3(20.5, 0, 15.6), 90, {"color": Color(0.55, 0.45, 0.95)})
	L.add_prop("cart_return", Vector3(9.0, 0, 22.2), 180)
	L.add_prop("plant_big", Vector3(11.0, 0, 21.9), 0)
	L.add_prop("plant_big", Vector3(15.0, 0, 21.9), 0)
	L.add_prop("arcade", Vector3(24.9, 0, 19.6), -90, {"color": Color(0.95, 0.35, 0.35)})
	L.add_prop("arcade", Vector3(24.9, 0, 20.5), -90, {"color": Color(0.35, 0.55, 0.95)})
	L.add_prop("shopping_basket", Vector3(18.6, 0, 20.6), 20)
	L.add_prop("mirror_frame", Vector3(0.08, 0, 20.2), 90, {"color": Color(1.0, 0.55, 0.3)})
	L.mirror = {"pos": Vector3(0.12, 0.95, 20.2), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	L.add_sort_table(Vector3(13.0, 0, 13.6), 0)
	L.add_sort_table(Vector3(20.6, 0, 12.0), 90)
	L.add_cart(Vector3(12.0, 0, 20.4), 0)
	L.add_cart(Vector3(14.0, 0, 20.4), 0)
	L.add_cart(Vector3(19.6, 0, 9.3), 90)
	for i in 4:
		poster(L, Vector3(1.8 + i * 1.0, 2.35, 22.46), 180, 0.55, 0.8, rng)
	poster(L, Vector3(25.96, 1.9, 18.0), -90, 0.6, 0.85, rng)
	poster(L, Vector3(0.04, 1.9, 16.5), 90, 0.6, 0.85, rng)
	poster(L, Vector3(0.04, 1.9, 17.6), 90, 0.6, 0.85, rng)
	for x in [4.0, 9.0, 13.0, 17.0, 22.0]:
		for z in [9.5, 14.0, 18.5]:
			L.add_prop("panel_light", Vector3(x, 3.36, z), 0)
	for x in [5.0, 13.0, 21.0]:
		for z in [10.0, 17.5]:
			L.add_light(Vector3(x, 3.0, z), Color(1.0, 0.95, 0.88), 1.2, 9.0)
	# --- backroom: delivery boxes to unpack
	for p in [Vector3(2.4, 0, 1.6), Vector3(5.6, 0, 4.4), Vector3(8.4, 0, 1.4), Vector3(11.0, 0, 4.0), Vector3(14.4, 0, 1.6), Vector3(17.4, 0, 4.4), Vector3(20.2, 0, 1.5), Vector3(24.0, 0, 3.6)]:
		L.add_stash("delivery_box", p, rng.randf_range(-15, 15))
	L.add_prop("pallet", Vector3(3.0, 0, 5.6), 0)
	L.add_prop("crate_stack", Vector3(2.7, 0.15, 5.6), 10)
	L.add_prop("crate_stack", Vector3(3.4, 0.15, 5.6), -5)
	L.add_prop("pallet", Vector3(12.8, 0, 0.7), 0)
	L.add_prop("crate_stack", Vector3(12.5, 0.15, 0.7), 0)
	L.add_prop("cardboard_box", Vector3(13.2, 0.15, 0.7), 8, {"size": Vector3(0.55, 0.45, 0.5)})
	L.add_prop("workbench", Vector3(18.0, 0, 0.45), 0)
	L.add_prop("pallet", Vector3(22.8, 0, 5.6), 90)
	L.add_prop("crate_stack", Vector3(22.8, 0.15, 5.4), 30)
	L.add_prop("fan", Vector3(25.5, 0, 0.5), 0)
	L.add_cart(Vector3(9.0, 0, 5.4), 90)
	for x in [4.0, 10.0, 16.0, 22.0]:
		L.add_prop("ceiling_lamp", Vector3(x, 2.65, 3.2), 0)
	L.add_light(Vector3(7.0, 2.4, 3.2), Color(1.0, 0.92, 0.8), 1.0, 8.0)
	L.add_light(Vector3(19.0, 2.4, 3.2), Color(1.0, 0.92, 0.8), 1.0, 8.0)
	L.spawns = [Vector3(13.0, 0, 20.6), Vector3(12.2, 0, 21.4), Vector3(13.8, 0, 21.4), Vector3(13.0, 0, 19.5)]
	clutter(L, rng, 60, ["snack", "soda", "pizza_box", "cable", "controller", "headphones", "shopping_basket", "soda"])
	surface_clutter(L, rng, 10)

# ------------------------------------------------------------------ 6. warehouse / endless
static func _warehouse(L: LevelLayout, rng: RandomNumberGenerator, def: Dictionary) -> void:
	var items: int = def.target_items
	var products := items / 2.2
	var n_case := int(ceil(products * 0.75 * 0.034 * 1.6 / 5.0)) + 2
	var n_tall := int(ceil(products * 0.25 * 0.07 * 1.6 / 4.0)) + 1
	var n_cab := int(ceil(products * 0.12 * 0.22 * 1.6 / 4.0)) + 1
	var per_side := 4
	var types: Array = []
	for i in n_case: types.append("case_shelf")
	for i in n_tall: types.append("tall_shelf")
	for i in n_cab: types.append("cabinet")
	var aisles := int(ceil(types.size() / float(per_side * 2)))
	var W := 6.0 + aisles * 3.4
	var D := per_side * 1.22 + 9.0
	var hall := Rect2(0, 0, W, D)
	var a := L.add_room("Warehouse", hall, 4.6, "concrete", Color(0.72, 0.76, 0.82), Color(0.7, 0.72, 0.76))
	L.rooms[a].wall_style = "bare"
	L.rooms[a].trim = Color(0.95, 0.75, 0.2)
	L.add_window(Vector2(W * 0.5, 0.0), 3.0, 1.0, 3.0)
	L.env.ambient = Color(0.92, 0.95, 1.0)
	L.env.ambient_energy = 0.55
	var ti := 0
	for ai in aisles:
		var x := 4.0 + ai * 3.4
		for side in [-1.0, 1.0]:
			for k in per_side:
				if ti >= types.size():
					break
				var t: String = types[ti]
				var u: Dictionary = ShelfPlanner.UNITS[t]
				var half: float = u.depth * 0.5 + 0.015
				L.add_shelf_slot(Vector3(x + side * half, 0, 3.5 + k * 1.22 + 0.6), 90.0 * side, t)
				ti += 1
		L.add_prop("panel_light", Vector3(x, 4.55, D * 0.5), 90)
		L.add_light(Vector3(x, 4.0, D * 0.45), Color(1.0, 0.96, 0.9), 1.3, 10.0)
	# loading area at the front
	var boxes := clampi(items / 110, 3, 14)
	for i in boxes:
		var p := Vector3(1.6 + (i % 7) * (W - 3.2) / 6.0, 0, D - 1.2 - (i / 7) * 1.5)
		L.add_stash("delivery_box", p, rng.randf_range(-20, 20))
	for i in 3:
		L.add_prop("pallet", Vector3(1.2 + i * 1.6, 0, 1.0), 0)
		L.add_prop("crate_stack", Vector3(1.2 + i * 1.6, 0.15, 1.0), rng.randf() * 30)
	L.add_sort_table(Vector3(W * 0.5 - 1.0, 0, D - 3.6), 0)
	L.add_sort_table(Vector3(W * 0.5 + 1.4, 0, D - 3.6), 0)
	L.add_cart(Vector3(W * 0.5 - 2.6, 0, D - 4.6), 0)
	L.add_cart(Vector3(W * 0.5 + 3.0, 0, D - 4.6), 0)
	L.add_cart(Vector3(W - 1.2, 0, 1.6), 90)
	L.add_prop("neon_sign", Vector3(W * 0.5, 3.6, 0.06), 0, {"color": Color(1.0, 0.75, 0.25)})
	label(L, Vector3(W * 0.5, 3.6, 0.1), 0, "WAREHOUSE", 110, Color(1.0, 0.95, 0.7))
	L.add_prop("mirror_frame", Vector3(0.08, 0, D - 2.5), 90, {"color": Color(0.95, 0.75, 0.2)})
	L.mirror = {"pos": Vector3(0.12, 0.95, D - 2.5), "yaw": deg_to_rad(90), "size": Vector2(0.8, 1.8)}
	L.spawns = [Vector3(W * 0.5, 0, D - 4.9), Vector3(W * 0.5 - 0.8, 0, D - 4.9), Vector3(W * 0.5 + 0.8, 0, D - 4.9), Vector3(W * 0.5 + 0.2, 0, D - 5.5)]
	clutter(L, rng, int(W * D / 12.0), ["pizza_box", "snack", "soda", "cable", "crate_stack"])
