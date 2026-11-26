extends Node
## M1 / audit A1: aiming at items that sit inside containers (carts, open cases, open boxes).
## Before the fix the container's bounding box was always entered first, so the container
## "shadowed" its contents: items put in a cart could never be picked up again.
var runner

func run() -> void:
	_raycast_unit()
	await _aim_through_player()

func _hit(st: LevelState, from: Vector3, dir: Vector3, dist := 3.0) -> int:
	return int(st.raycast(from, dir, dist, 0.03).get("uid", -1))

func _raycast_unit() -> void:
	var r := TestUtil.fresh(5)
	var st: LevelState = r[2]
	# --- open flip case lying on the floor with its disc
	var case_uid := -1
	for p in st.products:
		var root: LevelState.Item = st.items[p.root]
		if root.kind == Defs.K_CASE and root.fmt == Defs.F_MODERN and p.edition == Defs.E_STANDARD and (p.discs as Array).size() == 1:
			case_uid = root.uid
			break
	var prod: Dictionary = st.products[st.items[case_uid].product]
	var disc: int = prod.discs[0]
	st.op_release(case_uid, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(3, 0.012, 3)))
	st.op_set_open(case_uid, true)
	if st.items[disc].parent != case_uid:
		st.op_grab(disc, 9)
		st.op_insert(disc, case_uid)
	var dpos := st.world_xf(disc).origin
	runner.check(_hit(st, dpos + Vector3(0, 1.0, 0), Vector3.DOWN) == disc, "A1: disc inside an open case on the floor is aimable")
	# aiming at the flipped-open front panel (no disc there) still targets the case itself
	var panel := st.world_xf(case_uid) * Vector3(-0.2, 0, 0)
	runner.check(_hit(st, panel + Vector3(0, 1.0, 0), Vector3.DOWN) == case_uid, "A1: open case panel (no disc) still targets the case")
	# --- cart with cargo, from above and from the side
	var cart := -1
	for it in st.items:
		if it.kind == Defs.K_CART:
			cart = it.uid
			break
	var cargo := TestUtil.free_cases(st, 4)
	for c in cargo:
		st.op_grab(c, 9)
		st.op_insert(c, cart)
	var seen := 0
	for c in cargo:
		var cp := st.world_xf(c).origin
		var top := _hit(st, cp + Vector3(0, 1.2, 0), Vector3.DOWN)
		var side_dir: Vector3 = -(st.items[cart].xf.basis.x)
		var side := _hit(st, cp - side_dir * 1.2, side_dir)
		if top == c:
			seen += 1
		runner.check(top == c, "A1: cart cargo item %d aimable from above (got %d)" % [c, top])
		runner.check(side == cart or cargo.has(side), "A1: cart cargo item %d from the side hits cargo or cart, never something else (got %d)" % [c, side])
	var cart_pos: Vector3 = st.items[cart].xf.origin
	var frame_hit := _hit(st, cart_pos + Vector3(0.0, 0.8, 1.6), Vector3(0, 0, -1))
	runner.check(frame_hit == cart, "A1: a ray that misses every cargo item still targets the cart (got %d)" % frame_hit)
	# taking the targeted item out really works through the same path the player uses
	var picked := _hit(st, st.world_xf(cargo[0]).origin + Vector3(0, 1.2, 0), Vector3.DOWN)
	runner.check(st.op_grab(picked, 7) and st.items[picked].parent < 0, "A1: item aimed in a cart can be grabbed out of it")
	# --- open collector's box: pieces and the inner case
	for p in st.products:
		if p.edition != Defs.E_CE:
			continue
		var box: LevelState.Item = st.items[p.root]
		st.op_release(box.uid, Transform3D(Basis(), Vector3(6, 0.08, 6)))
		st.op_set_open(box.uid, true)
		var piece: int = p.pieces[0]
		if st.items[piece].parent != box.uid:
			st.op_grab(piece, 9)
			st.op_insert(piece, box.uid)
		var pp := st.world_xf(piece).origin
		runner.check(_hit(st, pp + Vector3(0, 1.0, 0), Vector3.DOWN) == piece, "A1: piece inside an open collector's box is aimable")
		# nested: a disc inside the inner case inside the open box
		var inner: int = p.disc_box
		if st.items[inner].parent != box.uid:
			st.op_grab(inner, 9)
			st.op_insert(inner, box.uid)
		st.op_set_open(inner, true)
		var d0: int = p.discs[0]
		if st.items[d0].parent != inner:
			st.op_grab(d0, 9)
			st.op_insert(d0, inner)
		var dp := st.world_xf(d0).origin
		runner.check(_hit(st, dp + Vector3(0, 1.0, 0), Vector3.DOWN) == d0, "A1: disc in a case in an open box: deepest item wins")
		break
	# --- unchanged behaviour for non-nested items
	var loose := TestUtil.free_cases(st, 2)
	var a: int = loose[0]
	var b: int = loose[1]
	st.op_release(a, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(9, 0.012, 9)))
	st.op_release(b, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(9, 0.04, 9)))   # lying on top of a
	runner.check(_hit(st, Vector3(9, 1.5, 9), Vector3.DOWN) == b, "A1 unchanged: two overlapping closed cases -> nearest one")
	runner.check(_hit(st, Vector3(9, 0.5, 9), Vector3.DOWN, 0.2) == -1, "A1 unchanged: max distance respected")
	var shelved := -1
	for it in st.items:
		if it.bucket >= 0:
			shelved = it.uid
			break
	runner.check(shelved >= 0, "A1 unchanged: the generated level has shelved items to test")
	if shelved >= 0:
		var bxf: Transform3D = st.buckets[st.items[shelved].bucket].xf
		var sp := st.world_xf(shelved).origin
		var front: Vector3 = bxf.basis.z
		runner.check(_hit(st, sp + front * 1.0, -front) == shelved, "A1 unchanged: a shelved case is targeted from the shelf front")
	var ex := st.raycast(Vector3(9, 1.5, 9), Vector3.DOWN, 3.0, 0.03, b)
	runner.check(int(ex.get("uid", -1)) == a, "A1 unchanged: 'exclude' skips the held item")

