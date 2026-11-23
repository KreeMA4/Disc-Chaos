class_name PropFactory
extends RefCounted
## Procedural props. spec() is pure data (footprint, collision, surfaces, stash spill point) and
## is used by layouts/tests without rendering. build() appends bevelled geometry to a MeshKit so
## every prop in a room merges into a few meshes.
##
## Channels: "toon" (opaque vertex-colored), "emit" (glowing), "glass" (transparent), "screen".

const WOOD := Color(0.72, 0.50, 0.32)
const WOOD_LIGHT := Color(0.86, 0.68, 0.46)
const WOOD_DARK := Color(0.45, 0.30, 0.20)
const WHITE := Color(0.96, 0.95, 0.92)
const DARK := Color(0.18, 0.18, 0.22)
const METAL := Color(0.62, 0.64, 0.70)

static func spec(type: String, p := {}) -> Dictionary:
	match type:
		"bed": return {"size": Vector3(1.2, 0.55, 2.1), "collide": true, "surface": {"w": 1.0, "d": 1.4, "h": 0.56, "offset": Vector3(0, 0, 0.25)}, "spill": Vector3(0.95, 0.3, 0)}
		"desk": return {"size": Vector3(1.4, 0.76, 0.7), "collide": true, "surface": {"w": 1.25, "d": 0.55, "h": 0.76}}
		"chair": return {"size": Vector3(0.5, 0.9, 0.5), "collide": true}
		"gaming_chair": return {"size": Vector3(0.6, 1.25, 0.6), "collide": true}
		"dresser": return {"size": Vector3(1.0, 0.95, 0.5), "collide": true, "surface": {"w": 0.9, "d": 0.42, "h": 0.95}, "spill": Vector3(0, 0.4, 0.7)}
		"nightstand": return {"size": Vector3(0.5, 0.55, 0.45), "collide": true, "surface": {"w": 0.42, "d": 0.38, "h": 0.55}, "spill": Vector3(0, 0.3, 0.55)}
		"wardrobe": return {"size": Vector3(1.2, 2.1, 0.6), "collide": true}
		"sofa": return {"size": Vector3(2.2, 0.85, 0.95), "collide": true, "surface": {"w": 1.8, "d": 0.5, "h": 0.45, "offset": Vector3(0, 0, 0.12)}, "spill": Vector3(0, 0.3, 0.9)}
		"armchair": return {"size": Vector3(0.95, 0.85, 0.9), "collide": true}
		"coffee_table": return {"size": Vector3(1.2, 0.42, 0.65), "collide": true, "surface": {"w": 1.1, "d": 0.55, "h": 0.42}}
		"tv_stand": return {"size": Vector3(1.8, 0.5, 0.48), "collide": true, "surface": {"w": 0.35, "d": 0.4, "h": 0.5, "offset": Vector3(0.7, 0, 0)}, "spill": Vector3(0, 0.35, 0.75)}
		"tv": return {"size": Vector3(1.4, 0.85, 0.12), "collide": false}
		"beanbag": return {"size": Vector3(0.95, 0.65, 0.95), "collide": true, "spill": Vector3(0, 0.3, 0.85)}
		"rug": return {"size": Vector3(p.get("w", 2.4), 0.02, p.get("d", 1.6)), "collide": false}
		"rug_round": return {"size": Vector3(p.get("r", 1.0) * 2, 0.02, p.get("r", 1.0) * 2), "collide": false}
		"lamp_floor": return {"size": Vector3(0.4, 1.6, 0.4), "collide": true}
		"lamp_desk": return {"size": Vector3(0.25, 0.45, 0.25), "collide": false}
		"plant_big": return {"size": Vector3(0.6, 1.4, 0.6), "collide": true}
		"plant_small": return {"size": Vector3(0.25, 0.35, 0.25), "collide": false}
		"monitor": return {"size": Vector3(0.6, 0.45, 0.2), "collide": false}
		"pc_tower": return {"size": Vector3(0.22, 0.48, 0.48), "collide": true}
		"console": return {"size": Vector3(0.38, 0.09, 0.3), "collide": false}
		"speaker": return {"size": Vector3(0.25, 0.4, 0.25), "collide": false}
		"speaker_big": return {"size": Vector3(0.4, 1.0, 0.4), "collide": true}
		"cardboard_box": return {"size": p.get("size", Vector3(0.55, 0.4, 0.45)), "collide": true, "spill": Vector3(0, 0.4, 0.65), "surface": {"w": p.get("size", Vector3(0.55, 0.4, 0.45)).x * 0.9, "d": p.get("size", Vector3(0.55, 0.4, 0.45)).z * 0.9, "h": p.get("size", Vector3(0.55, 0.4, 0.45)).y}}
		"delivery_box": return {"size": Vector3(0.7, 0.55, 0.6), "collide": true, "spill": Vector3(0, 0.45, 0.8)}
		"pizza_box": return {"size": Vector3(0.42, 0.05 * p.get("stack", 1), 0.42), "collide": false}
		"snack": return {"size": Vector3(0.15, 0.03, 0.1), "collide": false}
		"soda": return {"size": Vector3(0.07, 0.12, 0.07), "collide": false}
		"cable": return {"size": Vector3(1.0, 0.02, 0.4), "collide": false}
		"string_lights": return {"size": Vector3(p.get("len", 3.0), 0.3, 0.05), "collide": false}
		"figure_shelf": return {"size": Vector3(0.9, 0.04, 0.22), "collide": false}
		"arcade": return {"size": Vector3(0.75, 1.8, 0.8), "collide": true}
		"checkout": return {"size": Vector3(2.6, 1.0, 0.8), "collide": true, "surface": {"w": 2.4, "d": 0.65, "h": 1.0}}
		"kiosk": return {"size": Vector3(0.9, 1.6, 0.6), "collide": true}
		"bargain_bin": return {"size": Vector3(1.4, 0.8, 0.9), "collide": true, "surface": {"w": 1.25, "d": 0.75, "h": 0.55}, "spill": Vector3(0, 0.6, 0.85)}
		"trunk": return {"size": Vector3(1.0, 0.6, 0.55), "collide": true, "spill": Vector3(0, 0.4, 0.75), "surface": {"w": 0.9, "d": 0.45, "h": 0.6}}
		"old_tv": return {"size": Vector3(0.6, 0.55, 0.55), "collide": true}
		"rocking_chair": return {"size": Vector3(0.65, 1.1, 0.9), "collide": true}
		"dust_sheet": return {"size": Vector3(1.4, 0.9, 0.9), "collide": true, "spill": Vector3(0, 0.3, 0.9)}
		"workbench": return {"size": Vector3(1.8, 0.9, 0.7), "collide": true, "surface": {"w": 1.7, "d": 0.6, "h": 0.9}}
		"washer": return {"size": Vector3(0.65, 0.9, 0.65), "collide": true}
		"boiler": return {"size": Vector3(0.7, 1.8, 0.7), "collide": true}
		"pallet": return {"size": Vector3(1.2, 0.15, 1.0), "collide": true, "surface": {"w": 1.1, "d": 0.9, "h": 0.15}}
		"sort_table": return {"size": Vector3(1.6, 0.78, 0.8), "collide": true}
		"radiator": return {"size": Vector3(0.9, 0.6, 0.12), "collide": true}
		"laundry": return {"size": Vector3(0.7, 0.3, 0.6), "collide": false}
		"guitar": return {"size": Vector3(0.4, 1.0, 0.15), "collide": false}
		"skateboard": return {"size": Vector3(0.8, 0.1, 0.22), "collide": false}
		"ball": return {"size": Vector3(0.24, 0.24, 0.24), "collide": false}
		"headphones": return {"size": Vector3(0.2, 0.2, 0.1), "collide": false}
		"controller": return {"size": Vector3(0.16, 0.05, 0.1), "collide": false}
		"books": return {"size": Vector3(0.4, 0.25, 0.2), "collide": false}
		"ceiling_lamp": return {"size": Vector3(0.5, 0.3, 0.5), "collide": false}
		"panel_light": return {"size": Vector3(1.2, 0.05, 0.6), "collide": false}
		"gondola": return {"size": Vector3(p.get("len", 2.4), 1.5, 0.9), "collide": true, "surface": {"w": p.get("len", 2.4) - 0.1, "d": 0.8, "h": 1.5}}
		"display_table": return {"size": Vector3(1.6, 0.8, 1.0), "collide": true, "surface": {"w": 1.5, "d": 0.9, "h": 0.8}}
		"neon_sign": return {"size": Vector3(1.5, 0.5, 0.06), "collide": false}
		"window_display": return {"size": Vector3(2.0, 0.5, 0.8), "collide": true, "surface": {"w": 1.9, "d": 0.7, "h": 0.5}}
		"stairs": return {"size": Vector3(1.0, 2.6, 2.4), "collide": true}
		"fridge": return {"size": Vector3(0.6, 1.2, 0.6), "collide": true, "surface": {"w": 0.5, "d": 0.5, "h": 1.2}}
		"ironing_board": return {"size": Vector3(1.3, 0.9, 0.4), "collide": true}
		"easel": return {"size": Vector3(0.6, 1.5, 0.5), "collide": true}
		"clothes_rack": return {"size": Vector3(1.2, 1.6, 0.5), "collide": true}
		"suitcase": return {"size": Vector3(0.7, 0.25, 0.45), "collide": true, "spill": Vector3(0, 0.3, 0.6)}
		"globe": return {"size": Vector3(0.3, 0.45, 0.3), "collide": false}
		"fan": return {"size": Vector3(0.45, 1.3, 0.45), "collide": true}
		"cushion": return {"size": Vector3(0.45, 0.15, 0.45), "collide": false}
		"trophy": return {"size": Vector3(0.12, 0.25, 0.12), "collide": false}
		"cart_return": return {"size": Vector3(1.0, 1.0, 0.3), "collide": true}
		"shopping_basket": return {"size": Vector3(0.45, 0.25, 0.32), "collide": false}
		"mirror_frame": return {"size": Vector3(0.9, 1.9, 0.12), "collide": true}
		"door": return {"size": Vector3(0.95, 2.1, 0.08), "collide": false}
		"rafter": return {"size": Vector3(p.get("len", 6.0), 0.2, 0.18), "collide": false}
		"fireplace": return {"size": Vector3(1.6, 1.2, 0.5), "collide": true, "surface": {"w": 1.6, "d": 0.3, "h": 1.2}}
		"crate_stack": return {"size": Vector3(0.6, 0.9, 0.6), "collide": true}
		"cobweb": return {"size": Vector3(0.6, 0.6, 0.02), "collide": false}
		"bulb": return {"size": Vector3(0.1, 0.5, 0.1), "collide": false}
		"pinball": return {"size": Vector3(0.75, 1.9, 1.4), "collide": true}
		"shelf_decor": return {"size": Vector3(1.2, 1.8, 0.3), "collide": true}
	return {"size": Vector3(0.3, 0.3, 0.3), "collide": false}

