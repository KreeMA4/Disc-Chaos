extends Node
## M1 / audit A5: carts collide with the world, never end up tilted/in the air, and a slip while
## pushing keeps the cart on the floor.
var runner

func run() -> void:
	await _unit()
	await _push_into_wall()
	await _slip_and_release()
	await _no_room_grab()
	await _doorways()

## Puts the cart where a player standing at `pos` facing `yaw` would be holding it, then grabs it.
func _grab_here(p: Player, cart: int, pos: Vector3, yaw: float) -> bool:
	p.global_position = pos
	p.look_yaw = yaw
	p.rotation.y = yaw
	Game.st.op_cart_move(cart, CartPhysics.pose_for(pos, yaw))
	await TestUtil.frames(get_tree(), 3)
	p._request_grab(cart)
	await TestUtil.frames(get_tree(), 3)
	return Game.st.items[cart].holder == Game.me()

## An open floor position (cart footprint free all around, facing yaw 0) in the biggest room.
func _free_spot(space: PhysicsDirectSpaceState3D, L: LevelLayout) -> Vector3:
	var best := 0
	for i in L.rooms.size():
		if (L.rooms[i].rect as Rect2).get_area() > (L.rooms[best].rect as Rect2).get_area():
			best = i
	var r: Rect2 = L.rooms[best].rect
	var x := r.position.x + 1.5
	while x < r.end.x - 1.5:
		var z := r.position.y + 1.5
		while z < r.end.y - 1.5:
			var ok := true
			for dx in [-0.8, 0.0, 0.8]:
				for dz in [-1.2, 0.0, 1.2]:
					var pos := Vector3(x + dx, 0.05, z + dz)
					if CartPhysics.blocked(space, CartPhysics.pose_for(pos, 0.0)) or CartPhysics.blocked(space, Transform3D(Basis(), pos)):
						ok = false
			if ok:
				return Vector3(x, 0.05, z)
			z += 0.5
		x += 0.5
	return Vector3.ZERO

func _unit() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var space: PhysicsDirectSpaceState3D = Game.level_root.get_world_3d().direct_space_state
	var L: LevelLayout = Game.layout
	var wall_x: float = L.rooms[1].rect.position.x   # west wall of the store floor room
	var z := 15.0
	var open_xf := Transform3D(Basis(), Vector3(wall_x + 3.0, 0, z))
	var wall_xf := Transform3D(Basis(), Vector3(wall_x - 0.1, 0, z))
	runner.check(not CartPhysics.blocked(space, open_xf), "A5: a cart in open floor is not blocked")
	runner.check(CartPhysics.blocked(space, wall_xf), "A5: a cart overlapping the wall is blocked")
	runner.check(not CartPhysics.blocked(space, Transform3D(Basis(), Vector3(wall_x + 0.45, 0, z))), "A5: a cart touching the wall (not inside it) is allowed")
	# resolve: free target is taken as is
	var cur := open_xf
	var r1 := CartPhysics.resolve(space, cur, Transform3D(Basis(), Vector3(wall_x + 2.0, 0, z)))
	runner.check(r1.origin.is_equal_approx(Vector3(wall_x + 2.0, 0, z)), "A5: resolve takes a free target")
	# resolve: target in the wall -> slide along it (x blocked, z free)
	var r2 := CartPhysics.resolve(space, Transform3D(Basis(), Vector3(wall_x + 0.5, 0, z)), Transform3D(Basis(), Vector3(wall_x - 0.3, 0, z + 0.5)))
	runner.check(not CartPhysics.blocked(space, r2) and is_equal_approx(r2.origin.z, z + 0.5) and r2.origin.x > wall_x, "A5: resolve slides along the wall (got %s)" % str(r2.origin))
	# resolve: fully blocked target keeps the current pose
	var r3 := CartPhysics.resolve(space, Transform3D(Basis(), Vector3(wall_x + 0.5, 0, z)), Transform3D(Basis(), Vector3(wall_x - 0.3, 0, z)))
	runner.check(r3.origin.is_equal_approx(Vector3(wall_x + 0.5, 0, z)), "A5: resolve keeps the current pose when nothing is free")
	# grounded
	var tilted := Transform3D(Basis(Vector3.UP, 1.0) * Basis(Vector3.RIGHT, 0.4), Vector3(2, 1.04, 3))
	var g := CartPhysics.grounded(tilted)
	runner.check(is_equal_approx(g.origin.y, 0.0) and g.basis.y.is_equal_approx(Vector3.UP) and is_equal_approx(g.origin.x, 2.0), "A5: grounded() puts a cart upright on the floor")
	await TestUtil.shutdown(get_tree(), main)

