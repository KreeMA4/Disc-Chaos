extends Node
## Drives the real game scene headlessly: solves products through Game.request_* exactly like
## the player controller does, and checks physics, stacking, stashes and save/resume.
var runner

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.start_solo(1)
	await Game.level_loaded
	await _frames(5)
	var st: LevelState = Game.st
	var me := Game.me()
	runner.check(Game.local_player != null and st != null, "level 1 loads with a local player")
	# --- solve 3 unsolved standard products end-to-end
	var solved_before := st.solved_count
	var done := 0
	for p in st.products:
		if p.solved or p.edition == Defs.E_CE or done >= 3:
			continue
		if not await _solve(p):
			runner.check(false, "solve product %d (%s)" % [p.pid, Catalog.titles[p.title].name])
			continue
		done += 1
	runner.check(st.solved_count >= solved_before + 3, "3 products solved through requests (%d -> %d)" % [solved_before, st.solved_count])
	# --- throwing creates a physics body
	var loose := -1
	for it in st.items:
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			loose = it.uid
			break
	if loose >= 0:
		Game.request_grab(loose)
		await _frames(2)
		var xf := Transform3D(Basis(), Game.local_player.global_position + Vector3(0, 1.2, 0))
		Game.request_release(loose, xf, Vector3(0, 2, -4), Vector3(1, 2, 3))
		await _frames(2)
		runner.check(Game.world.bodies.has(loose), "thrown disc becomes an active RigidBody3D")
		await _frames(90)
		var y: float = Game.world.bodies[loose].global_position.y if Game.world.bodies.has(loose) else st.items[loose].xf.origin.y
		runner.check(y > -0.5 and y < 2.0, "thrown disc lands on the floor (y=%.2f)" % y)
	# --- stack carry
	var cases: Array = []
	for it in st.items:
		if it.kind == Defs.K_CASE and not it.open and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			cases.append(it.uid)
		if cases.size() >= 4:
			break
	for c in cases:
		if st.items[c].active:
			Game.world.deactivate(c)
		Game.request_grab(c)
		await _frames(1)
	runner.check(st.held_by(me).size() == cases.size(), "stack-carry %d closed cases" % cases.size())
	for c in st.held_by(me).duplicate():
		Game.request_release(c, Transform3D(Basis(), Game.local_player.global_position + Vector3(0, 1, -0.5)), Vector3.ZERO, Vector3.ZERO)
	await _frames(2)
	runner.check(st.held_by(me).is_empty(), "dropping the stack empties the hands")
	# --- grab ownership: an item held by someone else can't be taken
	if not cases.is_empty():
		st.items[cases[0]].holder = 99
		Game.request_grab(cases[0])
		await _frames(1)
		runner.check(st.items[cases[0]].holder == 99, "grab ownership: held items can't be stolen")
		st.items[cases[0]].holder = 0
	# --- stash reveal
	var sid := -1
	for s in st.stashes:
		if not s.revealed and not (s.items as Array).is_empty():
			sid = s.id
			break
	if sid >= 0:
		var n: int = (st.stashes[sid].items as Array).size()
		Game.request_reveal(sid)
		await _frames(3)
		runner.check(st.stashes[sid].revealed and (st.stashes[sid].items as Array).is_empty(), "stash %d revealed %d items" % [sid, n])
	# --- save & resume
	var sum_before := st.checksum()
	runner.check(Game.save_game(), "host can save mid-level")
	var solved_now := st.solved_count
	await main.leave_to_menu()
	await _frames(3)
	await Game.resume(1)
	await _frames(5)
	runner.check(Game.st != null and Game.st.solved_count == solved_now, "resume restores progress (%d solved)" % (Game.st.solved_count if Game.st else -1))
	Game.delete_save(1)
	main.leave_to_menu()
	await _frames(2)
	await _cart_test(main)
	main.queue_free()
	await _frames(2)

func _cart_test(main) -> void:
	main.start_solo(5)
	await Game.level_loaded
	await _frames(5)
	var st: LevelState = Game.st
	var p: Player = Game.local_player
	runner.check(not Game.carts.is_empty(), "store has %d push carts" % Game.carts.size())
	var cart: int = Game.carts.keys()[0]
	var case_uid := -1
	for it in st.items:
		if it.kind == Defs.K_CASE and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			case_uid = it.uid
			break
	Game.request_grab(case_uid)
	await _frames(2)
	Game.request_insert(case_uid, cart)
	await _frames(2)
	runner.check(st.items[case_uid].parent == cart, "a case can be put in a cart")
	p.global_position = st.items[cart].xf.origin + Vector3(0, 0, 1.0)
	await _frames(2)
	Game.request_grab(cart)
	await _frames(2)
	runner.check(p.pushing_cart() == cart, "player pushes the cart")
	var before := st.world_xf(case_uid).origin
	p.look_yaw = 0.0
	p.touch_move = Vector2(0, -1)
	await _frames(60)
	p.touch_move = Vector2.ZERO
	await _frames(2)
	var after := st.world_xf(case_uid).origin
	runner.check(after.distance_to(before) > 1.0, "cart contents travel with the cart (%.1f m)" % after.distance_to(before))
	Game.request_release(cart, p.cart_xf(), Vector3.ZERO, Vector3.ZERO)
	await _frames(2)
	runner.check(st.items[cart].holder == 0 and p.held().is_empty(), "letting go of the cart")
	Game.request_grab(case_uid)
	await _frames(2)
	runner.check(st.items[case_uid].holder == Game.me(), "items can be taken back out of a cart")
	main.leave_to_menu()
	await _frames(2)

func _solve(p: Dictionary) -> bool:
	var st: LevelState = Game.st
	var me := Game.me()
	var root: int = p.root
	# free the root if it's in a stash
	if st.items[root].stash >= 0:
		Game.request_reveal(st.items[root].stash)
		await _frames(2)
	if st.items[root].active:
		pass
	Game.request_grab(root)
	await _frames(1)
	if st.items[root].holder != me:
		print("    could not grab root ", root)
		return false
	if not st.items[root].open:
		Game.request_open(root, true)
		await _frames(1)
	for c in Array(st.items[root].contents):
		if not (p.discs as Array).has(c) and not (p.pieces as Array).has(c):
			Game.request_eject(root, Transform3D(Basis(), Game.local_player.global_position + Vector3(0.3, 1.0, 0)))
			await _frames(1)
	for d in p.discs:
		if st.items[d].parent == root:
			continue
		if st.items[d].stash >= 0:
			Game.request_reveal(st.items[d].stash)
			await _frames(2)
		var par: int = st.items[d].parent
		if par >= 0 and not st.items[par].open:
			Game.request_open(par, true)
			await _frames(1)
		Game.request_insert(d, root)
		await _frames(1)
		if st.items[d].parent != root:
			print("    insert failed disc ", d, " parent ", st.items[d].parent)
			return false
	for pc in p.pieces:
		if st.items[pc].parent != root:
			if st.items[pc].stash >= 0:
				Game.request_reveal(st.items[pc].stash)
				await _frames(2)
			Game.request_insert(pc, root)
			await _frames(1)
	Game.request_open(root, false)
	await _frames(1)
	var b: Dictionary = st.buckets[p.bucket]
	if not st.bucket_has_room(p.bucket, root):
		for u in (b.items as Array).duplicate():
			if st.correct_bucket_for(u) != p.bucket:
				st.op_grab(u, 77)
				st.op_release(u, Transform3D(Basis(), Vector3(1, 0.1, 1)))
	Game.request_shelve(root, p.bucket, Game.local_player.hold_point.global_transform)
	await _frames(1)
	return st.products[p.pid].solved
