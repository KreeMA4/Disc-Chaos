extends Node
## Seeded catalog generator. Produces the same 480 original titles on every device, so peers only
## need to agree on CATALOG_SEED. Every name, publisher and platform is invented.

var titles: Array = []          # Array[Dictionary]
var by_gid: Dictionary = {}     # gid -> index
var franchises: Array = []

const PER_PLATFORM := 60

# Genre vocab: [themes, whimsy, genre nouns]
const VOCAB := {
	Defs.G_SPACE: [["Pulsar", "Comet", "Nebula", "Quasar", "Orbit", "Cosmo", "Meteor", "Photon", "Stardust", "Zenith", "Lunar", "Ion"],
		["Pickle", "Noodle", "Waffle", "Goose", "Teacup", "Mitten", "Pudding", "Sprout", "Bagel", "Llama"],
		["Patrol", "Barrage", "Squadron", "Drifters", "Armada", "Rangers", "Salvo", "Voyage", "Express", "Frontier"]],
	Defs.G_KART: [["Turbo", "Nitro", "Zoom", "Skid", "Drift", "Rocket", "Hyper", "Pedal", "Rally", "Vroom"],
		["Toast", "Muffin", "Hamster", "Taco", "Penguin", "Donut", "Corgi", "Gumdrop", "Walrus", "Pretzel"],
		["Rally", "Grand Prix", "Derby", "Circuit", "Dash", "Cup", "Rush", "Raceway", "Showdown", "Speedway"]],
	Defs.G_CRIME: [["Neon", "Vice-Free", "Sunset", "Harbor", "Downtown", "Midnight", "Velvet", "Chrome", "Palm", "Boulevard"],
		["Heist", "Hustle", "Getaway", "Caper", "Grift", "Racket", "Shakedown", "Score", "Stakeout", "Jackpot"],
		["Stories", "City", "Avenue", "Blocks", "Syndicate", "Streets", "District", "Nights", "Kings", "Bay"]],
	Defs.G_MONSTER: [["Pocket", "Critter", "Fuzzy", "Pebble", "Bramble", "Puddle", "Snuggle", "Wiggle", "Twig", "Puff"],
		["Monsters", "Beasties", "Critters", "Pals", "Buddies", "Sprites", "Goblins", "Wisps", "Chums", "Blobs"],
		["Caravan", "Collector", "Safari", "League", "Expedition", "Valley", "Journey", "Ranch", "Academy", "Isles"]],
	Defs.G_FANTASY: [["Ember", "Rune", "Crystal", "Thorn", "Silver", "Ashen", "Whisper", "Oak", "Gilded", "Hollow"],
		["Crown", "Blade", "Tower", "Lantern", "Grimoire", "Wyrm", "Throne", "Chalice", "Sigil", "Harp"],
		["Chronicles", "Saga", "Legends", "Quest", "Tales", "Ballad", "Odyssey", "Covenant", "Kingdoms", "Prophecy"]],
	Defs.G_HORROR: [["Gloom", "Hollowmere", "Ravenwick", "Dread", "Murk", "Shiver", "Blackthorn", "Creep", "Ashgrove", "Fogbell"],
		["Manor", "Asylum", "Orphanage", "Lighthouse", "Motel", "Cellar", "Chapel", "Sanatorium", "Woods", "Carnival"],
		["Whispers", "Nightfall", "Remains", "Echoes", "Dread", "Shadows", "Hauntings", "Silence", "Lullaby", "Visitors"]],
	Defs.G_MASCOT: [["Bouncy", "Super-Duper", "Zippy", "Wobbly", "Jumpin'", "Sparkle", "Rolly", "Bubbly", "Hoppy", "Spiffy"],
		["Bimble", "Pogo", "Mochi", "Nubbin", "Tuffy", "Sprocket", "Biscuit", "Pipkin", "Squeak", "Flapjack"],
		["Adventure", "Island", "Land", "Galaxy", "World", "Escapade", "Jamboree", "Getaway", "Hop", "Bonanza"]],
	Defs.G_SPORTS: [["Pro", "Ultra", "All-Star", "Mega", "Extreme", "Street", "Power", "Champion", "Slam", "Golden"],
		["Hoops", "Pitch", "Puck", "Bowling", "Volley", "Dodgeball", "Tennis", "Curling", "Golf", "Skate"],
		["Season", "Tour", "League", "Cup", "Jam", "Classic", "Arena", "Showcase", "Open", "Bash"]],
	Defs.G_FIGHTING: [["Iron", "Thunder", "Brawl", "Knuckle", "Fury", "Blaze", "Crimson", "Steel", "Storm", "Savage"],
		["Fist", "Dojo", "Rumble", "Clash", "Gauntlet", "Smash", "Tusk", "Talon", "Uppercut", "Mayhem"],
		["Tournament", "Arena", "Legends", "Showdown", "Royale", "Federation", "Masters", "Revolution", "Ring", "Spirits"]],
	Defs.G_RHYTHM: [["Disco", "Groove", "Funky", "Beat", "Boogie", "Bass", "Synth", "Jazz", "Tempo", "Echo"],
		["Llama", "Goblin", "Panda", "Robot", "Hamster", "Frog", "Duck", "Octopus", "Yak", "Moose"],
		["Party", "Fever", "Jam", "Shuffle", "Stomp", "Remix", "Session", "Parade", "Mixtape", "Encore"]],
	Defs.G_MECH: [["Titan", "Bastion", "Vanguard", "Bulwark", "Cobalt", "Ironclad", "Rampart", "Atlas", "Hammer", "Aegis"],
		["Frame", "Gear", "Walker", "Chassis", "Piston", "Rotor", "Strider", "Engine", "Core"],
		["Protocol", "Assault", "Warfront", "Directive", "Uprising", "Theater", "Conflict", "Siege", "Command", "Breach"]],
	Defs.G_STEALTH: [["Silent", "Shadow", "Velvet", "Ghost", "Quiet", "Hush", "Dusk", "Nightjar", "Cipher", "Whisper"],
		["Fox", "Moth", "Cat", "Owl", "Agent", "Courier", "Thief", "Spook", "Raven", "Lynx"],
		["Protocol", "Operation", "Dossier", "Infiltration", "Mandate", "Contract", "Gambit", "Signal", "Ledger", "Exfil"]],
	Defs.G_PUZZLE: [["Tumble", "Block", "Pixel", "Puzzle", "Brain", "Tile", "Jelly", "Gem", "Cube", "Swirl"],
		["Bonbon", "Kitten", "Noggin", "Teapot", "Sprout", "Domino", "Marble", "Button", "Pebble", "Jigsaw"],
		["Mania", "Matrix", "Factory", "Lab", "Shuffle", "Cascade", "Fiesta", "Logic", "Workshop", "Garden"]],
	Defs.G_FARM: [["Sunny", "Harvest", "Meadow", "Clover", "Golden", "Honey", "Maple", "Barn", "Orchard", "Daisy"],
		["Acres", "Hollow", "Fields", "Valley", "Creek", "Pastures", "Ridge", "Hills", "Glen", "Patch"],
		["Life", "Days", "Story", "Seasons", "Moon", "Friends", "Village", "Homestead", "Market", "Diaries"]],
}
const SUBTITLE_A := ["Return of the", "Rise of the", "Curse of the", "Secret of the", "Revenge of the",
	"Dawn of the", "Legacy of the", "Song of the", "March of the", "Night of the", "Quest for the", "Fall of the"]
