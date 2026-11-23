class_name FPHands
extends Node3D
## Rounded first-person mitten hands with sway, idle breathing, holding & inspect poses.

var holding := false
var inspecting := false
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
	if holding:
		pl = Vector3(-0.13, -0.24 + breathe, -0.46)
		pr = Vector3(0.13, -0.24 + breathe, -0.46)
		rl = Vector3(0.1, 0.9, 1.2)
		rr = Vector3(0.1, -0.9, -1.2)
	if inspecting:
		pl = Vector3(-0.21, -0.24, -0.36)
		pr = Vector3(0.21, -0.24, -0.36)
		rl = Vector3(0.3, 0.5, 0.6)
		rr = Vector3(0.3, -0.5, -0.6)
	pr.z -= _punch * 0.12
	pr.y += _punch * 0.04
	var off := Vector3(-_sway.x, _sway.y, 0)
	_l.position = _l.position.lerp(pl + off, clampf(delta * 14.0, 0, 1))
	_r.position = _r.position.lerp(pr + off, clampf(delta * 14.0, 0, 1))
	_l.rotation = _l.rotation.lerp(rl, clampf(delta * 10.0, 0, 1))
	_r.rotation = _r.rotation.lerp(rr, clampf(delta * 10.0, 0, 1))
