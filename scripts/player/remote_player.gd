class_name RemotePlayer
extends Node3D
## Another player's bean, interpolated from their state packets. Has a kinematic collider so
## players can bump into each other, shows held items, flashlight, slips and chat bubbles.

var peer_id := 0
var bean: BeanModel
var body: AnimatableBody3D
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _vel := Vector3.ZERO
var _flags := 0
var _has_state := false
var _held_vis: Node3D
var _held_sig := ""
var _bubble: Label3D
var _bubble_t := 0.0
var _light: SpotLight3D

func _ready() -> void:
	bean = BeanModel.new()
	add_child(bean)
	body = AnimatableBody3D.new()
	body.collision_layer = Defs.LAYER_PLAYER
	body.collision_mask = 0
	body.sync_to_physics = false
	body.set_meta("peer_id", peer_id)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.66, 0)
	body.add_child(cs)
	add_child(body)
	_bubble = Label3D.new()
	_bubble.font = Covers.fonts.get("lilita-one")
	_bubble.font_size = 40
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 10
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 1.95, 0)
	_bubble.modulate = Color(1, 1, 0.85)
	_bubble.visible = false
	add_child(_bubble)
	_light = SpotLight3D.new()
	_light.spot_range = 8.0
	_light.spot_angle = 30.0
	_light.light_energy = 1.8
	_light.position = Vector3(0, 1.15, -0.3)
	_light.visible = false
	add_child(_light)

func apply_look(l: Dictionary) -> void:
	if bean:
		bean.apply_look(l)

func net_update(pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_vel = vel
	_flags = flags
	if not _has_state:
		_has_state = true
		global_position = pos
		rotation.y = yaw

func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = 3.5
	bean.talk_t = 1.0

func _process(delta: float) -> void:
	var k := clampf(delta * 12.0, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos + _vel * 0.05, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	body.global_position = global_position
	var slipping := (_flags & 4) != 0
	bean.carrying = (_flags & 16) != 0
	bean.animate(delta, _vel, absf(_vel.y) < 0.5)
	if slipping:
		bean.wobble.rotation.z = lerpf(bean.wobble.rotation.z, 1.4, delta * 8.0)
	bean.scale = Vector3(1, 0.8, 1) if (_flags & 1) else Vector3.ONE
	_light.visible = (_flags & 8) != 0
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
	_update_held()

func _update_held() -> void:
	if Game.st == null or Game.world == null:
		return
	var h := Game.st.held_by(peer_id)
	var sig := str(h) + str(h.map(func(u): return Game.st.items[u].open))
	if sig == _held_sig:
		return
	_held_sig = sig
	if _held_vis:
		_held_vis.queue_free()
		_held_vis = null
	if h.is_empty():
		return
	_held_vis = Node3D.new()
	_held_vis.position = Vector3(0, 0.95, -0.45)
	bean.wobble.add_child(_held_vis)
	var y := 0.0
	for uid in h:
		if Game.st.items[uid].kind == Defs.K_CART:
			continue
		var v := Game.world.make_visual(uid)
		var it: LevelState.Item = Game.st.items[uid]
		var s := Game.st.size_of(it)
		v.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI) if h.size() > 1 else Basis(Vector3.UP, PI), Vector3(0, y, 0))
		y += (s.z if h.size() > 1 else 0.0) + 0.002
		_held_vis.add_child(v)
