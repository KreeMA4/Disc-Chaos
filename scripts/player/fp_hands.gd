class_name FPHands
extends Node3D
## Rounded first-person mitten hands with sway, idle breathing, holding & inspect poses.

var holding := false
var inspecting := false
var emote := ""            # emote being performed by THESE hands (same nodes as always; nothing is spawned)
var emote_t := 0.0
const EMOTE_LEN := 2.6     # keep in sync with BeanModel's emote length
var _open_t := 0.0         # open/close-case gesture, 1 -> 0
var _open_dir := 1.0
var _l: Node3D
var _r: Node3D
var _t := 0.0
var _punch := 0.0
var _glove := Color(1.0, 0.82, 0.3)
var _last_cam_basis := Basis()
var _sway := Vector2.ZERO

func _ready() -> void:
	_l = _make_hand(-1.0)
	_r = _make_hand(1.0)

func set_glove(c: Color) -> void:
	_glove = c
	if _l:
		_l.queue_free()
		_r.queue_free()
		_l = _make_hand(-1.0)
		_r = _make_hand(1.0)

func _make_hand(side: float) -> Node3D:
	var n := Node3D.new()
	var k := MeshKit.new()
	k.ao_enabled = false
	k.sphere("toon", Transform3D(Basis(), Vector3.ZERO), Vector3(0.055, 0.048, 0.07), _glove, 6, 12)
	k.sphere("toon", Transform3D(Basis(), Vector3(-side * 0.04, 0.012, -0.02)), Vector3(0.022, 0.02, 0.03), _glove.darkened(0.06), 4, 8)
	k.cylinder("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.005, 0.07)), 0.045, 0.05, _glove.darkened(0.12), 12)
	var arm_col = Profile.look.get("color", Color(0.3, 0.8, 0.7))
	k.capsule("toon", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.005, 0.13)), 0.034, 0.12, arm_col if arm_col is Color else Color(0.3, 0.8, 0.7), 10)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build_mesh("toon")
	mi.material_override = WorldBuilder.mat("toon")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	add_child(n)
	return n

func punch() -> void:
	_punch = 1.0

## Same wire names as BeanModel.play_emote (which animates the body other players and mirrors see).
func play_emote(e: String) -> void:
	if e in ["wave", "dance", "point", "facepalm", "cheer", "shrug"]:
		emote = e
		emote_t = 0.0

func is_emoting() -> bool:
	return emote != ""

## Both hands spread/close together while a case is opened or closed.
func open_close(opening: bool) -> void:
	_open_t = 1.0
	_open_dir = 1.0 if opening else -1.0

## Pose of one hand for the current emote: [position, rotation(euler)] or [] to keep the normal pose.
## Camera-local space; the forearm trails behind the hand along +z, so raising a hand pitches it (rx > 0).
func _emote_pose(side: float, t: float) -> Array:
	var right := side > 0.0
	match emote:
		"wave":
			if right:
				return [Vector3(0.30, 0.0, -0.5), Vector3(0.9, -0.3, -0.2 + sin(t * 12.0) * 0.45)]
		"cheer":
			var bob := absf(sin(t * 9.0)) * 0.07
			return [Vector3(side * 0.30, 0.08 + bob, -0.5), Vector3(1.0, -side * 0.25, -side * 0.3)]
		"dance":
			var ph := t * 10.0 + (1.5 if right else 0.0)
			return [Vector3(side * 0.32, -0.02 + sin(ph) * 0.11, -0.5), Vector3(0.9, -side * 0.25, -side * (0.3 + sin(ph) * 0.3))]
		"point":
			if right:
				return [Vector3(0.12, -0.10, -0.80), Vector3(0.05, 0.0, 0.0)]
		"facepalm":
			if right:
				return [Vector3(0.03, 0.0, -0.30), Vector3(0.5, 0.2, 0.3)]
		"shrug":
			var sh := sin(t * 6.0) * 0.03
			return [Vector3(side * 0.36, -0.10 + sh, -0.45), Vector3(0.6, -side * 0.5, -side * 0.5)]
	return []

func _process(delta: float) -> void:
	_t += delta
	_punch = maxf(0.0, _punch - delta * 5.0)
	var cam := get_parent() as Node3D
	if cam:
		var b := cam.global_transform.basis
		var d := (_last_cam_basis.inverse() * b).get_euler()
		_last_cam_basis = b
		_sway = _sway.lerp(Vector2(clampf(d.y * 3.0, -0.06, 0.06), clampf(d.x * 3.0, -0.06, 0.06)), clampf(delta * 10.0, 0, 1))
	var breathe := sin(_t * 1.8) * 0.006
	var pl := Vector3(-0.26, -0.27 + breathe, -0.42)
	var pr := Vector3(0.26, -0.27 + breathe, -0.42)
	var rl := Vector3(0.2, 0.3, 0.3)
	var rr := Vector3(0.2, -0.3, -0.3)
	# Holding: the hands are brought together at the item's sides. The forearms trail back along local
	# +z towards the shoulders, which are WIDER apart than the hands, so each forearm must slant
	# outward (left: yaw < 0, right: yaw > 0). The previous poses slanted them inward, which made the
	# arms cross over each other. The fingers point inward (palms facing the item), roll keeps thumbs up.
	if holding:
		pl = Vector3(-0.13, -0.24 + breathe, -0.46)
		pr = Vector3(0.13, -0.24 + breathe, -0.46)
		rl = Vector3(0.1, -0.55, 1.2)
		rr = Vector3(0.1, 0.55, -1.2)
	if inspecting:
		pl = Vector3(-0.21, -0.24, -0.36)
		pr = Vector3(0.21, -0.24, -0.36)
		rl = Vector3(0.3, -0.25, 0.6)
		rr = Vector3(0.3, 0.25, -0.6)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - delta * 3.5)
		var k := sin(_open_t * PI)
		var spread := 0.07 * k * _open_dir
		pl.x -= spread
		pr.x += spread
		pl.y += 0.03 * k
		pr.y += 0.03 * k
		rl.y += 0.35 * k * _open_dir
		rr.y -= 0.35 * k * _open_dir
	pr.z -= _punch * 0.12
	pr.y += _punch * 0.04
	if emote != "":
		emote_t += delta
		var lp: Array = _emote_pose(-1.0, emote_t)
		var rp: Array = _emote_pose(1.0, emote_t)
		if not lp.is_empty():
			pl = lp[0]
			rl = lp[1]
		if not rp.is_empty():
			pr = rp[0]
			rr = rp[1]
		if emote_t > EMOTE_LEN:
			emote = ""
	var off := Vector3(-_sway.x, _sway.y, 0)
	_l.position = _l.position.lerp(pl + off, clampf(delta * 14.0, 0, 1))
	_r.position = _r.position.lerp(pr + off, clampf(delta * 14.0, 0, 1))
	_l.rotation = _l.rotation.lerp(rl, clampf(delta * 10.0, 0, 1))
	_r.rotation = _r.rotation.lerp(rr, clampf(delta * 10.0, 0, 1))
