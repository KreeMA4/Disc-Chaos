class_name Levels
## Level definitions. "target_items" drives product selection; the bot test checks the result
## lands near the design counts and estimates playtime.

const LIST := [
	{"id": 1, "name": "Teen's Bedroom", "layout": "bedroom", "platforms": [Defs.P_OX5, Defs.P_PIP],
		"target_items": 150, "steel": false, "ce": false, "gh": true, "multi": false, "bucket": 7,
		"tip": "Tap a disc to grab it, then grab its matching case to slot it in!", "music": 0,
		"desc": "A teenager's room after a very long weekend. Tutorial."},
	{"id": 2, "name": "Living Room & Game Den", "layout": "living", "platforms": [Defs.P_OX5, Defs.P_KST, Defs.P_OX4],
		"target_items": 300, "steel": true, "ce": false, "gh": true, "multi": false, "bucket": 8,
		"tip": "Steelbooks are shiny metal cases. They still go A–Z with the rest!", "music": 1,
		"desc": "Family movie night turned into a disc avalanche. Introduces steelbooks."},
	{"id": 3, "name": "Basement Collector's Room", "layout": "basement", "platforms": [Defs.P_OX4, Defs.P_OX5, Defs.P_KST, Defs.P_BLP],
		"target_items": 500, "steel": true, "ce": true, "gh": true, "multi": true, "bucket": 9,
		"tip": "Collector's Editions need the case, artbook, figurine AND poster back in the box.", "music": 2,
		"desc": "Glass cabinets, collector's boxes and multi-disc epics."},
	{"id": 4, "name": "Retro Attic", "layout": "attic", "platforms": [Defs.P_S16, Defs.P_P32, Defs.P_RIG, Defs.P_BLP],
		"target_items": 600, "steel": false, "ce": true, "gh": true, "multi": true, "bucket": 9, "flashlight": true,
		"tip": "It's dim up here. Toggle your flashlight! Big-box PC games need their manuals.", "music": 3,
		"desc": "Dusty long boxes, jewel cases and big-box PC games."},
	{"id": 5, "name": "Level Up Loot", "layout": "store", "platforms": [Defs.P_OX4, Defs.P_OX5, Defs.P_KST, Defs.P_PIP, Defs.P_BLP, Defs.P_S16, Defs.P_P32, Defs.P_RIG],
		"target_items": 1560, "steel": true, "ce": true, "gh": true, "multi": true, "bucket": 10,
		"tip": "Unpack the delivery boxes in the backroom. Carts carry 30 items at once!", "music": 4,
		"desc": "A whole game store, the morning after the midnight launch."},
]
const WAREHOUSE := {"id": 6, "name": "Warehouse (Endless)", "layout": "warehouse", "platforms": [0, 1, 2, 3, 4, 5, 6, 7],
	"target_items": 400, "steel": true, "ce": true, "gh": true, "multi": true, "bucket": 9,
	"tip": "Endless mode: a random mess every time.", "music": 5, "desc": "Random mess, your rules."}

static func get_def(id: int, warehouse_items := 400, warehouse_seed := 0) -> Dictionary:
	if id == 6:
		var d := WAREHOUSE.duplicate(true)
		d.target_items = warehouse_items
		var rng := RandomNumberGenerator.new()
		rng.seed = warehouse_seed
		var plats := [0, 1, 2, 3, 4, 5, 6, 7]
		var n := clampi(2 + warehouse_items / 250, 2, 8)
		var chosen: Array = []
		while chosen.size() < n:
			var p: int = plats[rng.randi() % plats.size()]
			if not chosen.has(p):
				chosen.append(p)
		chosen.sort()
		d.platforms = chosen
		return d
	for d in LIST:
		if d.id == id:
			return d
	return LIST[0]

static func count() -> int:
	return LIST.size()

## Par time (seconds) for 3 stars given player count, from the bot estimate per item.
static func par_seconds(def: Dictionary, players: int) -> float:
	var per_item := 9.5
	return def.target_items * per_item / (1.0 + 0.85 * (players - 1))
