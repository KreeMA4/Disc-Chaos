class_name CartNode
extends Node3D
## Push cart / store trolley. Visual + kinematic collider; the transform comes from LevelState
## (the item's xf), smoothed for remote viewers. Contents are drawn by ItemWorld.

var uid := -1
var body: AnimatableBody3D

func _ready() -> void:
	var k := MeshKit.new()
	var red := Color(0.95, 0.35, 0.32)
	var metal := Color(0.75, 0.78, 0.84)
	k.box("toon", Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.66, 0.04, 0.95), metal, 0.01)
	for sx in [-0.31, 0.31]:
		k.box("toon", Transform3D(Basis(), Vector3(sx, 0.72, 0)), Vector3(0.025, 0.5, 0.95), metal, 0.005)
		for i in 6:
			k.box("toon", Transform3D(Basis(), Vector3(sx, 0.72, -0.45 + i * 0.18)), Vector3(0.03, 0.5, 0.012), metal.darkened(0.1), 0.0)
	for sz in [-0.47, 0.47]:
		k.box("toon", Transform3D(Basis(), Vector3(0, 0.72, sz)), Vector3(0.66, 0.5, 0.025), metal, 0.005)
	k.box("toon", Transform3D(Basis(), Vector3(0, 0.97, 0)), Vector3(0.68, 0.035, 0.97), red, 0.012)
	k.cylinder("toon", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 1.08, 0.62)), 0.025, 0.7, red, 10)
	for sx in [-0.28, 0.28]:
		k.box("toon", Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(sx, 1.02, 0.55)), Vector3(0.025, 0.18, 0.025), metal, 0.0)
		for sz in [-0.4, 0.4]:
			k.box("toon", Transform3D(Basis(), Vector3(sx, 0.24, sz)), Vector3(0.025, 0.42, 0.025), metal, 0.0)
			k.cylinder("toon", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0.05, sz)), 0.05, 0.04, Color(0.2, 0.2, 0.24), 10)
	k.box("toon", Transform3D(Basis(), Vector3(0, 0.7, -0.485)), Vector3(0.4, 0.14, 0.01), Color(1.0, 0.85, 0.3), 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build_mesh("toon")
	mi.material_override = WorldBuilder.mat("toon")
	add_child(mi)
	body = AnimatableBody3D.new()
	body.collision_layer = Defs.LAYER_CART
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.68, 1.0, 1.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	add_child(body)

func _process(delta: float) -> void:
	if Game.st == null or uid < 0:
		return
	var it: LevelState.Item = Game.st.items[uid]
	var k := 1.0 if it.holder == Game.me() else clampf(delta * 12.0, 0.0, 1.0)
	global_transform = global_transform.interpolate_with(it.xf, k)