static func _t(xf: Transform3D, x: float, y: float, z: float, yaw := 0.0) -> Transform3D:
	return xf * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))

static func _tr(xf: Transform3D, pos: Vector3, rot: Vector3) -> Transform3D:
	return xf * Transform3D(Basis.from_euler(rot), pos)

static func build(k: MeshKit, type: String, xf: Transform3D, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var c1: Color = p.get("color", Color.from_hsv(rng.randf(), 0.45, 0.9))
	var c2: Color = p.get("color2", Color.from_hsv(rng.randf(), 0.35, 0.95))
	match type:
		"bed":
			k.box("toon", _t(xf, 0, 0.17, 0), Vector3(1.2, 0.3, 2.1), WOOD, 0.04)
			k.box("toon", _t(xf, 0, 0.6, -1.0), Vector3(1.2, 0.9, 0.1), WOOD, 0.04)
			k.box("toon", _t(xf, 0, 0.4, 0.05), Vector3(1.1, 0.22, 2.0), WHITE, 0.08)
			k.box("toon", _t(xf, 0, 0.52, 0.3), Vector3(1.16, 0.1, 1.45), c1, 0.05)
			k.box("toon", _t(xf, 0.02, 0.58, 0.05), Vector3(1.0, 0.06, 0.4), c1.lightened(0.2), 0.03)
			k.box("toon", _t(xf, -0.25, 0.56, -0.75, 0.1), Vector3(0.42, 0.12, 0.28), c2, 0.06)
			k.box("toon", _t(xf, 0.25, 0.56, -0.75, -0.15), Vector3(0.42, 0.12, 0.28), c2.lightened(0.15), 0.06)
			for sx in [-0.55, 0.55]:
				for sz in [-0.98, 0.98]:
					k.box("toon", _t(xf, sx, 0.05, sz), Vector3(0.08, 0.1, 0.08), WOOD_DARK, 0.02)
		"desk":
			var dc: Color = p.get("color", WOOD_LIGHT)
			k.box("toon", _t(xf, 0, 0.74, 0), Vector3(1.4, 0.05, 0.7), dc, 0.015)
			k.box("toon", _t(xf, 0.48, 0.36, 0), Vector3(0.4, 0.72, 0.64), dc.darkened(0.1), 0.02)
			for i in 3:
				k.box("toon", _t(xf, 0.48, 0.15 + i * 0.22, 0.325), Vector3(0.34, 0.17, 0.02), dc.lightened(0.1), 0.01)
				k.box("toon", _t(xf, 0.48, 0.18 + i * 0.22, 0.34), Vector3(0.1, 0.02, 0.02), METAL, 0.005)
			k.box("toon", _t(xf, -0.66, 0.36, 0), Vector3(0.05, 0.72, 0.62), dc.darkened(0.1), 0.01)
		"chair":
			k.box("toon", _t(xf, 0, 0.45, 0), Vector3(0.46, 0.06, 0.44), c1, 0.025)
			k.box("toon", _t(xf, 0, 0.72, -0.2), Vector3(0.44, 0.5, 0.05), c1, 0.025)
			for sx in [-0.19, 0.19]:
				for sz in [-0.18, 0.18]:
					k.cylinder("toon", _t(xf, sx, 0.21, sz), 0.02, 0.42, WOOD_DARK, 6)
		"gaming_chair":
			k.cylinder("toon", _t(xf, 0, 0.06, 0), 0.3, 0.04, DARK, 10)
			k.cylinder("toon", _t(xf, 0, 0.27, 0), 0.03, 0.4, METAL, 6)
			k.box("toon", _t(xf, 0, 0.5, 0), Vector3(0.55, 0.12, 0.52), c1.darkened(0.4), 0.05)
			k.box("toon", _t(xf, 0, 0.92, -0.24, 0), Vector3(0.52, 0.75, 0.12), c1.darkened(0.4), 0.06)
			k.box("toon", _t(xf, 0, 0.95, -0.17), Vector3(0.22, 0.55, 0.02), c1, 0.01)
			k.box("toon", _t(xf, 0, 1.2, -0.2), Vector3(0.3, 0.12, 0.1), c1, 0.04)
		"dresser", "nightstand":
			var sz: Vector3 = spec(type).size
			var dc2: Color = p.get("color", Color(0.93, 0.90, 0.85) if rng.randf() < 0.5 else WOOD)
			k.box("toon", _t(xf, 0, sz.y * 0.5 + 0.03, 0), Vector3(sz.x, sz.y - 0.06, sz.z), dc2, 0.025)
			var rows := 3 if type == "dresser" else 2
			for i in rows:
				var hy := (sz.y - 0.1) / rows
				var y := 0.08 + hy * (i + 0.5)
				k.box("toon", _t(xf, 0, y, sz.z * 0.5 + 0.005), Vector3(sz.x - 0.08, hy - 0.04, 0.02), dc2.lightened(0.08), 0.01)
				k.sphere("toon", _t(xf, 0, y, sz.z * 0.5 + 0.03), Vector3(0.025, 0.025, 0.025), WOOD_DARK, 4, 6)
			for sx in [-1, 1]:
				k.box("toon", _t(xf, sx * (sz.x * 0.5 - 0.05), 0.015, 0), Vector3(0.06, 0.03, sz.z - 0.05), WOOD_DARK, 0.01)
		"wardrobe":
			var wc: Color = p.get("color", WHITE)
			k.box("toon", _t(xf, 0, 1.05, 0), Vector3(1.2, 2.1, 0.6), wc, 0.03)
			k.box("toon", _t(xf, 0, 1.05, 0.305), Vector3(0.01, 1.95, 0.01), wc.darkened(0.3), 0.0)
			k.box("toon", _t(xf, -0.06, 1.1, 0.32), Vector3(0.025, 0.25, 0.025), METAL, 0.008)
			k.box("toon", _t(xf, 0.06, 1.1, 0.32), Vector3(0.025, 0.25, 0.025), METAL, 0.008)
		"sofa":
			var sc: Color = p.get("color", Color(0.38, 0.55, 0.75))
			k.box("toon", _t(xf, 0, 0.25, 0.05), Vector3(2.2, 0.3, 0.85), sc.darkened(0.1), 0.08)
			k.box("toon", _t(xf, 0, 0.6, -0.36), Vector3(2.2, 0.55, 0.22), sc.darkened(0.05), 0.1)
			for sx in [-1.0, 1.0]:
				k.box("toon", _t(xf, sx * 1.0, 0.48, 0.02), Vector3(0.22, 0.4, 0.9), sc.darkened(0.08), 0.1)
			for i in 3:
				k.box("toon", _t(xf, -0.6 + i * 0.6, 0.45, 0.1), Vector3(0.58, 0.14, 0.62), sc, 0.06)
				k.box("toon", _t(xf, -0.6 + i * 0.6, 0.65, -0.22, 0), Vector3(0.56, 0.42, 0.14), sc.lightened(0.05), 0.07)
			k.box("toon", _t(xf, -0.75, 0.62, -0.08, 0.3), Vector3(0.38, 0.32, 0.12), c2, 0.07)
		"armchair":
			var ac: Color = p.get("color", Color(0.85, 0.55, 0.35))
			k.box("toon", _t(xf, 0, 0.25, 0.05), Vector3(0.9, 0.3, 0.8), ac.darkened(0.1), 0.08)
			k.box("toon", _t(xf, 0, 0.6, -0.33), Vector3(0.9, 0.55, 0.2), ac, 0.09)
			for sx in [-1.0, 1.0]:
				k.box("toon", _t(xf, sx * 0.38, 0.48, 0.02), Vector3(0.18, 0.38, 0.8), ac.darkened(0.05), 0.08)
			k.box("toon", _t(xf, 0, 0.44, 0.08), Vector3(0.58, 0.12, 0.6), ac.lightened(0.08), 0.05)
		"coffee_table":
			k.box("toon", _t(xf, 0, 0.4, 0), Vector3(1.2, 0.05, 0.65), WOOD, 0.02)
			k.box("toon", _t(xf, 0, 0.12, 0), Vector3(1.05, 0.03, 0.55), WOOD_DARK, 0.01)
			for sx in [-0.55, 0.55]:
				for sz in [-0.27, 0.27]:
					k.box("toon", _t(xf, sx, 0.2, sz), Vector3(0.05, 0.4, 0.05), WOOD_DARK, 0.01)
		"tv_stand":
			k.box("toon", _t(xf, 0, 0.25, 0), Vector3(1.8, 0.48, 0.48), p.get("color", Color(0.28, 0.26, 0.3)), 0.03)
			for i in 3:
				k.box("toon", _t(xf, -0.6 + i * 0.6, 0.22, 0.245), Vector3(0.55, 0.36, 0.015), Color(0.2, 0.2, 0.24), 0.005)
			k.box("toon", _t(xf, -0.1, 0.53, 0.0), Vector3(0.38, 0.06, 0.28), Color(0.95, 0.95, 0.97), 0.02)
			k.box("emit", _t(xf, 0.05, 0.55, 0.145), Vector3(0.05, 0.008, 0.005), Color(0.2, 0.9, 1.0), 0.0)
		"tv":
			k.box("toon", _t(xf, 0, 0.47, 0), Vector3(1.4, 0.8, 0.06), DARK, 0.02)
			k.box("toon", _t(xf, 0, 0.04, 0), Vector3(0.4, 0.03, 0.2), DARK, 0.01)
			k.box("toon", _t(xf, 0, 0.12, -0.02), Vector3(0.06, 0.15, 0.04), DARK, 0.01)
			k.plane("screen", _t(xf, 0, 0.47, 0.032), Vector2(1.32, 0.72), Color(1, 1, 1))
		"beanbag":
			var bc: Color = p.get("color", Color.from_hsv(rng.randf(), 0.55, 0.85))
			k.blob("toon", _t(xf, 0, 0.3, 0), Vector3(0.95, 0.62, 0.95), bc)
			k.blob("toon", _tr(xf, Vector3(0, 0.55, -0.18), Vector3(-0.5, 0, 0)), Vector3(0.7, 0.4, 0.45), bc.lightened(0.06))
		"rug":
			var rc: Color = p.get("color", c1)
			var w: float = p.get("w", 2.4)
			var d: float = p.get("d", 1.6)
			k.box("toon", _t(xf, 0, 0.006, 0), Vector3(w, 0.012, d), rc, 0.004)
			k.box("toon", _t(xf, 0, 0.008, 0), Vector3(w - 0.25, 0.012, d - 0.25), rc.lightened(0.2), 0.004)
			k.box("toon", _t(xf, 0, 0.01, 0), Vector3(w - 0.5, 0.012, d - 0.5), p.get("color2", c2), 0.004)
		"rug_round":
			var r: float = p.get("r", 1.0)
			k.cylinder("toon", _t(xf, 0, 0.006, 0), r, 0.012, c1, 24)
			k.cylinder("toon", _t(xf, 0, 0.009, 0), r * 0.75, 0.012, c2, 24)
			k.cylinder("toon", _t(xf, 0, 0.012, 0), r * 0.45, 0.012, c1.lightened(0.25), 20)
		"lamp_floor":
			k.cylinder("toon", _t(xf, 0, 0.02, 0), 0.18, 0.04, DARK, 12)
			k.cylinder("toon", _t(xf, 0, 0.75, 0), 0.02, 1.45, METAL, 6)
			k.cylinder("emit", _t(xf, 0, 1.45, 0), 0.22, 0.28, Color(1.0, 0.85, 0.6), 14, 0.14)
		"lamp_desk":
			k.cylinder("toon", _t(xf, 0, 0.015, 0), 0.08, 0.03, c1, 10)
			k.cylinder("toon", _t(xf, 0, 0.18, 0), 0.012, 0.32, METAL, 6)
			k.cylinder("emit", _t(xf, 0, 0.36, 0), 0.1, 0.13, Color(1.0, 0.88, 0.65), 12, 0.06)
		"plant_big":
			k.cylinder("toon", _t(xf, 0, 0.2, 0), 0.22, 0.4, p.get("pot", Color(0.85, 0.5, 0.35)), 12, 0.26)
			k.cylinder("toon", _t(xf, 0, 0.39, 0), 0.24, 0.03, Color(0.35, 0.25, 0.18), 12)
			for i in 7:
				var a := TAU * i / 7.0 + rng.randf() * 0.4
				var leaf := Color(0.25 + rng.randf() * 0.15, 0.6 + rng.randf() * 0.2, 0.3)
				k.blob("toon", _tr(xf, Vector3(cos(a) * 0.18, 0.75 + rng.randf() * 0.45, sin(a) * 0.18), Vector3(rng.randf() * 0.6 - 0.3, a, 0.7)), Vector3(0.18, 0.5, 0.06), leaf)
			k.cylinder("toon", _t(xf, 0, 0.65, 0), 0.02, 0.6, Color(0.35, 0.5, 0.25), 5)
		"plant_small":
			k.cylinder("toon", _t(xf, 0, 0.07, 0), 0.07, 0.14, p.get("pot", Color(0.95, 0.95, 0.9)), 10, 0.09)
			for i in 5:
				var a := TAU * i / 5.0
				k.blob("toon", _tr(xf, Vector3(cos(a) * 0.05, 0.2, sin(a) * 0.05), Vector3(0.4 * cos(a), a, 0.5)), Vector3(0.06, 0.16, 0.03), Color(0.3, 0.7, 0.35))
		"monitor":
			k.box("toon", _t(xf, 0, 0.28, 0), Vector3(0.6, 0.36, 0.03), DARK, 0.012)
			k.plane("screen", _t(xf, 0, 0.28, 0.016), Vector2(0.56, 0.32), Color(1, 1, 1))
			k.box("toon", _t(xf, 0, 0.06, -0.02), Vector3(0.04, 0.12, 0.03), DARK, 0.01)
			k.box("toon", _t(xf, 0, 0.01, -0.02), Vector3(0.22, 0.02, 0.15), DARK, 0.01)
		"pc_tower":
			k.box("toon", _t(xf, 0, 0.24, 0), Vector3(0.22, 0.48, 0.48), DARK, 0.02)
			k.box("emit", _t(xf, 0.112, 0.3, 0), Vector3(0.005, 0.3, 0.35), Color.from_hsv(rng.randf(), 0.8, 1.0) * 0.8, 0.0)
		"console":
			var cc: Color = p.get("color", [WHITE, DARK, Color(0.4, 0.3, 0.6)][rng.randi() % 3])
			k.box("toon", _t(xf, 0, 0.045, 0), Vector3(0.38, 0.09, 0.3), cc, 0.03)
			k.box("emit", _t(xf, 0.12, 0.05, 0.151), Vector3(0.06, 0.008, 0.004), Color(0.3, 0.8, 1.0), 0.0)
			k.box("toon", _t(xf, -0.05, 0.091, 0.0), Vector3(0.2, 0.004, 0.18), cc.darkened(0.15), 0.0)
		"speaker":
			k.box("toon", _t(xf, 0, 0.2, 0), Vector3(0.25, 0.4, 0.25), DARK, 0.03)
			k.cylinder("toon", _tr(xf, Vector3(0, 0.25, 0.126), Vector3(PI / 2, 0, 0)), 0.08, 0.01, Color(0.3, 0.3, 0.35), 12)
			k.cylinder("toon", _tr(xf, Vector3(0, 0.08, 0.126), Vector3(PI / 2, 0, 0)), 0.04, 0.01, Color(0.3, 0.3, 0.35), 10)
		"speaker_big":
			k.box("toon", _t(xf, 0, 0.5, 0), Vector3(0.4, 1.0, 0.4), WOOD_DARK, 0.03)
			for i in 3:
				k.cylinder("toon", _tr(xf, Vector3(0, 0.25 + i * 0.27, 0.201), Vector3(PI / 2, 0, 0)), 0.12 - i * 0.03, 0.01, DARK, 14)
		"cardboard_box", "delivery_box":
			var s: Vector3 = spec(type, p).size
			var bc2 := Color(0.82, 0.64, 0.42).lerp(Color(0.75, 0.58, 0.38), rng.randf())
			k.box("toon", _t(xf, 0, s.y * 0.5, 0), s, bc2, 0.012)
			k.box("toon", _t(xf, 0, s.y + 0.001, 0), Vector3(s.x * 0.98, 0.004, 0.06), Color(0.85, 0.78, 0.6), 0.0)
			if type == "delivery_box":
				k.box("toon", _t(xf, 0.12, s.y * 0.6, s.z * 0.5 + 0.002), Vector3(0.18, 0.12, 0.004), WHITE, 0.0)
				k.box("toon", _t(xf, -0.15, s.y * 0.4, s.z * 0.5 + 0.002), Vector3(0.12, 0.12, 0.004), Color(0.2, 0.2, 0.2), 0.0)
			if p.get("open", false):
				k.box("toon", _tr(xf, Vector3(0, s.y + 0.08, s.z * 0.5 + 0.04), Vector3(-0.9, 0, 0)), Vector3(s.x * 0.95, 0.008, s.z * 0.45), bc2.lightened(0.05), 0.0)
		"pizza_box":
			var n: int = p.get("stack", 1)
			for i in n:
				k.box("toon", _t(xf, rng.randf() * 0.03, 0.025 + i * 0.05, rng.randf() * 0.03, rng.randf() * 0.3), Vector3(0.42, 0.045, 0.42), Color(0.9, 0.82, 0.68), 0.008)
				k.cylinder("toon", _t(xf, 0, 0.049 + i * 0.05, 0), 0.08, 0.004, Color(0.85, 0.2, 0.15), 10)
		"snack":
			var col := Color.from_hsv(rng.randf(), 0.8, 0.95)
			k.box("toon", _tr(xf, Vector3(0, 0.012, 0), Vector3(0, 0, 0.1)), Vector3(0.15, 0.02, 0.1), col, 0.008)
			k.box("toon", _t(xf, 0, 0.024, 0), Vector3(0.06, 0.004, 0.05), WHITE, 0.0)
		"soda":
			var sc2 := Color.from_hsv(rng.randf(), 0.75, 0.9)
			if p.get("tipped", false):
				k.cylinder("toon", _tr(xf, Vector3(0, 0.035, 0), Vector3(0, 0, PI / 2)), 0.035, 0.12, sc2, 10)
			else:
				k.cylinder("toon", _t(xf, 0, 0.06, 0), 0.035, 0.12, sc2, 10)
				k.cylinder("toon", _t(xf, 0, 0.122, 0), 0.03, 0.004, METAL, 10)
		"cable":
			var cc2: Color = p.get("color", DARK)
			var prev := Vector3(-0.5, 0.008, 0)
			for i in 8:
				var nx := Vector3(-0.5 + (i + 1) / 8.0, 0.008, sin(i * 1.3 + rng.randf()) * 0.15)
				var mid := (prev + nx) * 0.5
				var d3 := nx - prev
				k.box("toon", xf * Transform3D(Basis(Vector3.UP, -atan2(d3.z, d3.x)), mid), Vector3(d3.length() + 0.01, 0.012, 0.012), cc2, 0.0)
				prev = nx
		"string_lights":
			var length: float = p.get("len", 3.0)
			var segs := int(length / 0.18)
			for i in segs:
				var t := float(i) / float(maxi(segs - 1, 1))
				var x := -length * 0.5 + t * length
				var y := -sin(t * PI) * 0.18
				k.box("toon", _t(xf, x, y + 0.02, 0), Vector3(0.19, 0.006, 0.006), DARK, 0.0)
				var lc := Color.from_hsv(fmod(i * 0.17, 1.0), 0.6, 1.0)
				k.sphere("emit", _t(xf, x, y - 0.015, 0), Vector3(0.022, 0.03, 0.022), lc * 1.6, 4, 6)
		"figure_shelf":
			k.box("toon", _t(xf, 0, 0, 0), Vector3(0.9, 0.03, 0.22), WOOD_LIGHT, 0.008)
			for i in 4:
				var fc := Color.from_hsv(rng.randf(), 0.6, 0.9)
				var x := -0.33 + i * 0.22
				k.capsule("toon", _t(xf, x, 0.08, 0), 0.035, 0.13, fc, 8)
				k.sphere("toon", _t(xf, x + 0.012, 0.11, 0.03), Vector3(0.012, 0.014, 0.008), WHITE, 3, 6)
				k.sphere("toon", _t(xf, x - 0.012, 0.11, 0.03), Vector3(0.012, 0.014, 0.008), WHITE, 3, 6)
		"arcade":
			var ac2: Color = p.get("color", Color.from_hsv(rng.randf(), 0.7, 0.75))
			k.box("toon", _t(xf, 0, 0.55, 0.05), Vector3(0.75, 1.1, 0.7), ac2, 0.03)
			k.box("toon", _tr(xf, Vector3(0, 1.3, -0.05), Vector3(-0.2, 0, 0)), Vector3(0.75, 0.6, 0.55), ac2, 0.03)
			k.plane("screen", _tr(xf, Vector3(0, 1.28, 0.24), Vector3(-0.2, 0, 0)), Vector2(0.56, 0.42), Color(1, 1, 1))
			k.box("emit", _t(xf, 0, 1.72, 0.18), Vector3(0.7, 0.14, 0.04), ac2.lightened(0.4) * 1.3, 0.01)
			k.box("toon", _t(xf, 0, 1.0, 0.38), Vector3(0.72, 0.08, 0.25), DARK, 0.02)
			for i in 4:
				k.cylinder("toon", _t(xf, -0.15 + i * 0.1, 1.05, 0.4), 0.025, 0.02, Color.from_hsv(i * 0.25, 0.8, 1.0), 8)
		"checkout":
			k.box("toon", _t(xf, 0, 0.5, 0), Vector3(2.6, 1.0, 0.8), Color(0.95, 0.4, 0.3), 0.04)
			k.box("toon", _t(xf, 0, 1.0, 0), Vector3(2.7, 0.05, 0.9), WHITE, 0.02)
			k.box("toon", _t(xf, 0.8, 1.15, 0), Vector3(0.4, 0.25, 0.35), DARK, 0.03)
			k.plane("screen", _tr(xf, Vector3(0.8, 1.35, 0.0), Vector3(-0.4, 0, 0)), Vector2(0.3, 0.2), Color(1, 1, 1))
			k.box("toon", _t(xf, -0.6, 1.08, 0.1), Vector3(0.3, 0.12, 0.2), Color(0.95, 0.85, 0.3), 0.02)
		"kiosk":
			var kc: Color = p.get("color", Color(0.3, 0.75, 0.95))
			k.box("toon", _t(xf, 0, 0.5, 0), Vector3(0.9, 1.0, 0.6), kc, 0.05)
			k.box("toon", _t(xf, 0, 1.3, -0.15), Vector3(0.85, 0.6, 0.12), DARK, 0.03)
			k.plane("screen", _t(xf, 0, 1.3, -0.088), Vector2(0.78, 0.52), Color(1, 1, 1))
			k.box("toon", _t(xf, 0, 1.03, 0.1), Vector3(0.3, 0.04, 0.15), DARK, 0.015)
			k.box("emit", _t(xf, 0, 1.68, -0.15), Vector3(0.85, 0.12, 0.1), kc.lightened(0.3), 0.02)
		"bargain_bin":
			var bb := Color(0.95, 0.3, 0.35)
			k.box("toon", _t(xf, 0, 0.05, 0), Vector3(1.4, 0.1, 0.9), bb.darkened(0.2), 0.02)
			for side in [[Vector3(0, 0.4, 0.44), Vector3(1.4, 0.7, 0.04)], [Vector3(0, 0.4, -0.44), Vector3(1.4, 0.7, 0.04)], [Vector3(0.68, 0.4, 0), Vector3(0.04, 0.7, 0.9)], [Vector3(-0.68, 0.4, 0), Vector3(0.04, 0.7, 0.9)]]:
				k.box("toon", _t(xf, side[0].x, side[0].y, side[0].z), side[1], bb, 0.015)
			k.box("toon", _t(xf, 0, 0.4, 0.465), Vector3(0.8, 0.25, 0.01), Color(1.0, 0.9, 0.2), 0.0)
		"trunk":
			var tc := Color(0.45, 0.28, 0.18)
			k.box("toon", _t(xf, 0, 0.27, 0), Vector3(1.0, 0.5, 0.55), tc, 0.03)
			k.box("toon", _t(xf, 0, 0.55, 0), Vector3(1.0, 0.12, 0.55), tc.lightened(0.1), 0.05)
			for sx in [-0.35, 0.35]:
				k.box("toon", _t(xf, sx, 0.3, 0), Vector3(0.06, 0.6, 0.57), Color(0.7, 0.6, 0.3), 0.01)
			k.box("toon", _t(xf, 0, 0.48, 0.28), Vector3(0.1, 0.1, 0.02), Color(0.85, 0.75, 0.35), 0.01)
		"old_tv":
			k.box("toon", _t(xf, 0, 0.28, 0), Vector3(0.6, 0.52, 0.55), Color(0.55, 0.45, 0.35), 0.06)
			k.plane("screen", _t(xf, -0.05, 0.3, 0.276), Vector2(0.4, 0.34), Color(1, 1, 1))
			k.cylinder("toon", _tr(xf, Vector3(0.23, 0.35, 0.28), Vector3(PI / 2, 0, 0)), 0.03, 0.02, DARK, 8)
			k.cylinder("toon", _tr(xf, Vector3(0.1, 0.65, 0), Vector3(0, 0, -0.5)), 0.005, 0.3, METAL, 4)
			k.cylinder("toon", _tr(xf, Vector3(-0.1, 0.65, 0), Vector3(0, 0, 0.5)), 0.005, 0.3, METAL, 4)
		"rocking_chair":
			k.box("toon", _t(xf, 0, 0.45, 0), Vector3(0.6, 0.05, 0.55), WOOD, 0.02)
			k.box("toon", _tr(xf, Vector3(0, 0.8, -0.3), Vector3(-0.15, 0, 0)), Vector3(0.6, 0.7, 0.05), WOOD, 0.02)
			for sx in [-0.28, 0.28]:
				k.torus("toon", _tr(xf, Vector3(sx, 0.75, 0), Vector3(0, PI / 2, PI / 2)), 0.75, 0.018, WOOD_DARK, 10, 5, 0.9)
				k.cylinder("toon", _t(xf, sx, 0.25, 0.2), 0.02, 0.4, WOOD_DARK, 5)
				k.cylinder("toon", _t(xf, sx, 0.25, -0.2), 0.02, 0.4, WOOD_DARK, 5)
		"dust_sheet":
			k.blob("toon", _t(xf, 0, 0.45, 0), Vector3(1.4, 0.95, 0.9), Color(0.9, 0.88, 0.82))
			k.box("toon", _t(xf, 0, 0.04, 0), Vector3(1.45, 0.08, 0.95), Color(0.88, 0.86, 0.8), 0.04)
		"workbench":
			k.box("toon", _t(xf, 0, 0.88, 0), Vector3(1.8, 0.06, 0.7), WOOD, 0.01)
			k.box("toon", _t(xf, 0, 0.25, 0), Vector3(1.7, 0.04, 0.6), WOOD_DARK, 0.01)
			for sx in [-0.85, 0.85]:
				for sz in [-0.3, 0.3]:
					k.box("toon", _t(xf, sx, 0.43, sz), Vector3(0.07, 0.86, 0.07), WOOD_DARK, 0.01)
			k.box("toon", _t(xf, 0, 1.3, -0.33), Vector3(1.7, 0.8, 0.03), Color(0.7, 0.6, 0.45), 0.0)
			for i in 6:
				k.box("toon", _t(xf, -0.7 + i * 0.28, 1.35, -0.3), Vector3(0.03, 0.25, 0.02), METAL.darkened(rng.randf() * 0.3), 0.005)
		"washer":
			k.box("toon", _t(xf, 0, 0.45, 0), Vector3(0.65, 0.9, 0.65), WHITE, 0.04)
			k.cylinder("glass", _tr(xf, Vector3(0, 0.45, 0.33), Vector3(PI / 2, 0, 0)), 0.2, 0.03, Color(0.6, 0.8, 0.95, 0.5), 18)
			k.torus("toon", _tr(xf, Vector3(0, 0.45, 0.33), Vector3(PI / 2, 0, 0)), 0.21, 0.025, METAL, 18, 6)
		"boiler":
			k.cylinder("toon", _t(xf, 0, 0.9, 0), 0.33, 1.7, WHITE.darkened(0.05), 16)
			k.cylinder("toon", _t(xf, 0.2, 1.9, 0), 0.04, 0.4, Color(0.75, 0.5, 0.3), 6)
			k.cylinder("toon", _t(xf, -0.2, 1.9, 0), 0.04, 0.4, Color(0.75, 0.5, 0.3), 6)
		"pallet":
			for i in 5:
				k.box("toon", _t(xf, 0, 0.13, -0.42 + i * 0.21), Vector3(1.2, 0.025, 0.14), WOOD_LIGHT, 0.005)
			for sx in [-0.5, 0, 0.5]:
				k.box("toon", _t(xf, sx, 0.06, 0), Vector3(0.1, 0.1, 1.0), WOOD, 0.005)
		"sort_table":
			k.box("toon", _t(xf, 0, 0.76, 0), Vector3(1.6, 0.04, 0.8), Color(0.98, 0.95, 0.85), 0.012)
			k.box("toon", _t(xf, 0, 0.785, 0), Vector3(1.56, 0.006, 0.76), Color(0.55, 0.8, 0.6), 0.0)
			for i in 7:
				k.box("toon", _t(xf, -0.78 + i * 0.26, 0.79, 0), Vector3(0.008, 0.004, 0.76), WHITE, 0.0)
			for j in 4:
				k.box("toon", _t(xf, 0, 0.79, -0.38 + j * 0.253), Vector3(1.56, 0.004, 0.008), WHITE, 0.0)
			for sx in [-0.74, 0.74]:
				for sz in [-0.34, 0.34]:
					k.cylinder("toon", _t(xf, sx, 0.37, sz), 0.03, 0.74, METAL, 6)
			k.box("toon", _t(xf, 0, 0.83, -0.42), Vector3(0.7, 0.1, 0.02), Color(0.98, 0.75, 0.25), 0.01)
		"radiator":
			for i in 8:
				k.box("toon", _t(xf, -0.4 + i * 0.115, 0.32, 0), Vector3(0.08, 0.55, 0.1), WHITE.darkened(0.05), 0.03)
		"laundry":
			for i in 5:
				k.blob("toon", _t(xf, rng.randf_range(-0.2, 0.2), 0.06 + i * 0.03, rng.randf_range(-0.15, 0.15)), Vector3(0.35, 0.1, 0.3), Color.from_hsv(rng.randf(), 0.5, 0.85))
		"guitar":
			var gc := Color.from_hsv(rng.randf(), 0.7, 0.85)
			k.blob("toon", _tr(xf, Vector3(0, 0.22, 0), Vector3(0, 0, 0)), Vector3(0.36, 0.42, 0.1), gc)
			k.blob("toon", _tr(xf, Vector3(0, 0.45, 0), Vector3(0, 0, 0)), Vector3(0.28, 0.28, 0.09), gc)
			k.box("toon", _t(xf, 0, 0.78, 0.0), Vector3(0.05, 0.5, 0.03), WOOD_DARK, 0.01)
			k.box("toon", _t(xf, 0, 1.03, 0.0), Vector3(0.08, 0.12, 0.03), DARK, 0.01)
		"skateboard":
			k.box("toon", _t(xf, 0, 0.08, 0), Vector3(0.8, 0.02, 0.21), c1, 0.03)
			for sx in [-0.28, 0.28]:
				for sz in [-0.08, 0.08]:
					k.cylinder("toon", _tr(xf, Vector3(sx, 0.03, sz), Vector3(PI / 2, 0, 0)), 0.03, 0.03, WHITE, 8)
		"ball":
			k.sphere("toon", _t(xf, 0, 0.12, 0), Vector3(0.12, 0.12, 0.12), c1, 8, 12)
			k.torus("toon", _tr(xf, Vector3(0, 0.12, 0), Vector3(PI / 2, 0, 0)), 0.12, 0.008, WHITE, 16, 4)
		"headphones":
			k.torus("toon", _tr(xf, Vector3(0, 0.1, 0), Vector3(PI / 2, 0, 0)), 0.09, 0.012, DARK, 12, 5, PI)
			k.cylinder("toon", _tr(xf, Vector3(0.09, 0.03, 0), Vector3(0, 0, PI / 2)), 0.045, 0.04, c1, 10)
			k.cylinder("toon", _tr(xf, Vector3(-0.09, 0.03, 0), Vector3(0, 0, PI / 2)), 0.045, 0.04, c1, 10)
		"controller":
			var cc3: Color = p.get("color", [WHITE, DARK, c1][rng.randi() % 3])
			k.box("toon", _t(xf, 0, 0.02, 0), Vector3(0.11, 0.035, 0.07), cc3, 0.015)
			k.sphere("toon", _t(xf, -0.06, 0.02, 0.015), Vector3(0.035, 0.02, 0.04), cc3, 4, 8)
			k.sphere("toon", _t(xf, 0.06, 0.02, 0.015), Vector3(0.035, 0.02, 0.04), cc3, 4, 8)
			k.cylinder("toon", _t(xf, -0.025, 0.042, 0), 0.01, 0.01, DARK.lightened(0.2), 6)
			k.cylinder("toon", _t(xf, 0.03, 0.042, -0.01), 0.008, 0.008, Color(0.9, 0.3, 0.3), 6)
		"books":
			var x := -0.18
			for i in 6:
				var bw := rng.randf_range(0.03, 0.06)
				var bh := rng.randf_range(0.18, 0.25)
				k.box("toon", _t(xf, x + bw * 0.5, bh * 0.5, 0), Vector3(bw, bh, 0.17), Color.from_hsv(rng.randf(), 0.5, 0.75), 0.004)
				x += bw + 0.003
		"ceiling_lamp":
			k.cylinder("toon", _t(xf, 0, 0.15, 0), 0.008, 0.3, DARK, 4)
			k.cylinder("emit", _t(xf, 0, -0.02, 0), 0.25, 0.16, Color(1.0, 0.9, 0.7), 16, 0.08)
		"panel_light":
			k.box("emit", _t(xf, 0, 0, 0), Vector3(1.2, 0.03, 0.6), Color(1.0, 0.97, 0.9) * 1.2, 0.01)
			k.box("toon", _t(xf, 0, 0.02, 0), Vector3(1.26, 0.02, 0.66), WHITE, 0.005)
		"gondola":
			var gl: float = p.get("len", 2.4)
			var gcol: Color = p.get("color", Color(0.95, 0.95, 0.97))
			k.box("toon", _t(xf, 0, 0.05, 0), Vector3(gl, 0.1, 0.9), gcol.darkened(0.15), 0.02)
			k.box("toon", _t(xf, 0, 0.8, 0), Vector3(gl, 1.4, 0.06), gcol, 0.02)
			for i in 3:
				for sz in [-0.22, 0.22]:
					k.box("toon", _t(xf, 0, 0.45 + i * 0.4, sz), Vector3(gl - 0.04, 0.025, 0.42), gcol.darkened(0.05), 0.005)
			k.box("emit", _t(xf, 0, 1.55, 0), Vector3(gl * 0.6, 0.12, 0.08), p.get("sign", Color(0.98, 0.5, 0.3)), 0.02)
		"display_table":
			k.box("toon", _t(xf, 0, 0.78, 0), Vector3(1.6, 0.05, 1.0), p.get("color", Color(0.25, 0.6, 0.85)), 0.02)
			k.box("toon", _t(xf, 0, 0.38, 0), Vector3(1.4, 0.76, 0.8), p.get("color", Color(0.25, 0.6, 0.85)).darkened(0.2), 0.03)
		"neon_sign":
			k.box("toon", _t(xf, 0, 0, -0.02), Vector3(1.5, 0.5, 0.02), DARK, 0.01)
			var nc: Color = p.get("color", Color(1.0, 0.35, 0.7))
			k.box("emit", _t(xf, 0, 0.15, 0.0), Vector3(1.3, 0.03, 0.03), nc * 2.0, 0.01)
			k.box("emit", _t(xf, 0, -0.15, 0.0), Vector3(1.3, 0.03, 0.03), nc * 2.0, 0.01)
		"window_display":
			k.box("toon", _t(xf, 0, 0.25, 0), Vector3(2.0, 0.5, 0.8), Color(0.98, 0.9, 0.5), 0.03)
		"stairs":
			for i in 10:
				k.box("toon", _t(xf, 0, 0.13 + i * 0.26, -1.08 + i * 0.24), Vector3(1.0, 0.06, 0.26), WOOD, 0.01)
			k.box("toon", _t(xf, -0.52, 1.3, 0), Vector3(0.04, 2.6, 2.4), WOOD_DARK, 0.01)
		"fridge":
			k.box("toon", _t(xf, 0, 0.6, 0), Vector3(0.6, 1.2, 0.6), p.get("color", Color(0.6, 0.85, 0.85)), 0.06)
			k.box("toon", _t(xf, 0.22, 0.8, 0.31), Vector3(0.03, 0.3, 0.03), METAL, 0.01)
			k.box("toon", _t(xf, -0.1, 0.9, 0.305), Vector3(0.08, 0.08, 0.01), Color(1.0, 0.4, 0.4), 0.01)
			k.box("toon", _t(xf, 0.05, 0.7, 0.305), Vector3(0.06, 0.09, 0.01), Color(0.4, 0.6, 1.0), 0.01)
		"ironing_board":
			k.box("toon", _t(xf, 0, 0.88, 0), Vector3(1.3, 0.03, 0.38), Color(0.6, 0.8, 0.95), 0.08)
			k.box("toon", _tr(xf, Vector3(0, 0.44, 0), Vector3(0, 0, 0.5)), Vector3(0.03, 0.95, 0.03), METAL, 0.0)
			k.box("toon", _tr(xf, Vector3(0, 0.44, 0), Vector3(0, 0, -0.5)), Vector3(0.03, 0.95, 0.03), METAL, 0.0)
		"easel":
			k.box("toon", _tr(xf, Vector3(0, 0.75, 0.1), Vector3(-0.15, 0, 0)), Vector3(0.05, 1.5, 0.04), WOOD, 0.01)
			k.box("toon", _t(xf, 0, 1.05, 0.15), Vector3(0.55, 0.7, 0.03), WHITE, 0.01)
			k.box("toon", _t(xf, 0.1, 1.05, 0.168), Vector3(0.3, 0.3, 0.005), c1, 0.0)
		"clothes_rack":
			k.box("toon", _t(xf, 0, 1.55, 0), Vector3(1.2, 0.03, 0.03), METAL, 0.0)
			for sx in [-0.58, 0.58]:
				k.box("toon", _t(xf, sx, 0.78, 0), Vector3(0.03, 1.56, 0.03), METAL, 0.0)
				k.box("toon", _t(xf, sx, 0.02, 0), Vector3(0.05, 0.04, 0.5), METAL, 0.0)
			for i in 7:
				k.box("toon", _t(xf, -0.45 + i * 0.15, 1.15, 0), Vector3(0.1, 0.75, 0.4), Color.from_hsv(rng.randf(), 0.5, 0.85), 0.04)
		"suitcase":
			k.box("toon", _t(xf, 0, 0.12, 0), Vector3(0.7, 0.24, 0.45), p.get("color", Color(0.3, 0.5, 0.7)), 0.04)
			k.box("toon", _t(xf, 0, 0.12, 0.23), Vector3(0.2, 0.04, 0.04), DARK, 0.01)
		"globe":
			k.cylinder("toon", _t(xf, 0, 0.02, 0), 0.1, 0.04, WOOD_DARK, 10)
			k.cylinder("toon", _t(xf, 0, 0.12, 0), 0.01, 0.2, METAL, 4)
			k.sphere("toon", _t(xf, 0, 0.3, 0), Vector3(0.14, 0.14, 0.14), Color(0.35, 0.6, 0.9), 8, 12)
			k.sphere("toon", _t(xf, 0.04, 0.33, 0.07), Vector3(0.09, 0.08, 0.08), Color(0.4, 0.75, 0.4), 5, 8)
		"fan":
			k.cylinder("toon", _t(xf, 0, 0.02, 0), 0.2, 0.04, WHITE, 10)
			k.cylinder("toon", _t(xf, 0, 0.6, 0), 0.02, 1.1, WHITE, 6)
			k.torus("toon", _tr(xf, Vector3(0, 1.15, 0), Vector3(PI / 2, 0, 0)), 0.2, 0.012, WHITE, 16, 4)
			k.cylinder("toon", _tr(xf, Vector3(0, 1.15, 0), Vector3(PI / 2, 0, 0)), 0.06, 0.08, c1, 10)
		"cushion":
			k.blob("toon", _tr(xf, Vector3(0, 0.07, 0), Vector3(0, rng.randf() * PI, 0)), Vector3(0.45, 0.14, 0.45), c1)
		"trophy":
			var gold := Color(1.0, 0.8, 0.25)
			k.box("toon", _t(xf, 0, 0.03, 0), Vector3(0.1, 0.06, 0.1), WOOD_DARK, 0.01)
			k.cylinder("toon", _t(xf, 0, 0.1, 0), 0.015, 0.08, gold, 6)
			k.cylinder("toon", _t(xf, 0, 0.18, 0), 0.06, 0.1, gold, 10, 0.03)
		"cart_return":
			for i in 4:
				k.box("toon", _t(xf, -0.45 + i * 0.3, 0.5, 0), Vector3(0.04, 1.0, 0.04), Color(0.95, 0.4, 0.3), 0.01)
			k.box("toon", _t(xf, 0, 0.98, 0), Vector3(1.0, 0.04, 0.06), Color(0.95, 0.4, 0.3), 0.01)
		"shopping_basket":
			k.box("toon", _t(xf, 0, 0.12, 0), Vector3(0.45, 0.24, 0.32), Color(0.95, 0.35, 0.35), 0.02)
			k.box("toon", _t(xf, 0, 0.24, 0), Vector3(0.4, 0.01, 0.27), Color(0.4, 0.1, 0.1), 0.0)
		"mirror_frame":
			k.box("toon", _t(xf, 0, 0.95, 0), Vector3(0.9, 1.9, 0.06), p.get("color", Color(0.95, 0.75, 0.3)), 0.03)
		"rafter":
			var rl: float = p.get("len", 6.0)
			k.box("toon", _t(xf, 0, 0, 0), Vector3(rl, 0.2, 0.18), WOOD_DARK.lerp(WOOD, 0.3), 0.01)
		"fireplace":
			k.box("toon", _t(xf, 0, 0.6, 0), Vector3(1.6, 1.2, 0.5), Color(0.75, 0.45, 0.35), 0.02)
			k.box("toon", _t(xf, 0, 0.42, 0.06), Vector3(0.9, 0.7, 0.42), Color(0.15, 0.1, 0.1), 0.02)
			k.box("toon", _t(xf, 0, 1.22, 0.05), Vector3(1.8, 0.08, 0.6), WOOD_LIGHT, 0.02)
			for i in 3:
				k.box("toon", _tr(xf, Vector3(-0.2 + i * 0.2, 0.12, 0.1), Vector3(0, i * 0.7, 0.2)), Vector3(0.5, 0.08, 0.08), WOOD_DARK, 0.02)
			k.sphere("emit", _t(xf, 0, 0.25, 0.12), Vector3(0.3, 0.18, 0.12), Color(2.0, 0.9, 0.3), 5, 10)
		"crate_stack":
			for i in 2:
				k.box("toon", _t(xf, rng.randf_range(-0.03, 0.03), 0.22 + i * 0.45, 0, rng.randf() * 0.2), Vector3(0.6, 0.43, 0.6), Color(0.78, 0.6, 0.4).darkened(rng.randf() * 0.15), 0.015)
		"cobweb":
			for i in 5:
				k.box("toon", _tr(xf, Vector3(0, 0, 0), Vector3(0, 0, i * 0.35)), Vector3(0.7, 0.004, 0.004), Color(0.9, 0.9, 0.9), 0.0)
			for i in 3:
				k.torus("toon", _tr(xf, Vector3(-0.3, 0.3, 0), Vector3(PI / 2, 0, 0)), 0.1 + i * 0.1, 0.002, Color(0.9, 0.9, 0.9), 10, 3, PI * 0.5)
		"bulb":
			k.box("toon", _t(xf, 0, 0.25, 0), Vector3(0.008, 0.5, 0.008), DARK, 0.0)
			k.sphere("emit", _t(xf, 0, -0.02, 0), Vector3(0.05, 0.07, 0.05), Color(1.6, 1.3, 0.8), 5, 8)
		"pinball":
			var pc: Color = p.get("color", Color.from_hsv(rng.randf(), 0.7, 0.85))
			k.box("toon", _tr(xf, Vector3(0, 0.95, 0.1), Vector3(0.12, 0, 0)), Vector3(0.75, 0.2, 1.2), pc, 0.03)
			k.plane("screen", _tr(xf, Vector3(0, 1.06, 0.1), Vector3(-PI / 2 + 0.12, 0, 0)), Vector2(0.65, 1.1), Color(1, 1, 1))
			k.box("toon", _t(xf, 0, 1.45, -0.55), Vector3(0.75, 0.8, 0.12), pc.darkened(0.2), 0.03)
			k.box("emit", _t(xf, 0, 1.5, -0.48), Vector3(0.65, 0.6, 0.01), pc.lightened(0.4) * 1.3, 0.0)
			for sx in [-0.3, 0.3]:
				for sz in [-0.45, 0.6]:
					k.box("toon", _t(xf, sx, 0.42, sz), Vector3(0.06, 0.84, 0.06), DARK, 0.01)
		"door":
			var dcol: Color = p.get("color", Color(0.96, 0.94, 0.9))
			k.box("toon", _t(xf, 0, 1.05, -0.01), Vector3(1.05, 2.16, 0.04), dcol.darkened(0.12), 0.01)
			k.box("toon", _t(xf, 0, 1.02, 0.01), Vector3(0.9, 2.04, 0.05), dcol, 0.015)
			k.box("toon", _t(xf, 0, 1.45, 0.04), Vector3(0.6, 0.7, 0.01), dcol.darkened(0.05), 0.01)
			k.box("toon", _t(xf, 0, 0.6, 0.04), Vector3(0.6, 0.7, 0.01), dcol.darkened(0.05), 0.01)
			k.sphere("toon", _t(xf, 0.36, 1.0, 0.06), Vector3(0.035, 0.035, 0.035), Color(0.95, 0.8, 0.35), 4, 8)
		_:
			k.box("toon", _t(xf, 0, 0.15, 0), Vector3(0.3, 0.3, 0.3), c1, 0.03)
