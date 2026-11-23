class_name Defs
## Shared constants for DISC CHAOS: item kinds, case formats, editions, platforms, genres.

const CATALOG_VERSION := 5
const CATALOG_SEED := 0x0D15C

# ---------------------------------------------------------------- item kinds
enum { K_CASE, K_DISC, K_CEBOX, K_ARTBOOK, K_FIGURE, K_POSTER, K_MANUAL, K_CART }
const KIND_NAMES := ["Case", "Disc", "Collector's Box", "Artbook", "Figurine", "Poster", "Manual", "Cart"]

# ---------------------------------------------------------------- case formats
enum { F_MODERN, F_HANDHELD, F_MINI, F_JEWEL, F_LONGBOX, F_BIGBOX, F_CEBOX }
const FORMAT_NAMES := ["Case", "Handheld case", "Mini case", "Jewel case", "Long box", "Big box", "Collector's box"]
## Local size of each format: x = cover width, y = height, z = thickness. Front cover faces +Z,
## spine is on the -X edge.
const FORMAT_SIZE := [
	Vector3(0.175, 0.225, 0.022),  # modern
	Vector3(0.140, 0.170, 0.020),  # handheld
	Vector3(0.150, 0.150, 0.020),  # mini
	Vector3(0.180, 0.160, 0.016),  # jewel
	Vector3(0.190, 0.380, 0.036),  # long box
	Vector3(0.260, 0.330, 0.080),  # big box
	Vector3(0.300, 0.300, 0.160),  # collector's box
]
const DISC_RADIUS := [0.078, 0.052, 0.062, 0.078, 0.078, 0.078, 0.078]
const DISC_THICK := 0.004

const PIECE_SIZE := {
	K_ARTBOOK: Vector3(0.22, 0.26, 0.026),
	K_FIGURE: Vector3(0.09, 0.17, 0.09),
	K_POSTER: Vector3(0.05, 0.34, 0.05),
	K_MANUAL: Vector3(0.17, 0.22, 0.008),
}

# ---------------------------------------------------------------- editions
enum { E_STANDARD, E_STEEL, E_CE, E_GH }
const EDITION_NAMES := ["Standard", "Steelbook", "Collector's Edition", "Golden Greats"]
const EDITION_SHORT := ["STD", "STEEL", "CE", "GOLD"]

# ---------------------------------------------------------------- genres
enum { G_SPACE, G_KART, G_CRIME, G_MONSTER, G_FANTASY, G_HORROR, G_MASCOT, G_SPORTS,
	G_FIGHTING, G_RHYTHM, G_MECH, G_STEALTH, G_PUZZLE, G_FARM }
const GENRE_NAMES := ["Space Shooter", "Kart Racer", "Open-World Crime", "Monster Catching",
	"Fantasy RPG", "Survival Horror", "Mascot Platformer", "Sports", "Fighting", "Rhythm",
	"Mech Action", "Stealth", "Puzzle", "Farming Sim"]

# ---------------------------------------------------------------- platforms
## All platforms, consoles, publishers and logos are original inventions.
const PLATFORMS := [
	{"code": "OX4", "name": "ORBIX 4", "maker": "Orbix", "format": F_MODERN, "years": [2013, 2020],
		"case": Color(0.16, 0.33, 0.78), "banner": Color(0.08, 0.16, 0.45), "banner_text": Color(1, 1, 1),
		"logo": "orbit", "font": "orbitron", "family": "ORBIX"},
	{"code": "OX5", "name": "ORBIX 5", "maker": "Orbix", "format": F_MODERN, "years": [2020, 2026],
		"case": Color(0.93, 0.94, 0.97), "banner": Color(0.10, 0.70, 0.86), "banner_text": Color(1, 1, 1),
		"logo": "orbit2", "font": "orbitron", "family": "ORBIX"},
	{"code": "KST", "name": "Kestrel", "maker": "Kestrel Labs", "format": F_MODERN, "years": [2016, 2025],
		"case": Color(0.47, 0.24, 0.66), "banner": Color(0.20, 0.08, 0.30), "banner_text": Color(1.0, 0.86, 0.25),
		"logo": "wing", "font": "righteous", "family": "KESTREL"},
	{"code": "PIP", "name": "Pip-Go", "maker": "Pipworks", "format": F_HANDHELD, "years": [2017, 2026],
		"case": Color(1.0, 0.80, 0.22), "banner": Color(0.98, 0.48, 0.15), "banner_text": Color(1, 1, 1),
		"logo": "pip", "font": "fredoka", "family": "PIP"},
	{"code": "BLP", "name": "Bloop Mini", "maker": "Bloop Co.", "format": F_MINI, "years": [2001, 2007],
		"case": Color(0.98, 0.50, 0.47), "banner": Color(0.12, 0.62, 0.62), "banner_text": Color(1, 1, 1),
		"logo": "bubbles", "font": "fredoka", "family": "BLOOP"},
	{"code": "S16", "name": "Sprocket 16", "maker": "Sprocket", "format": F_LONGBOX, "years": [1990, 1996],
		"case": Color(0.13, 0.13, 0.16), "banner": Color(0.13, 0.13, 0.16), "banner_text": Color(1, 1, 1),
		"logo": "gear", "font": "press-start-2p", "family": "SPROCKET"},
	{"code": "P32", "name": "Prism-32", "maker": "Prism", "format": F_JEWEL, "years": [1995, 2002],
		"case": Color(0.22, 0.22, 0.27), "banner": Color(0.95, 0.95, 0.97), "banner_text": Color(0.15, 0.15, 0.2),
		"logo": "prism", "font": "bungee", "family": "PRISM"},
	{"code": "RIG", "name": "HomeRig PC", "maker": "HomeRig", "format": F_BIGBOX, "years": [1993, 2005],
		"case": Color(0.85, 0.82, 0.74), "banner": Color(0.05, 0.22, 0.10), "banner_text": Color(0.35, 1.0, 0.45),
		"logo": "monitor", "font": "black-ops-one", "family": "HOMERIG"},
]
enum { P_OX4, P_OX5, P_KST, P_PIP, P_BLP, P_S16, P_P32, P_RIG }