func _aim_through_player() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var st: LevelState = Game.st
	var p: Player = Game.local_player
	var cart: int = Game.carts.keys()[0]
	var cargo := TestUtil.free_cases(st, 3)
	for c in cargo:
		Game.request_grab(c)
		await TestUtil.frames(get_tree(), 1)
		Game.request_insert(c, cart)
		await TestUtil.frames(get_tree(), 1)
	runner.check(st.items[cargo[0]].parent == cart, "A1 (engine): cargo is in the cart")
	var cpos: Vector3 = st.items[cart].xf.origin
	var cart_before: Transform3D = st.items[cart].xf
	p.global_position = Vector3(cpos.x, 0.05, cpos.z + 1.7)
	await TestUtil.frames(get_tree(), 40)   # > 2 activation ticks (0.2 s each at 60 Hz = 12 frames)
	runner.check(st.items[cart].xf.is_equal_approx(cart_before) and not Game.world.bodies.has(cart), "A5: a loose cart next to the player stays put (never activated as a rigid body)")
	var ok := 0
	for c in cargo:
		TestUtil.aim_at(p, st.world_xf(c).origin)
		await TestUtil.frames(get_tree(), 2)
		var tgt: Dictionary = p.target
		# a neighbouring cargo item may legitimately be nearer along the ray
		if tgt.get("type", "") == "item" and st.items[tgt.uid].parent == cart:
			ok += 1
	runner.check(ok == cargo.size(), "A1 (engine): the Player's real targeting picks each cargo item (%d/%d)" % [ok, cargo.size()])
	TestUtil.aim_at(p, st.world_xf(cargo[0]).origin)
	await TestUtil.frames(get_tree(), 2)
	runner.check(String(p.context().get("grab", "")) == "Grab", "A1 (engine): the contextual button offers Grab for cargo")
	var aimed: int = int(p.target.get("uid", -1)) if p.target.get("type", "") == "item" else -1
	if aimed >= 0:
		Game.request_grab(aimed)
		await TestUtil.frames(get_tree(), 2)
	runner.check(aimed >= 0 and st.items[aimed].holder == Game.me() and st.items[aimed].parent < 0, "A1 (engine): aimed grab takes the item out of the cart")
	await TestUtil.shutdown(get_tree(), main)
