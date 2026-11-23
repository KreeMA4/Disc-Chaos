class_name CoverPalette
extends RefCounted
## Palette derived from a title's seed. Shared by the cover painter and item tinting so cases,
## discs, figurines and boxes of one game all share colors.

static func palette(t: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t.seed)
	var h := rng.randf()
	var genre: int = t.genre
	var dark_bias := 0.0
	match genre:
		Defs.G_HORROR: h = 0.30 + rng.randf() * 0.15; dark_bias = 0.2
		Defs.G_SPACE: h = 0.62 + rng.randf() * 0.18; dark_bias = 0.25
		Defs.G_STEALTH: h = 0.55 + rng.randf() * 0.1; dark_bias = 0.18
		Defs.G_FARM: h = 0.1 + rng.randf() * 0.15
		Defs.G_CRIME: h = 0.88 + rng.randf() * 0.15
		Defs.G_MECH: h = rng.randf() * 0.15 + 0.02
	h = fposmod(h, 1.0)
	var comp := fposmod(h + 0.45 + rng.randf() * 0.1, 1.0)
	return {
		"h": h,
		"sky1": Color.from_ok_hsl(h, 0.65, clampf(0.55 - dark_bias, 0.1, 0.9)),
		"sky2": Color.from_ok_hsl(fposmod(h + 0.08, 1.0), 0.75, clampf(0.78 - dark_bias, 0.15, 0.95)),
		"accent": Color.from_ok_hsl(comp, 0.85, 0.65),
		"accent2": Color.from_ok_hsl(fposmod(comp + 0.15, 1.0), 0.8, 0.6),
		"dark": Color.from_ok_hsl(h, 0.45, 0.14),
		"mid": Color.from_ok_hsl(h, 0.5, 0.35),
		"light": Color.from_ok_hsl(fposmod(h + 0.05, 1.0), 0.6, 0.92),
		"title": Color.from_ok_hsl(fposmod(comp + 0.05, 1.0), 0.95, 0.72),
		"seed": int(t.seed),
	}

static func accent_of(t: Dictionary) -> Color:
	return palette(t).accent
