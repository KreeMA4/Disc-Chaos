class_name ItemWorld
extends Node3D
## Renders and simulates items.
## - Static items (floor piles, shelves, tables, open containers) are drawn through chunked
##   MultiMeshes: one draw call per (chunk, mesh kind) thanks to atlas materials.
## - Items near a player become RigidBody3D on the host ("active"); clients show interpolated
##   puppets driven by host snapshots. Sleeping bodies far from players are frozen back into data.

signal body_hit(uid: int, speed: float)

const CHUNK := 6.0
const START_CAP := 32
var ACTIVATE_R := 2.1
var MAX_ACTIVE := 90

var st: LevelState
var is_host := true
var players: Array = []          # Array[Vector3] positions used for activation (host)
var _chunks := {}                # Vector2i -> {rkey -> MultiMeshInstance3D}
var _mm_uids := {}               # MultiMeshInstance3D -> Array[int]
var _slot := {}                  # uid -> [mmi, index]
var _dirty := {}
var _anim := {}                  # uid -> {from: Transform3D, t: float}
var bodies := {}                 # uid -> RigidBody3D (host)
var puppets := {}                # uid -> {node: Node3D, target: Transform3D}
var _act_timer := 0.0
var _shadows := true
var _vis_range := 40.0
var _phys_mat: PhysicsMaterial

func setup(state: LevelState, host: bool) -> void:
	st = state
	is_host = host
	st.item_changed.connect(_on_changed)
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.75
	_phys_mat.bounce = 0.12
	var pd := Settings.preset()
	_shadows = pd.shadows and int(Settings.get_value("preset")) >= 2
	_vis_range = 38.0 * float(pd.vis_mult)
	for it in st.items:
		_dirty[it.uid] = true
	_flush()

func _on_changed(uid: int) -> void:
	_dirty[uid] = true

## Animate an item from its previous transform to the new one (shelf slides, snaps).
func animate_from(uid: int, from_xf: Transform3D, dur := 0.18) -> void:
	_anim[uid] = {"from": from_xf, "t": 0.0, "dur": dur}
	_dirty[uid] = true

func _process(delta: float) -> void:
	for uid in _anim.keys():
		var a: Dictionary = _anim[uid]
		a.t += delta
		_dirty[uid] = true
	_flush()
	for uid in _anim.keys():
		if _anim[uid].t >= _anim[uid].dur:
			_anim.erase(uid)
	# client puppets follow host snapshots smoothly
	var k := clampf(delta * 14.0, 0.0, 1.0)
	for uid in puppets:
		var p: Dictionary = puppets[uid]
		var n: Node3D = p.node
		n.global_transform = n.global_transform.interpolate_with(p.target, k)

func _physics_process(delta: float) -> void:
	if not is_host or st == null:
		return
	for uid in bodies:
		var b: RigidBody3D = bodies[uid]
		if not b.sleeping:
			st.op_move(uid, b.global_transform)
			if b.global_position.y < -3.0:
				_rescue(uid, b)
	_act_timer -= delta
	if _act_timer <= 0.0:
		_act_timer = 0.2
		_update_activation()

func _rescue(uid: int, b: RigidBody3D) -> void:
	var p: Vector3 = players[0] if not players.is_empty() else Vector3(0, 1, 0)
	b.global_position = p + Vector3(0, 1.0, 0.5)
	b.linear_velocity = Vector3.ZERO

# ------------------------------------------------------------------ static rendering
func _flush() -> void:
	if _dirty.is_empty():
		return
	var keys := _dirty.keys()
	_dirty.clear()
	for uid in keys:
		_refresh(uid)

func _wants_static(uid: int) -> bool:
	var it: LevelState.Item = st.items[uid]
	if it.kind == Defs.K_CART or it.active or not st.is_visible(uid):
		return false
	var r := st.root_of(uid)
	if r != uid:
		var ri: LevelState.Item = st.items[r]
		if ri.active or ri.holder != 0 or ri.kind == Defs.K_CART and false:
			return false
	return true

func _refresh(uid: int) -> void:
	var it: LevelState.Item = st.items[uid]
	if _wants_static(uid):
		var xf := st.world_xf(uid)
		if _anim.has(uid):
			var a: Dictionary = _anim[uid]
			var t := clampf(a.t / a.dur, 0.0, 1.0)
			t = 1.0 - pow(1.0 - t, 3.0)
			xf = (a.from as Transform3D).interpolate_with(xf, t)
		var key := ItemMeshes.render_key(it)
		var chunk := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
		var mmi := _get_mmi(chunk, key, it.kind)
		if _slot.has(uid) and _slot[uid][0] != mmi:
			_remove(uid)
		if not _slot.has(uid):
			_add(uid, mmi)
		var idx: int = _slot[uid][1]
		mmi.multimesh.set_instance_transform(idx, xf)
		mmi.multimesh.set_instance_custom_data(idx, Covers.item_custom(st, it))
		mmi.multimesh.set_instance_color(idx, Covers.item_plastic(st, it))
	else:
		_remove(uid)
	for c in it.contents:
		_refresh(c)