const PUBLISHERS := [
	{"name": "Wobblesoft", "shape": "circle", "color": Color(0.95, 0.35, 0.35)},
	{"name": "Pancake Forge", "shape": "stack", "color": Color(0.95, 0.70, 0.30)},
	{"name": "Neon Yeti", "shape": "triangle", "color": Color(0.30, 0.85, 0.95)},
	{"name": "Moonbean Studios", "shape": "moon", "color": Color(0.70, 0.60, 0.95)},
	{"name": "Krunchware", "shape": "square", "color": Color(0.40, 0.80, 0.40)},
	{"name": "Pebble Pixel", "shape": "pixel", "color": Color(0.60, 0.60, 0.65)},
	{"name": "Grumbletooth", "shape": "tooth", "color": Color(0.90, 0.90, 0.85)},
	{"name": "Kettle Komet", "shape": "star", "color": Color(1.0, 0.85, 0.20)},
	{"name": "Mossy Byte", "shape": "leaf", "color": Color(0.35, 0.70, 0.35)},
	{"name": "Saucer Planet", "shape": "saucer", "color": Color(0.55, 0.90, 0.70)},
	{"name": "Jellyhaus", "shape": "blob", "color": Color(0.95, 0.45, 0.75)},
	{"name": "Biscuit Bunker", "shape": "square", "color": Color(0.80, 0.60, 0.40)},
	{"name": "Hoot Owl Interactive", "shape": "circle", "color": Color(0.55, 0.40, 0.30)},
	{"name": "Tidepool Arcade", "shape": "wave", "color": Color(0.25, 0.55, 0.95)},
	{"name": "Picklebolt", "shape": "bolt", "color": Color(0.55, 0.80, 0.20)},
	{"name": "Gizmo Garden", "shape": "hex", "color": Color(0.95, 0.55, 0.20)},
]

## Fictional age rating board "PLAYSAFE".
const RATINGS := [
	{"label": "ALL", "color": Color(0.30, 0.75, 0.35)},
	{"label": "7+", "color": Color(0.55, 0.80, 0.25)},
	{"label": "12+", "color": Color(0.98, 0.78, 0.20)},
	{"label": "16+", "color": Color(0.98, 0.52, 0.18)},
	{"label": "18+", "color": Color(0.90, 0.22, 0.22)},
]

const TITLE_FONTS_BY_GENRE := ["orbitron", "racing-sans-one", "permanent-marker", "fredoka",
	"righteous", "creepster", "lilita-one", "bungee", "black-ops-one", "monoton",
	"black-ops-one", "orbitron", "lilita-one", "fredoka"]

# ---------------------------------------------------------------- physics layers
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ITEM := 4
const LAYER_CART := 8

# ---------------------------------------------------------------- helpers
static func item_size(kind: int, fmt: int) -> Vector3:
	match kind:
		K_CASE: return FORMAT_SIZE[fmt]
		K_CEBOX: return FORMAT_SIZE[F_CEBOX]
		K_DISC:
			var r: float = DISC_RADIUS[fmt]
			return Vector3(r * 2.0, DISC_THICK, r * 2.0)
		K_CART: return Vector3(0.7, 0.9, 1.0)
		_: return PIECE_SIZE.get(kind, Vector3(0.1, 0.1, 0.1))

static func is_root_kind(kind: int) -> bool:
	return kind == K_CASE or kind == K_CEBOX

static func letter_of(s: String) -> String:
	var u := s.to_upper()
	if u.begins_with("THE "):
		u = u.substr(4)
	for i in u.length():
		var c := u[i]
		if c >= "A" and c <= "Z":
			return c
		if c >= "0" and c <= "9":
			return "#"
	return "#"

static func sort_name(s: String) -> String:
	var u := s.to_upper()
	if u.begins_with("THE "):
		u = u.substr(4)
	return u