const SUBTITLE_B := ["Moon Waffle", "Lost Sock", "Crystal Spoon", "Iron Kettle", "Ninth Moon", "Sky Whale",
	"Velvet Fog", "Glass Duck", "Golden Noodle", "Paper Dragon", "Thunder Toad", "Last Biscuit",
	"Copper Owl", "Silent Teapot", "Neon Yak", "Hidden Mitten", "Cosmic Pancake", "Hollow Drum"]
const SEQUELS := ["2", "3", "4", "II", "III", "Zero", "Deluxe", "Turbo", "Remix", "Forever", "Plus", "64-ish"]
const SUBTITLE_PLAIN := ["Origins", "Rebooted", "Overdrive", "Unbound", "Afterglow", "Homecoming",
	"Double Trouble", "Jumbo Edition", "Encore", "Deluxe Remaster", "Tag Team", "Night Shift"]

## Genre weights per platform (higher = more likely).
const PLATFORM_GENRES := {
	Defs.P_OX4: [3, 3, 3, 2, 3, 3, 2, 3, 2, 1, 2, 3, 1, 1],
	Defs.P_OX5: [3, 2, 3, 2, 3, 3, 2, 3, 2, 2, 3, 2, 1, 2],
	Defs.P_KST: [3, 2, 3, 1, 3, 2, 2, 3, 3, 1, 3, 3, 1, 1],
	Defs.P_PIP: [1, 3, 1, 4, 2, 1, 4, 2, 2, 3, 1, 1, 3, 3],
	Defs.P_BLP: [2, 3, 1, 3, 2, 2, 4, 2, 2, 2, 1, 1, 3, 2],
	Defs.P_S16: [4, 2, 0, 1, 2, 1, 5, 3, 4, 0, 2, 1, 2, 0],
	Defs.P_P32: [3, 3, 1, 2, 4, 4, 3, 3, 3, 3, 2, 2, 2, 1],
	Defs.P_RIG: [2, 1, 1, 0, 5, 3, 1, 2, 0, 1, 3, 3, 3, 3],
}