func _push_into_wall() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var p: Player = Game.local_player
	var L: LevelLayout = Game.layout
	var cart: int = Game.carts.keys()[0]
	var wall_x: float = L.rooms[1].rect.position.x
	var held: bool = await _grab_here(p, cart, Vector3(wall_x + 1.8, 0.05, 15.0), PI * 0.5)   # facing -X, into the west wall
	runner.check(held, "A5: the player holds the cart")
	p.touch_move = Vector2(0, -1)
	await TestUtil.frames(get_tree(), 150)
	p.touch_move = Vector2.ZERO
	var cxf: Transform3D = Game.st.items[cart].xf
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	runner.check(not CartPhysics.blocked(space, cxf), "A5: after pushing into a wall the cart is not inside it (cart x=%.2f, wall x=%.2f)" % [cxf.origin.x, wall_x])
	runner.check(cxf.origin.x - 0.5 >= wall_x - 0.02, "A5: the cart's near end stays on the room side of the wall")
	runner.check(p.global_position.x > cxf.origin.x, "A5: the pusher stays behind the cart")
	runner.check(p.oob_recoveries == 0, "A5: no out-of-bounds recovery was needed")
	# slide: push diagonally along the wall; the cart must keep moving along it
	var z0: float = cxf.origin.z
	p.look_yaw = PI * 0.5 - 0.5   # facing mostly -X, a little towards +Z... (yaw<PI/2 turns towards -Z? see assert on movement either way)
	p.touch_move = Vector2(0, -1)
	await TestUtil.frames(get_tree(), 90)
	p.touch_move = Vector2.ZERO
	var c2: Transform3D = Game.st.items[cart].xf
	runner.check(not CartPhysics.blocked(space, c2), "A5: after sliding along the wall the cart is still outside it")
	runner.check(absf(c2.origin.z - z0) > 0.5, "A5: the cart slides along the wall instead of sticking (moved %.2f m)" % absf(c2.origin.z - z0))
	await TestUtil.shutdown(get_tree(), main)

func _slip_and_release() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var p: Player = Game.local_player
	var cart: int = Game.carts.keys()[0]
	var st: LevelState = Game.st
	var spot := _free_spot(p.get_world_3d().direct_space_state, Game.layout)
	runner.check(spot != Vector3.ZERO, "A5: found open floor for the slip test")
	var held: bool = await _grab_here(p, cart, spot, 0.0)
	runner.check(held, "A5: cart held before the slip")
	var before: Transform3D = st.items[cart].xf
	p.start_slip()
	await TestUtil.frames(get_tree(), 10)
	var xf: Transform3D = st.items[cart].xf
	runner.check(st.items[cart].holder == 0, "A5: a slip drops the cart")
	runner.check(is_equal_approx(xf.origin.y, 0.0) and xf.basis.y.is_equal_approx(Vector3.UP), "A5: the dropped cart is on the floor and upright (y=%.2f)" % xf.origin.y)
	runner.check(xf.origin.distance_to(before.origin) < 0.2, "A5: the cart stays where it was instead of being thrown (%.2f m)" % xf.origin.distance_to(before.origin))
	runner.check(not Game.world.bodies.has(cart), "A5: the dropped cart is not a rigid body")
	# a plain release with a floating, tilted transform is grounded too
	await _grab_here(p, cart, spot, 0.0)
	Game.request_release(cart, Transform3D(Basis(Vector3.RIGHT, 0.7), spot + Vector3(1, 2.0, 0)), Vector3.ZERO, Vector3.ZERO)
	await TestUtil.frames(get_tree(), 3)
	var x2: Transform3D = st.items[cart].xf
	runner.check(is_equal_approx(x2.origin.y, 0.0) and x2.basis.y.is_equal_approx(Vector3.UP), "A5: release always grounds the cart (y=%.2f)" % x2.origin.y)
	await TestUtil.shutdown(get_tree(), main)

