extends Node
## Local player profile: nickname, bean customization, stars, unlocks, best times.

signal changed

const PATH := "user://profile.cfg"

const BODY_COLORS := [Color(0.31, 0.82, 0.75), Color(1.0, 0.45, 0.45), Color(0.45, 0.62, 1.0), Color(1.0, 0.8, 0.3),
	Color(0.7, 0.5, 0.95), Color(0.55, 0.85, 0.4), Color(1.0, 0.6, 0.8), Color(1.0, 0.62, 0.3), Color(0.95, 0.95, 0.92),
	Color(0.35, 0.35, 0.42), Color(0.6, 0.4, 0.3), Color(0.5, 0.9, 0.95), Color(0.85, 0.3, 0.55), Color(0.75, 0.8, 0.3),
	Color(0.4, 0.45, 0.7), Color(1.0, 0.9, 0.7)]

## Each category: array of {id, name, stars (required)}.
const COSMETICS := {
	"pattern": ["None", "Spots", "Stripes", "Stars", "Hearts", "Checker", "Zigzag", "Polka", "Camo", "Gradient", "Galaxy", "Freckles"],
	"eyes": ["Happy", "Round", "Sleepy", "Grumpy", "Surprised", "Wink", "Sparkle", "Dizzy", "Hearts", "Determined", "Shy", "Cyclops"],
	"hat": ["None", "Cap", "Beanie", "Crown", "Headphones", "Propeller", "Traffic Cone", "Chef Hat", "Top Hat", "Cowboy", "Horns", "Bunny Ears", "Party Hat", "Halo", "Flower Crown", "Disc Hat"],
	"glasses": ["None", "Round", "Square", "Stars", "Hearts", "3D Specs", "Monocle", "Goggles", "Aviators", "Nerd", "Shades"],
	"shirt": ["None", "Disc Tee", "Heart Tee", "Star Tee", "Bolt Tee", "Smiley Tee", "Stripy Tee", "Pad Tee", "Pizza Tee", "Cat Tee", "Rainbow Tee", "Overalls"],
	"backpack": ["None", "School Bag", "Jetpack", "Turtle Shell", "Teddy", "Guitar Case", "Rocket", "Cardboard Box", "Wings", "Balloon", "Disc Stack"],
	"gloves": ["Sunny", "Red", "Blue", "Green", "Purple", "Black", "White", "Rainbow", "Striped", "Polka", "Gold"],
	"scarf": ["None", "Red Scarf", "Striped Scarf", "Knitted", "Bandana", "Bowtie", "Necklace", "Flower Lei", "Tie", "Medal", "Bell"],
	"cape": ["None", "Hero Red", "Royal Purple", "Starry", "Cloud", "Bat", "Rainbow", "Leaf", "Golden", "Ghost Sheet", "Checkered"],
}
## Bonus cosmetics: category -> {index: stars needed}
const UNLOCKS := {
	"hat": {3: 3, 13: 12, 15: 15},
	"glasses": {5: 4, 10: 8},
	"backpack": {2: 6, 6: 10, 8: 14},
	"cape": {3: 5, 8: 11, 9: 7},
	"gloves": {7: 9, 10: 13},
	"pattern": {10: 6},
	"eyes": {6: 2, 8: 9},
}
const CATEGORIES := ["pattern", "eyes", "hat", "glasses", "shirt", "backpack", "gloves", "scarf", "cape"]

const NAME_A := ["Wobbly", "Turbo", "Sir", "Captain", "Tiny", "Mega", "Fuzzy", "Sneaky", "Dizzy", "Lucky", "Sleepy", "Speedy"]
const NAME_B := ["Bean", "Noodle", "Muffin", "Pickle", "Sprout", "Waffle", "Biscuit", "Pebble", "Taco", "Gumdrop", "Disc", "Button"]

var nickname := ""
var look := {}
var stars := {}         # level id -> best stars
var best_time := {}     # level id -> seconds
var completed := {}     # level id -> true
var custom_color := Color(0.31, 0.82, 0.75)

func _ready() -> void:
	load_profile()

func default_look() -> Dictionary:
	return {"color": BODY_COLORS[0], "pattern": 0, "eyes": 0, "hat": 1, "glasses": 0, "shirt": 1, "backpack": 0,
		"gloves": 0, "scarf": 1, "cape": 0}

func load_profile() -> void:
	look = default_look()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		nickname = cf.get_value("p", "nickname", "")
		var l = cf.get_value("p", "look", {})
		if typeof(l) == TYPE_DICTIONARY:
			for k in l:
				look[k] = l[k]
		stars = cf.get_value("p", "stars", {})
		best_time = cf.get_value("p", "best_time", {})
		completed = cf.get_value("p", "completed", {})
	if nickname == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		nickname = "%s %s" % [NAME_A[rng.randi() % NAME_A.size()], NAME_B[rng.randi() % NAME_B.size()]]
		save_profile()

func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "nickname", nickname)
	cf.set_value("p", "look", look)
	cf.set_value("p", "stars", stars)
	cf.set_value("p", "best_time", best_time)
	cf.set_value("p", "completed", completed)
	cf.save(PATH)
	changed.emit()

func total_stars() -> int:
	var n := 0
	for k in stars:
		n += int(stars[k])
	return n

func is_unlocked(cat: String, idx: int) -> bool:
	var need: int = UNLOCKS.get(cat, {}).get(idx, 0)
	return total_stars() >= need

func stars_needed(cat: String, idx: int) -> int:
	return UNLOCKS.get(cat, {}).get(idx, 0)

func level_unlocked(id: int) -> bool:
	if id <= 1:
		return true
	if id == 6:
		return completed.has(1) or completed.has("1")
	return completed.has(id - 1) or completed.has(str(id - 1))

func record_result(level_id: int, star_count: int, seconds: float) -> void:
	stars[level_id] = maxi(int(stars.get(level_id, 0)), star_count)
	if not best_time.has(level_id) or seconds < float(best_time[level_id]):
		best_time[level_id] = seconds
	completed[level_id] = true
	save_profile()

func randomize_look(cat := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cats: Array = CATEGORIES if cat == "" else [cat]
	for c in cats:
		if c == "color":
			continue
		var opts: Array = COSMETICS[c]
		for attempt in 20:
			var i := rng.randi() % opts.size()
			if is_unlocked(c, i):
				look[c] = i
				break
	if cat == "" or cat == "color":
		look["color"] = BODY_COLORS[rng.randi() % BODY_COLORS.size()] if rng.randf() < 0.8 else Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.8), rng.randf_range(0.7, 1.0))
	save_profile()

func set_look(cat: String, v) -> void:
	look[cat] = v
	save_profile()

## Compact form sent over the network.
func net_look() -> Dictionary:
	var d := look.duplicate()
	d["name"] = nickname
	return d