const BLURB_OPEN := ["Grab your %s and get ready!", "The world needs a hero with a %s.", "Nobody saw the %s coming.",
	"One %s. Endless trouble.", "Legends speak of a %s.", "It all started with a stolen %s."]
const BLURB_ITEMS := ["lucky spoon", "rubber chicken", "glowing map", "spare tire", "magic kazoo", "golden sock",
	"jetpack", "tiny umbrella", "secret recipe", "ancient remote"]
const BLURB_MID := ["Explore %d hand-crafted zones", "Battle through %d wild stages", "Unlock %d hidden secrets",
	"Master %d unique abilities", "Race across %d crazy tracks", "Befriend %d curious creatures"]
const BLURB_END := ["Fun for the whole household.", "Now with 40%% more wobble.", "Up to 4 players on one couch!",
	"Featuring a toe-tapping soundtrack.", "Award-winning* fun. (*probably)", "Includes bonus snack mode."]

# Words that must never appear in a generated name (keeps us clear of real franchises).
const BLOCKLIST := ["MARIO", "ZELDA", "HALO", "SONIC", "POKE", "FANTASY", "RESIDENT", "SILENT HILL", "FIGHTER",
	"KOMBAT", "METAL GEAR", "TURISMO", "SPEED", "DUTY", "SOULS", "SCROLLS", "CRASH", "SPYRO", "KIRBY",
	"METROID", "TEKKEN", "MADDEN", "GUITAR", "STARCRAFT", "DOOM", "QUAKE", "STAR FOX", "RATCHET", "BANJO",
	"RAYMAN", "PIKMIN", "GEARS OF", "FORZA", "DESTINY", "TITANFALL", "ARMORED CORE", "SPLINTER", "HITMAN",
	"DISHONORED", "DRAGON QUEST", "MONSTER HUNTER", "DIGIMON", "PERSONA", "ACE COMBAT", "RIDGE", "BURNOUT",
	"WIPEOUT", "MEGA MAN", "CASTLEVANIA", "BAYONETTA", "STARDEW", "HARVEST MOON", "ANIMAL CROSSING",
	"POCKET MONSTERS", "TETRIS", "PAC", "KART", "SMASH BROS", "MORTAL", "VICE CITY", "SAINTS", "SHENMUE",
	"GOLDEN SUN", "CRYSTAL CHRONICLES", "SILENT STORM", "IRON FIST", "SHADOW FOX", "STEEL BATTALION"]

func _ready() -> void:
	generate()