func _no_room_grab() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var p: Player = Game.local_player
	var L: LevelLayout = Game.layout
	var cart: int = Game.carts.keys()[0]
	var wall_x: float = L.rooms[1].rect.position.x
	# stand right at the wall, facing it: no space for the cart in front
	p.global_position = Vector3(wall_x + 0.35, 0.05, 15.0)
	p.look_yaw = PI * 0.5
	Game.st.op_cart_move(cart, Transform3D(Basis(), Vector3(wall_x + 2.5, 0, 15.0)))
	await TestUtil.frames(get_tree(), 3)
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	runner.check(CartPhysics.blocked(space, p.cart_xf()), "A5: the test spot really has no room in front")
	p._request_grab(cart)
	await TestUtil.frames(get_tree(), 3)
	runner.check(Game.st.items[cart].holder == 0, "A5: grabbing a cart with no room in front is declined")
	# in open floor the same call works
	var ok: bool = await _grab_here(p, cart, Vector3(wall_x + 3.0, 0.05, 15.0), PI * 0.5)
	runner.check(ok, "A5: grabbing a cart in open floor still works")
	await TestUtil.shutdown(get_tree(), main)

## Pushes a cart straight through a gap of the given width in a synthetic wall, step by step, the way
## Player._update_cart_push does. Returns the cart's final z (start -1.5, goal +1.5).
func _push_through_gap(space: PhysicsDirectSpaceState3D, origin: Vector3) -> float:
	var cur := Transform3D(Basis(), origin + Vector3(0, 0, -1.5))
	var z := -1.5
	for i in 120:
		z += 0.04
		var want := Transform3D(Basis(), origin + Vector3(0, 0, z))
		cur = CartPhysics.resolve(space, cur, want)
		if not cur.origin.is_equal_approx(want.origin):
			z = cur.origin.z - origin.z   # the pusher is held back behind a blocked cart
	return cur.origin.z - origin.z

func _doorways() -> void:
	var main := await TestUtil.boot(get_tree(), 5)
	var root: Node3D = Game.level_root
	var origin := Vector3(300, 0, 300)   # far outside the store
	var wall := StaticBody3D.new()
	wall.collision_layer = Defs.LAYER_WORLD
	root.add_child(wall)
	var specs := {}   # gap -> built
	for gap in [1.1, 0.5]:
		var o := origin + Vector3(0 if gap == 1.1 else 40, 0, 0)
		for side in [-1.0, 1.0]:
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(3.0, 2.2, 0.16)
			cs.shape = sh
			cs.position = o + Vector3(side * (gap * 0.5 + 1.5), 1.1, 0)
			wall.add_child(cs)
	await TestUtil.frames(get_tree(), 3)
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	runner.check(CartPhysics.blocked(space, Transform3D(Basis(), origin + Vector3(1.5, 0, 0))), "A5: the synthetic wall exists (wide)")
	runner.check(CartPhysics.blocked(space, Transform3D(Basis(), origin + Vector3(40 + 1.5, 0, 0))), "A5: the synthetic wall exists (narrow)")
	var z_wide := _push_through_gap(space, origin)
	runner.check(z_wide > 1.4, "A5: a cart is pushed straight through a 1.1 m doorway (ended %.2f m past the wall)" % z_wide)
	runner.check(CartPhysics.blocked(space, Transform3D(Basis(), origin + Vector3(40, 0, 0))), "A5: a cart centred in the 0.5 m gap overlaps its sides")
	var z_narrow := _push_through_gap(space, origin + Vector3(40, 0, 0))
	runner.check(z_narrow < -0.3, "A5: a cart does not squeeze through a 0.5 m gap (stopped %.2f m before the wall)" % z_narrow)
	wall.queue_free()
	# every real doorway in every level is wider than the cart footprint, with margin
	var narrowest := 99.0
	for lv in [1, 2, 3, 4, 5, 6]:
		var def := Levels.get_def(lv, 300, 5)
		var Lv := Layouts.build(def, 5)
		for d in Lv.doors:
			narrowest = minf(narrowest, float(d.width))
	runner.check(narrowest >= CartPhysics.SIZE.x + 0.3, "A5: every doorway is wider than the cart (narrowest %.2f m)" % narrowest)
	await TestUtil.shutdown(get_tree(), main)