func _get_mmi(chunk: Vector2i, key: String, kind: int) -> MultiMeshInstance3D:
	if not _chunks.has(chunk):
		_chunks[chunk] = {}
	var d: Dictionary = _chunks[chunk]
	if d.has(key):
		return d[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = ItemMeshes.mesh(key)
	mm.instance_count = START_CAP
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Covers.mm_mats[Covers.mode_for(kind)]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows and kind != Defs.K_DISC else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = _vis_range
	mmi.visibility_range_end_margin = 2.0
	mmi.name = "MM_%d_%d_%s" % [chunk.x, chunk.y, key]
	add_child(mmi)
	d[key] = mmi
	_mm_uids[mmi] = []
	return mmi

func _add(uid: int, mmi: MultiMeshInstance3D) -> void:
	var arr: Array = _mm_uids[mmi]
	var mm := mmi.multimesh
	if arr.size() >= mm.instance_count:
		# grow: instance_count resets the buffer, so re-upload everything
		var xfs: Array = []
		var cds: Array = []
		var cols: Array = []
		for i in arr.size():
			xfs.append(mm.get_instance_transform(i))
			cds.append(mm.get_instance_custom_data(i))
			cols.append(mm.get_instance_color(i))
		mm.instance_count = mm.instance_count * 2
		for i in arr.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_custom_data(i, cds[i])
			mm.set_instance_color(i, cols[i])
	arr.append(uid)
	_slot[uid] = [mmi, arr.size() - 1]
	mm.visible_instance_count = arr.size()

func _remove(uid: int) -> void:
	if not _slot.has(uid):
		return
	var mmi: MultiMeshInstance3D = _slot[uid][0]
	var idx: int = _slot[uid][1]
	var arr: Array = _mm_uids[mmi]
	var mm := mmi.multimesh
	var last := arr.size() - 1
	if idx != last:
		var moved: int = arr[last]
		arr[idx] = moved
		mm.set_instance_transform(idx, mm.get_instance_transform(last))
		mm.set_instance_custom_data(idx, mm.get_instance_custom_data(last))
		mm.set_instance_color(idx, mm.get_instance_color(last))
		_slot[moved] = [mmi, idx]
	arr.pop_back()
	mm.visible_instance_count = arr.size()
	_slot.erase(uid)

func static_instance_count() -> int:
	return _slot.size()

func multimesh_count() -> int:
	var n := 0
	for m in _mm_uids:
		if (_mm_uids[m] as Array).size() > 0:
			n += 1
	return n

# ------------------------------------------------------------------ item visuals (bodies/puppets/held)
## Builds a node tree of MeshInstances for an item and its visible contents (single material).
func make_visual(uid: int, hires := false) -> Node3D:
	var root := Node3D.new()
	_add_visual_mesh(root, uid, Transform3D(), hires)
	return root

func _add_visual_mesh(parent: Node3D, uid: int, local: Transform3D, hires: bool) -> void:
	var it: LevelState.Item = st.items[uid]
	if it.kind == Defs.K_CART:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = ItemMeshes.mesh(ItemMeshes.render_key(it))
	mi.transform = local
	if hires:
		mi.material_override = HiresMaterials.for_item(st, it)
	else:
		mi.material_override = Covers.single_mats[Covers.mode_for(it.kind)]
		mi.set_instance_shader_parameter("inst_custom", Covers.item_custom(st, it))
		mi.set_instance_shader_parameter("inst_color", Covers.item_plastic(st, it))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if it.open or it.kind == Defs.K_CART:
		for c in it.contents:
			_add_visual_mesh(parent, c, local * st.items[c].xf, hires)

# ------------------------------------------------------------------ host physics
func activate(uid: int, xf: Transform3D, vel := Vector3.ZERO, ang := Vector3.ZERO) -> void:
	var it: LevelState.Item = st.items[uid]
	if bodies.has(uid) or puppets.has(uid):
		_deactivate_node(uid)
	it.active = true
	if is_host:
		var b := RigidBody3D.new()
		b.collision_layer = Defs.LAYER_ITEM
		b.collision_mask = Defs.LAYER_WORLD | Defs.LAYER_ITEM | Defs.LAYER_CART
		b.physics_material_override = _phys_mat
		b.mass = _mass_of(it)
		b.continuous_cd = it.kind == Defs.K_DISC or vel.length() > 3.0
		b.can_sleep = true
		b.contact_monitor = true
		b.max_contacts_reported = 1
		b.linear_damp = 0.05
		b.angular_damp = 0.6
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var box := st.local_aabb(it)
		shape.size = ItemMeshes.collision_size(st, it)
		cs.shape = shape
		cs.position = box.get_center()
		b.add_child(cs)
		b.add_child(make_visual(uid))
		add_child(b)
		b.global_transform = xf
		b.linear_velocity = vel
		b.angular_velocity = ang
		b.body_entered.connect(func(_other): body_hit.emit(uid, b.linear_velocity.length()))
		bodies[uid] = b
	else:
		var n := make_visual(uid)
		add_child(n)
		n.global_transform = xf
		puppets[uid] = {"node": n, "target": xf}
	_dirty[uid] = true

func deactivate(uid: int) -> void:
	var it: LevelState.Item = st.items[uid]
	_deactivate_node(uid)
	it.active = false
	_dirty[uid] = true

func _deactivate_node(uid: int) -> void:
	if bodies.has(uid):
		var b: RigidBody3D = bodies[uid]
		st.op_move(uid, b.global_transform)
		b.queue_free()
		bodies.erase(uid)
	if puppets.has(uid):
		puppets[uid].node.queue_free()
		puppets.erase(uid)

## Rebuild the visual of an active item (e.g. opened/closed while on the floor).
func refresh_visual(uid: int) -> void:
	var node: Node3D = null
	if bodies.has(uid):
		node = bodies[uid]
	elif puppets.has(uid):
		node = puppets[uid].node
	if node == null:
		return
	for c in node.get_children():
		if not (c is CollisionShape3D):
			c.queue_free()
	node.add_child(make_visual(uid))
	if node is RigidBody3D:
		var it: LevelState.Item = st.items[uid]
		for c in node.get_children():
			if c is CollisionShape3D:
				(c.shape as BoxShape3D).size = ItemMeshes.collision_size(st, it)
				c.position = st.local_aabb(it).get_center()
		(node as RigidBody3D).sleeping = false

func _mass_of(it: LevelState.Item) -> float:
	match it.kind:
		Defs.K_DISC: return 0.03
		Defs.K_CEBOX: return 1.2
		Defs.K_FIGURE: return 0.25
		Defs.K_ARTBOOK: return 0.6
	if it.fmt == Defs.F_BIGBOX:
		return 0.6
	return 0.15

func _update_activation() -> void:
	if players.is_empty():
		return
	var want := {}
	for p in players:
		for uid in st.query_box(p, ACTIVATE_R):
			var it: LevelState.Item = st.items[uid]
			if it.parent >= 0 or it.bucket >= 0 or it.table >= 0 or it.holder != 0 or it.stash >= 0:
				continue
			var d = (it.xf.origin - p).length()
			if d < ACTIVATE_R:
				want[uid] = minf(want.get(uid, 99.0), d)
	# deactivate sleeping bodies out of range
	for uid in bodies.keys():
		var b: RigidBody3D = bodies[uid]
		if (b.sleeping or b.linear_velocity.length() < 0.02) and not want.has(uid):
			var far := true
			for p in players:
				if b.global_position.distance_to(p) < ACTIVATE_R + 1.0:
					far = false
			if far:
				Game.on_item_rest(uid, b.global_transform)
				deactivate(uid)
	if bodies.size() >= MAX_ACTIVE:
		return
	var cand := want.keys()
	cand.sort_custom(func(a, b): return want[a] < want[b])
	for uid in cand:
		if bodies.size() >= MAX_ACTIVE:
			break
		if bodies.has(uid):
			continue
		var it: LevelState.Item = st.items[uid]
		activate(uid, it.xf)
		bodies[uid].sleeping = true
		Game.on_item_activated(uid, it.xf)

func active_count() -> int:
	return bodies.size() + puppets.size()

## Kick loose items around a moving player's feet (comedic scatter).
func kick_near(pos: Vector3, vel: Vector3) -> int:
	var hits := 0
	var hv := Vector3(vel.x, 0, vel.z)
	if hv.length() < 1.2:
		return 0
	for uid in bodies:
		var b: RigidBody3D = bodies[uid]
		var d := b.global_position - pos
		if absf(d.y) < 0.5 and Vector2(d.x, d.z).length() < 0.42:
			b.apply_central_impulse((hv * 0.35 + Vector3(0, 0.6, 0)) * b.mass)
			b.apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.002)
			if st.items[uid].kind == Defs.K_DISC:
				hits += 1
	return hits

# ------------------------------------------------------------------ snapshots (host -> clients)
func pack_snapshot() -> Array:
	var uids := PackedInt32Array()
	var data := PackedFloat32Array()
	for uid in bodies:
		var b: RigidBody3D = bodies[uid]
		if b.sleeping:
			continue
		var xf := b.global_transform
		var q := xf.basis.get_rotation_quaternion()
		uids.append(uid)
		data.append_array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w])
	return [uids, data]

func apply_snapshot(uids: PackedInt32Array, data: PackedFloat32Array) -> void:
	for i in uids.size():
		var uid := uids[i]
		var o := i * 7
		var xf := Transform3D(Basis(Quaternion(data[o + 3], data[o + 4], data[o + 5], data[o + 6])), Vector3(data[o], data[o + 1], data[o + 2]))
		if not puppets.has(uid):
			if st.items[uid].holder != 0 or st.items[uid].parent >= 0 or st.items[uid].bucket >= 0:
				continue
			activate(uid, xf)
		puppets[uid].target = xf
		st.op_move(uid, xf)

func clear_all() -> void:
	for uid in bodies.keys() + puppets.keys():
		_deactivate_node(uid)