func generate() -> void:
	titles.clear()
	by_gid.clear()
	franchises.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = Defs.CATALOG_SEED * 7919 + Defs.CATALOG_VERSION
	var used_names := {}
	# Build titles platform by platform; some become franchises that recur on later platforms.
	var franchise_pool: Array = [] # [{base, genre, count}]
	for p in Defs.PLATFORMS.size():
		var pdef: Dictionary = Defs.PLATFORMS[p]
		var weights: Array = PLATFORM_GENRES[p]
		var n := 0
		var guard := 0
		while n < PER_PLATFORM and guard < 5000:
			guard += 1
			var genre := _weighted(rng, weights)
			var base := ""
			var full := ""
			var sub := ""
			var franchise_id := -1
			# 30%: continue an existing franchise of that genre
			if rng.randf() < 0.30 and franchise_pool.size() > 0:
				var cands := franchise_pool.filter(func(f): return f.genre == genre)
				if cands.size() > 0:
					var f: Dictionary = cands[rng.randi() % cands.size()]
					base = f.base
					franchise_id = f.id
					f.count += 1
					if rng.randf() < 0.5:
						sub = SEQUELS[mini(f.count - 2, SEQUELS.size() - 1)] if f.count >= 2 else SEQUELS[0]
						full = "%s %s" % [base, sub]
					else:
						sub = "%s %s" % [_pick(rng, SUBTITLE_A), _pick(rng, SUBTITLE_B)] if rng.randf() < 0.6 else _pick(rng, SUBTITLE_PLAIN)
						full = "%s: %s" % [base, sub]
			if full == "":
				base = _make_name(rng, genre)
				full = base
				if rng.randf() < 0.18:
					sub = _pick(rng, SUBTITLE_PLAIN)
					full = "%s: %s" % [base, sub]
				franchise_id = franchise_pool.size()
				franchise_pool.append({"id": franchise_id, "base": base, "genre": genre, "count": 1})
			var key := full.to_upper()
			if used_names.has(key) or _blocked(key):
				continue
			used_names[key] = true
			var yrs: Array = pdef.years
			var year := rng.randi_range(yrs[0], yrs[1])
			var discs := 1
			var multi_chance := 0.0
			match p:
				Defs.P_P32: multi_chance = 0.28 if genre == Defs.G_FANTASY else 0.10
				Defs.P_RIG: multi_chance = 0.30
				Defs.P_OX4, Defs.P_OX5, Defs.P_KST: multi_chance = 0.10 if genre == Defs.G_FANTASY else 0.03
				Defs.P_S16: multi_chance = 0.06
			if rng.randf() < multi_chance:
				discs = rng.randi_range(2, 4)
			var editions := [Defs.E_STANDARD]
			if p in [Defs.P_OX4, Defs.P_OX5, Defs.P_KST] and rng.randf() < 0.32:
				editions.append(Defs.E_STEEL)
			if p in [Defs.P_OX4, Defs.P_OX5, Defs.P_KST, Defs.P_RIG, Defs.P_P32] and rng.randf() < 0.22:
				editions.append(Defs.E_CE)
			if p in [Defs.P_OX4, Defs.P_OX5, Defs.P_KST, Defs.P_P32, Defs.P_BLP, Defs.P_PIP] and rng.randf() < 0.28:
				editions.append(Defs.E_GH)
			var rating := clampi(_genre_rating(genre) + rng.randi_range(-1, 1), 0, 4)
			var gid := "%s_%03d" % [String(pdef.code).to_lower(), n]
			var t := {
				"idx": titles.size(), "gid": gid, "name": full, "base": base, "subtitle": sub,
				"platform": p, "genre": genre, "publisher": rng.randi() % Defs.PUBLISHERS.size(),
				"year": year, "rating": rating, "discs": discs, "editions": editions,
				"seed": rng.randi(), "franchise": franchise_id,
				"blurb": _blurb(rng),
			}
			by_gid[gid] = titles.size()
			titles.append(t)
			n += 1
	franchises = franchise_pool

func _blocked(key: String) -> bool:
	for w in BLOCKLIST:
		if key.find(w) != -1:
			return true
	return false

func _make_name(rng: RandomNumberGenerator, genre: int) -> String:
	var v: Array = VOCAB[genre]
	var a: String = _pick(rng, v[0])
	var b: String = _pick(rng, v[1])
	var c: String = _pick(rng, v[2])
	var r := rng.randf()
	if r < 0.45:
		return "%s %s %s" % [a, b, c]
	elif r < 0.65:
		return "%s %s" % [b, c] if b != c else "%s %s" % [a, c]
	elif r < 0.82:
		return "%s %s" % [a, b]
	else:
		return "The %s %s" % [a, b]

func _genre_rating(g: int) -> int:
	match g:
		Defs.G_HORROR, Defs.G_CRIME: return 4
		Defs.G_STEALTH, Defs.G_MECH, Defs.G_FIGHTING: return 3
		Defs.G_SPACE, Defs.G_FANTASY: return 2
		Defs.G_SPORTS, Defs.G_KART, Defs.G_RHYTHM: return 1
		_: return 0

func _blurb(rng: RandomNumberGenerator) -> String:
	return "%s %s. %s" % [_pick(rng, BLURB_OPEN) % _pick(rng, BLURB_ITEMS),
		_pick(rng, BLURB_MID) % rng.randi_range(8, 99), _pick(rng, BLURB_END)]

func _pick(rng: RandomNumberGenerator, arr: Array):
	return arr[rng.randi() % arr.size()]

func _weighted(rng: RandomNumberGenerator, w: Array) -> int:
	var total := 0
	for x in w:
		total += x
	var r := rng.randi() % maxi(total, 1)
	for i in w.size():
		r -= w[i]
		if r < 0:
			return i
	return 0

# ----------------------------------------------------------------- queries
func titles_for_platform(p: int) -> Array:
	return titles.filter(func(t): return t.platform == p)

func title(idx: int) -> Dictionary:
	return titles[idx]

func platform_of(idx: int) -> Dictionary:
	return Defs.PLATFORMS[titles[idx].platform]

func display_name(idx: int) -> String:
	return titles[idx].name
