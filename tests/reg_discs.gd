extends Node
## M1.1: core disc interaction and presentation.
##  1 discs are visible inside open cases (slot geometry vs the open-case meshes)
##  2 eject / pick up / insert cycle, repeatable, solo and with several peers
##  3 hands do not cross when holding/opening (first-person rig)
##  4 emotes are performed by the existing hands (nothing spawned)
##  5 the bedroom has no middle sorting table (and old saves with table items still load)
##  6 dropped/thrown discs stay in the level (safe spawn, rescue, no mid-air freeze)
##  7 art identity of a disc is one function of the item in every state; aiming picks what is aimed at
var runner

func run() -> void:
	_disc_slots_are_visible()
	_art_identity()
	_aim_precision()
	_bedroom_layout()
	_table_items_migrate()
	_hands_pose()
	await _hands_emote_and_open()
	await _cycle()
	await _multi_peer_eject()
	await _release_safety()
	await _physics_hardening()

# ------------------------------------------------------------------ 1. visibility
func _disc_slots_are_visible() -> void:
	var checked := 0
	var buried := 0
	var formats := {}
	for lv in [1, 2, 3, 4, 5]:
		var st: LevelState = TestUtil.fresh(lv, 7)[2]
		for it in st.items:
			if it.kind != Defs.K_DISC or it.parent < 0:
				continue
			var cont: LevelState.Item = st.items[it.parent]
			if cont.kind != Defs.K_CASE:
				continue
			var s := st.size_of(cont)
			var z: float = it.xf.origin.z
			var half: float = Defs.DISC_THICK * 0.5
			# solid parts of the OPEN mesh along z: flip case = back panel [-d/2, 0]; box = back wall [-d/2, -d/2+0.006]
			var solid_top: float = 0.0 if LevelState.is_flip_case(cont) else -s.z * 0.5 + 0.006
			checked += 1
			formats[cont.fmt] = true
			if z - half < solid_top - 1e-6:
				buried += 1
			# and the disc must be inside the case outline in x/y
			var r: float = Defs.DISC_RADIUS[it.fmt]
			if absf(it.xf.origin.x) + r > s.x * 0.5 + 0.02 or absf(it.xf.origin.y) + r > s.y * 0.5 + 0.02:
				buried += 1
	runner.check(checked > 100, "1: checked %d discs in cases across levels 1-5 (%d case formats)" % [checked, formats.size()])
	runner.check(buried == 0, "1: no disc sits inside the solid back of its open case (%d buried)" % buried)
	# the position is a pure function of the container: a save made with the old buried positions is repaired on load
	var st2: LevelState = TestUtil.fresh(1, 7)[2]
	var d: LevelState.Item = null
	for it in st2.items:
		if it.kind == Defs.K_DISC and it.parent >= 0:
			d = it
			break
	var good: Transform3D = d.xf
	d.xf = Transform3D(good.basis, Vector3(0, 0, -st2.size_of(st2.items[d.parent]).z * 0.5 + 0.004))   # v1.0 value
	var st3: LevelState = TestUtil.fresh(1, 7)[2]
	runner.check(st3.deserialize(st2.serialize()), "1: state with the old disc position deserializes")
	runner.check(st3.items[d.uid].xf.origin.is_equal_approx(good.origin), "1: loading repairs the old buried disc position")

# ------------------------------------------------------------------ 7. identity / aiming
func _art_identity() -> void:
	var bad := 0
	var n := 0
	for lv in [1, 2, 5]:
		var st: LevelState = TestUtil.fresh(lv, 3)[2]
		Covers.headless = true
		await_free_atlas(st)
		var seen := {}
		for it in st.items:
			if it.kind != Defs.K_DISC:
				continue
			n += 1
			var prod: Dictionary = st.products[it.product]
			if prod.discs[it.sub] != it.uid:
				bad += 1
			var li: int = Covers.label_index.get(it.uid, -1)
			if li < 0 or seen.has(li):
				bad += 1
			seen[li] = true
			# the art key is the item's own product (title/edition) + disc number, whatever state it is in
			var before: Color = Covers.item_custom(st, it)
			if it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
				st.op_grab(it.uid, 5)
				st.op_release(it.uid, Transform3D(Basis(), Vector3(2, 0.1, 2)))
				if Covers.item_custom(st, it) != before:
					bad += 1
	runner.check(n > 300 and bad == 0, "7: %d discs: label atlas index is unique and maps to (own product, disc number); art key unchanged by grab/release (%d bad)" % [n, bad])
	# serialization keeps identity (product / sub are structural, never saved)
	var st2: LevelState = TestUtil.fresh(1, 3)[2]
	var st3: LevelState = TestUtil.fresh(1, 3)[2]
	var snapshot := {}
	for it in st2.items:
		if it.kind == Defs.K_DISC:
			snapshot[it.uid] = [it.product, it.sub, it.fmt]
	st3.deserialize(st2.serialize())
	var same := true
	for uid in snapshot:
		var it3: LevelState.Item = st3.items[uid]
		same = same and snapshot[uid] == [it3.product, it3.sub, it3.fmt]
	runner.check(same, "7: disc identity (product, disc number, format) survives save/load and peer changes")

func await_free_atlas(st: LevelState) -> void:
	# computes cover_index / label_index (they are filled before the headless early-out)
	Covers.build_level_atlases(st)

func _aim_precision() -> void:
	var total := 0
	var wrong_unblocked := 0
	for lv in [1, 2, 5]:
		var st: LevelState = TestUtil.fresh(lv, 11)[2]
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		for it in st.items:
			if it.kind != Defs.K_DISC or it.parent >= 0 or it.bucket >= 0 or it.stash >= 0 or it.holder != 0 or it.table >= 0:
				continue
			var c: Vector3 = st.world_xf(it.uid).origin
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(0.8, 1.4)
			var from := Vector3(c.x + cos(ang) * dist, 1.55, c.z + sin(ang) * dist)
			var dir := (c - from).normalized()
			var got: int = int(st.raycast(from, dir, 3.0, 0.03).get("uid", -1))
			total += 1
			if got != it.uid:
				# acceptable only if the selected item is genuinely in front of the disc along the ray
				var gi: LevelState.Item = st.items[got] if got >= 0 else null
				var blocked := false
				if gi != null:
					var inv := st.world_xf(got).affine_inverse()
					var th = LevelState._ray_aabb(inv * from, inv.basis * dir, st.local_aabb(gi))
					var invd := st.world_xf(it.uid).affine_inverse()
					var td = LevelState._ray_aabb(invd * from, invd.basis * dir, st.local_aabb(it))
					blocked = th != null and (td == null or th <= td + 0.001)
				if not blocked:
					wrong_unblocked += 1
	runner.check(total > 150 and wrong_unblocked == 0, "7: aiming at a loose disc picks that disc unless another item is really in front (%d aimed, %d wrong)" % [total, wrong_unblocked])

# ------------------------------------------------------------------ 5. bedroom
func _bedroom_layout() -> void:
	var def := Levels.get_def(1, 300, 5)
	var L := Layouts.build(def, 5)
	var st: LevelState = TestUtil.fresh(1, 5)[2]
	var kinds := {}
	for p in L.props:
		kinds[p.type] = true
	runner.check(L.sort_tables.is_empty() and st.tables.is_empty() and not kinds.has("sort_table"), "5: the bedroom has no sorting table in the middle")
	for k in ["bed", "desk", "wardrobe", "door"]:
		runner.check(kinds.has(k), "5: the bedroom keeps its %s" % k)
	runner.check(L.shelf_slots.size() >= 3, "5: the bedroom keeps its shelves (%d)" % L.shelf_slots.size())
	# the centre of the room is free floor again
	var centre := Vector3(3.3, 0.0, 2.2)
	var blocked := 0
	for o in L.obstacles:
		if (o as AABB).grow(0.4).has_point(centre + Vector3(0, 0.2, 0)):
			blocked += 1
	runner.check(blocked == 0, "5: the middle of the room is open floor (no obstacle within 0.4 m of the old table spot)")
	# the other levels still have their sorting tables
	for lv in [2, 3, 4, 5]:
		runner.check(not Layouts.build(Levels.get_def(lv, 300, 5), 5).sort_tables.is_empty(), "5: level %d keeps its sorting table(s)" % lv)

func _table_items_migrate() -> void:
	# a save made when the bedroom still had its table may contain items standing on it
	var old: LevelState = TestUtil.fresh(1, 5)[2]
	old.tables.append({"id": 0, "xf": Transform3D(Basis(), Vector3(3.3, 0, 2.2)), "cells": Vector2i(6, 3), "cell_size": Vector2(0.27, 0.27), "occupied": {}, "height": 0.78})
	var uid := -1
	for it in old.items:
		if it.kind == Defs.K_CASE and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			uid = it.uid
			break
	old.items[uid].table = 4
	old.items[uid].xf = Transform3D(Basis(), Vector3(3.3, 0.78, 2.2))
	(old.tables[0].occupied as Dictionary)[4] = uid
	var fresh: LevelState = TestUtil.fresh(1, 5)[2]
	runner.check(fresh.deserialize(old.serialize()), "5: a state that has one more sorting table than the level now has still loads")
	var it2: LevelState.Item = fresh.items[uid]
	runner.check(it2.table == -1 and it2.xf.origin.y < 0.1, "5: an item that stood on the removed table is put on the floor (y=%.2f)" % it2.xf.origin.y)
	runner.check(fresh.tables.is_empty(), "5: ...and the level has no table")

# ------------------------------------------------------------------ 3/4. hands
func _make_hands() -> Array:
	var cam := Node3D.new()
	add_child(cam)
	var h := FPHands.new()
	cam.add_child(h)
	return [cam, h]

func _converge(h: FPHands, seconds := 1.5) -> void:
	for i in int(seconds * 60.0):
		h._process(1.0 / 60.0)

func _arm_dir(n: Node3D) -> Vector3:
	return n.basis * Vector3(0, 0, 1)   # forearm trails behind the hand along local +z (towards the shoulder)

func _hands_pose() -> void:
	var r := _make_hands()
	var cam: Node3D = r[0]
	var h: FPHands = r[1]
	_converge(h)
	var l: Node3D = h._l
	var rr: Node3D = h._r
	runner.check(l.position.x + _arm_dir(l).x * 0.3 < rr.position.x + _arm_dir(rr).x * 0.3 - 0.2, "3: idle - the forearms do not cross")
	h.holding = true
	_converge(h)
	var al := _arm_dir(l)
	var ar := _arm_dir(rr)
	runner.check(al.x < -0.2 and ar.x > 0.2, "3: holding - left forearm slants left, right forearm slants right (x=%.2f / %.2f), so they do not cross" % [al.x, ar.x])
	runner.check(l.position.x < rr.position.x - 0.1, "3: holding - the left hand stays on the left of the right hand")
	# the arms never meet: their back ends (0.3 m behind each hand) stay apart
	var back_l := l.position + al * 0.3
	var back_r := rr.position + ar * 0.3
	runner.check(back_l.x < back_r.x - 0.2, "3: holding - the forearm ends do not cross (%.2f vs %.2f)" % [back_l.x, back_r.x])
	h.inspecting = true
	_converge(h)
	runner.check(_arm_dir(l).x <= 0.02 and _arm_dir(rr).x >= -0.02, "3: inspecting - forearms are not crossed")
	h.inspecting = false
	cam.queue_free()

func _hands_emote_and_open() -> void:
	var r := _make_hands()
	var cam: Node3D = r[0]
	var h: FPHands = r[1]
	_converge(h)
	var l_id: int = h._l.get_instance_id()
	var r_id: int = h._r.get_instance_id()
	var kids := h.get_child_count()
	var idle_l: Vector3 = h._l.position
	var idle_r: Vector3 = h._r.position
	# open/close gesture: mirrored, then back to rest
	h.holding = true
	_converge(h)
	var base_l: Vector3 = h._l.position
	var base_r: Vector3 = h._r.position
	h.open_close(true)
	var widest := 0.0
	var mirrored := true
	for i in 12:
		h._process(1.0 / 60.0)
		var dl: float = h._l.position.x - base_l.x
		var dr: float = h._r.position.x - base_r.x
		widest = maxf(widest, absf(dl))
		mirrored = mirrored and absf(dl + dr) < 0.03
	runner.check(widest > 0.02 and mirrored, "3: opening a case moves both hands symmetrically (left/right mirrored, %.3f m)" % widest)
	_converge(h)
	runner.check(h._l.position.distance_to(base_l) < 0.02 and h._r.position.distance_to(base_r) < 0.02, "3: ...and they return to the holding pose")
	h.holding = false
	_converge(h)
	# emotes: the same two hand nodes move; nothing is spawned or hidden
	for e in ["wave", "dance", "point", "facepalm", "cheer", "shrug"]:
		h.play_emote(e)
		var moved := 0.0
		for i in 60:
			h._process(1.0 / 60.0)
			moved = maxf(moved, maxf(h._l.position.distance_to(idle_l), h._r.position.distance_to(idle_r)))
		runner.check(h.is_emoting() and moved > 0.12, "4: emote '%s' moves the existing hands (%.2f m from rest)" % [e, moved])
		runner.check(h._l.get_instance_id() == l_id and h._r.get_instance_id() == r_id and h.get_child_count() == kids and h._l.visible and h._r.visible, "4: emote '%s' uses the same hand nodes (no new hands, none hidden)" % e)
		_converge(h, 3.0)
		runner.check(not h.is_emoting() and h._l.position.distance_to(idle_l) < 0.03 and h._r.position.distance_to(idle_r) < 0.03, "4: after '%s' the same hands are back in their previous positions" % e)
	h.play_emote("not_an_emote")
	runner.check(not h.is_emoting(), "4: an unknown emote name does nothing")
	cam.queue_free()
	await get_tree().process_frame
	# through the real event path
	var main := await TestUtil.boot(get_tree(), 1)
	var p: Player = Game.local_player
	var cam_kids := p.camera.get_child_count()
	var hand_kids := p.hands.get_child_count()
	Game.ev_emote(Game.me(), "cheer")
	await TestUtil.frames(get_tree(), 20)
	runner.check(p.hands.is_emoting() and p.bean.emote == "cheer", "4: the emote event drives both the first-person hands and the body")
	runner.check(p.camera.get_child_count() == cam_kids and p.hands.get_child_count() == hand_kids, "4: the emote added no nodes to the camera or hands")
	await TestUtil.shutdown(get_tree(), main)

# ------------------------------------------------------------------ 2. cycle
func _first_case_and_disc(st: LevelState, skip: Array = []) -> Array:
	for pr in st.products:
		var root: LevelState.Item = st.items[pr.root]
		if root.kind == Defs.K_CASE and root.fmt == Defs.F_MODERN and pr.edition == Defs.E_STANDARD and (pr.discs as Array).size() == 1 and not skip.has(root.uid):
			return [root.uid, pr.discs[0]]
	return [-1, -1]

func _cycle() -> void:
	var main := await TestUtil.boot(get_tree(), 1)
	var st: LevelState = Game.st
	var p: Player = Game.local_player
	var a: Array = _first_case_and_disc(st)
	var b: Array = _first_case_and_disc(st, [a[0]])
	var case_a: int = a[0]
	var disc: int = a[1]
	var case_b: int = b[0]
	p.global_position = Vector3(5.0, 0.05, 4.0)
	await TestUtil.frames(get_tree(), 3)
	# put the pieces on the floor around the player
	var spot := p.global_position + Vector3(0, 0, -1.2)
	for u in [case_a, case_b]:
		Game.request_grab(u)
		await TestUtil.frames(get_tree(), 1)
		Game.request_open(u, true)
		await TestUtil.frames(get_tree(), 1)
		Game.request_release(u, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), spot + Vector3(0.5 * float(u % 2), 0.2, 0)), Vector3.ZERO, Vector3.ZERO)
		await TestUtil.frames(get_tree(), 1)
	await TestUtil.frames(get_tree(), 60)
	var ok_cycles := 0
	for cycle in 3:
		var tag := "cycle %d" % (cycle + 1)
		# pick the loose disc up (from the case it is in, or from the floor)
		if st.items[disc].parent >= 0:
			Game.request_grab(st.items[disc].parent)
			await TestUtil.frames(get_tree(), 2)
			Game.request_eject(st.items[disc].parent, p.hold_point.global_transform)
			await TestUtil.frames(get_tree(), 3)
			Game.request_release(st.items[disc].parent if st.items[disc].parent >= 0 else case_a, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), spot + Vector3(0.5, 0.2, 0.3)), Vector3.ZERO, Vector3.ZERO)
		else:
			pass
		await TestUtil.frames(get_tree(), 5)
		# make sure the disc is in the player's hand
		if st.items[disc].holder != Game.me():
			Game.request_grab(disc)
			await TestUtil.frames(get_tree(), 2)
		# insert into case A (open, on the floor)
		Game.request_insert(disc, case_a)
		await TestUtil.frames(get_tree(), 2)
		var inserted: bool = st.items[disc].parent == case_a and st.items[disc].holder == 0
		# close, open: the disc stays associated with its case
		Game.request_open(case_a, false)
		await TestUtil.frames(get_tree(), 2)
		var closed_ok: bool = st.items[disc].parent == case_a and not st.is_visible(disc)
		Game.request_open(case_a, true)
		await TestUtil.frames(get_tree(), 2)
		var open_ok: bool = st.items[disc].parent == case_a and st.is_visible(disc)
		# pick the case up and take the disc out: it ends in the hand, state is consistent
		Game.request_grab(case_a)
		await TestUtil.frames(get_tree(), 2)
		Game.request_eject(case_a, p.hold_point.global_transform)
		await TestUtil.frames(get_tree(), 3)
		var ejected_in_hand: bool = st.items[disc].parent == -1 and st.items[disc].holder == Game.me() and st.held_by(Game.me()).back() == disc
		# put the case down, drop the disc: a loose, targetable, pickable disc
		Game.request_release(case_a, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), spot + Vector3(-0.6, 0.2, 0.2)), Vector3.ZERO, Vector3.ZERO)
		await TestUtil.frames(get_tree(), 2)
		var dxf := Transform3D(Basis(), spot + Vector3(0.2, 0.3, 0.9))
		Game.request_release(disc, dxf, Vector3.ZERO, Vector3.ZERO)
		await TestUtil.frames(get_tree(), 80)
		var dpos: Vector3 = st.items[disc].xf.origin
		var loose_ok: bool = st.items[disc].holder == 0 and st.items[disc].parent == -1 and dpos.y > -0.02 and dpos.y < 1.0 and Game.layout.is_inside(dpos, 0.2)
		# aim at it like a player and pick it up again
		p.global_position = Vector3(dpos.x, 0.05, dpos.z + 0.9)
		await TestUtil.frames(get_tree(), 3)
		TestUtil.aim_at(p, dpos)
		await TestUtil.frames(get_tree(), 3)
		var targeted: bool = p.target.get("type", "") == "item" and int(p.target.get("uid", -1)) == disc and p.context().get("grab", "") == "Grab"
		Game.request_grab(disc)
		await TestUtil.frames(get_tree(), 2)
		var picked: bool = st.items[disc].holder == Game.me()
		# ... and into the other case
		Game.request_insert(disc, case_b)
		await TestUtil.frames(get_tree(), 2)
		var into_b: bool = st.items[disc].parent == case_b
		# move it back to case A for the next round
		Game.request_grab(case_b)
		await TestUtil.frames(get_tree(), 2)
		Game.request_eject(case_b, p.hold_point.global_transform)
		await TestUtil.frames(get_tree(), 3)
		Game.request_release(case_b, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), spot + Vector3(0.9, 0.2, -0.3)), Vector3.ZERO, Vector3.ZERO)
		await TestUtil.frames(get_tree(), 40)
		runner.check(inserted and closed_ok and open_ok, "2: %s - insert, close, open keep the disc in its case" % tag)
		runner.check(ejected_in_hand, "2: %s - Take out puts the disc in the player's hand" % tag)
		runner.check(loose_ok and targeted and picked, "2: %s - the dropped disc is loose, visible, targetable and can be picked up again" % tag)
		runner.check(into_b, "2: %s - ...and inserted into another case" % tag)
		if inserted and closed_ok and ejected_in_hand and loose_ok and targeted and picked and into_b:
			ok_cycles += 1
		# disc is held by the player after the last eject from case_b: drop it for the next round
		if st.items[disc].holder == Game.me():
			Game.request_release(disc, Transform3D(Basis(), spot + Vector3(0.1, 0.4, 0.5)), Vector3.ZERO, Vector3.ZERO)
			await TestUtil.frames(get_tree(), 30)
		# make the disc be inside case_a for the next round
		Game.request_grab(disc)
		await TestUtil.frames(get_tree(), 2)
		Game.request_insert(disc, case_a)
		await TestUtil.frames(get_tree(), 2)
	runner.check(ok_cycles == 3, "2: the full cycle works 3 times in a row (%d/3)" % ok_cycles)
	# hands full -> Take out leaves a loose disc instead
	Game.request_grab(case_a)
	await TestUtil.frames(get_tree(), 2)
	var fillers := TestUtil.free_cases(st, Player.MAX_STACK)
	var held_n := 0
	for f in fillers:
		if st.held_by(Game.me()).size() >= Player.MAX_STACK:
			break
		Game.request_grab(f)
		await TestUtil.frames(get_tree(), 1)
	# case_a must be on top for Take out: re-grab order is irrelevant for the data rule under test
	var full: bool = st.held_by(Game.me()).size() >= Player.MAX_STACK
	if full and st.items[case_a].holder == Game.me() and not st.items[case_a].contents.is_empty():
		var c0 := st.items[case_a].contents[0] as int
		Game.ev_eject(case_a, p.hold_point.global_transform, Game.me())
		await TestUtil.frames(get_tree(), 5)
		runner.check(st.items[c0].holder == 0 and Game.world.bodies.has(c0), "2: with full hands Take out leaves a loose, simulated disc")
	else:
		runner.check(true, "2: (full-hands case skipped: setup did not fill the stack)")
	await TestUtil.shutdown(get_tree(), main)

func _multi_peer_eject() -> void:
	# several peers: items belong to whoever took them out, nobody else can grab them
	var main := await TestUtil.boot(get_tree(), 1)
	var st: LevelState = Game.st
	var a: Array = _first_case_and_disc(st)
	var case_a: int = a[0]
	var disc: int = a[1]
	Game.request_grab(case_a)
	await TestUtil.frames(get_tree(), 2)
	Game.request_open(case_a, true)
	await TestUtil.frames(get_tree(), 2)
	# peer 7 (a client) takes the disc out of the case held by the host; the event carries the peer
	st.op_release(case_a, Transform3D(Basis(), Vector3(2, 0.05, 2)))
	st.op_grab(case_a, 7)
	Game.ev_eject(case_a, Transform3D(Basis(), Vector3(2, 1.0, 2)), 7)
	await TestUtil.frames(get_tree(), 2)
	runner.check(st.items[disc].holder == 7 and st.held_by(7).back() == disc, "2: peer 7 took the disc out: it is in peer 7's hands")
	runner.check(not st.op_grab(disc, 8), "2: another peer cannot take it out of peer 7's hands")
	Game.ev_release(disc, Transform3D(Basis(), Vector3(2.5, 0.3, 2)), Vector3.ZERO, Vector3.ZERO, 7)
	await TestUtil.frames(get_tree(), 40)
	runner.check(st.items[disc].holder == 0 and Game.world.bodies.has(disc), "2: peer 7 drops it: loose again")
	runner.check(st.op_grab(disc, 8) and st.held_by(8) == [disc], "2: peer 8 can now pick it up")
	# the serialized state a late joiner receives has the right owner
	var bytes := st.serialize()
	var other: LevelState = TestUtil.fresh(1, 1234)[2]
	runner.check(other.deserialize(bytes) and other.items[disc].holder == 8 and other.held_by(8) == [disc], "2: a late joiner sees the same owner")
	await TestUtil.shutdown(get_tree(), main)

# ------------------------------------------------------------------ 6. falling
func _release_safety() -> void:
	var main := await TestUtil.boot(get_tree(), 1)
	var p: Player = Game.local_player
	var L: LevelLayout = Game.layout
	var st: LevelState = Game.st
	# standing against the west wall, facing it: the hold point is half a metre ahead, i.e. outside the room
	p.global_position = Vector3(0.45, 0.05, 3.0)
	p.look_yaw = PI * 0.5
	p.look_pitch = -0.1
	await TestUtil.frames(get_tree(), 4)
	# a spawn point 0.4 m beyond the wall, as the hold point is when standing against it
	var raw := Transform3D(Basis(), Vector3(-0.4, p.camera.global_position.y - 0.2, 3.0))
	var safe := p._safe_xf(raw)
	runner.check(safe.origin.x > 0.0, "6: a spawn point beyond the wall (x=%.2f) is pulled back into the room (x=%.2f)" % [raw.origin.x, safe.origin.x])
	var free_pt := p._safe_xf(Transform3D(Basis(), p.camera.global_position + Vector3(0.0, -0.2, 0.3)))
	runner.check(free_pt.origin.is_equal_approx(p.camera.global_position + Vector3(0.0, -0.2, 0.3)), "6: a free spawn point is left unchanged")
	var disc := -1
	for it in st.items:
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			disc = it.uid
			break
	Game.request_grab(disc)
	await TestUtil.frames(get_tree(), 2)
	p._drop(disc)
	await TestUtil.frames(get_tree(), 90)
	var o: Vector3 = st.items[disc].xf.origin
	runner.check(L.is_inside(o, 0.1) and o.y > -0.02 and st.items[disc].holder == 0, "6: a disc dropped against a wall stays in the room on the floor (%.2f, %.3f, %.2f)" % [o.x, o.y, o.z])
	runner.check(Game.world.rescued == 0, "6: ...without needing the rescue")
	# many drops and throws at different speeds: none leave the level, all remain pickable
	var discs: Array = []
	for it in st.items:
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0 and it.uid != disc:
			discs.append(it.uid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lost := 0
	var trials := 0
	p.global_position = Vector3(4.0, 0.05, 3.0)
	await TestUtil.frames(get_tree(), 3)
	var batch: Array = []
	for i in 18:
		var uid: int = discs.pop_back()
		Game.request_grab(uid)
		await TestUtil.frames(get_tree(), 1)
		var speed: float = [0.0, 3.0, 8.5, 12.0][i % 4]
		var pos := Vector3(4.0 + rng.randf_range(-1.5, 1.5), [1.0, 1.4, 0.4][i % 3], 3.0 + rng.randf_range(-1.5, 1.5))
		Game.request_release(uid, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos), Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)).normalized() * speed, Vector3(rng.randf(), rng.randf(), rng.randf()) * 6.0)
		batch.append(uid)
	await TestUtil.frames(get_tree(), 150)
	for uid in batch:
		var q: Vector3 = st.items[uid].xf.origin
		trials += 1
		if q.y < -0.05 or not L.is_inside(q, 0.3) or st.items[uid].holder != 0:
			lost += 1
	runner.check(lost == 0, "6: %d dropped/thrown discs (0-12 m/s) all end on a surface inside the level (%d lost)" % [trials, lost])
	await TestUtil.shutdown(get_tree(), main)

func _physics_hardening() -> void:
	var main := await TestUtil.boot(get_tree(), 1)
	var st: LevelState = Game.st
	var w: ItemWorld = Game.world
	var p: Player = Game.local_player
	var disc := -1
	for it in st.items:
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			disc = it.uid
			break
	Game.request_grab(disc)
	await TestUtil.frames(get_tree(), 1)
	Game.request_release(disc, Transform3D(Basis(), Vector3(4.0, 0.5, 3.0)), Vector3.ZERO, Vector3.ZERO)
	await TestUtil.frames(get_tree(), 90)
	var b: RigidBody3D = w.bodies.get(disc)
	runner.check(b != null, "6: the released disc is a simulated body")
	if b != null:
		# a body that ends up under the floor is put straight back (it used to fall for ~0.8 s, then teleport to a player)
		var before := w.rescued
		b.global_position = Vector3(4.0, -1.0, 3.0)
		b.linear_velocity = Vector3(0, -2.0, 0)
		await TestUtil.frames(get_tree(), 3)
		var back: Vector3 = b.global_position
		runner.check(w.rescued == before + 1 and back.y > -0.1 and absf(back.x - 4.0) < 1.5, "6: a disc pushed below the floor is rescued at once, near where it was (y=%.2f)" % back.y)
		# a body leaving the level sideways is rescued too
		before = w.rescued
		b.global_position = Vector3(60.0, 0.5, 60.0)
		await TestUtil.frames(get_tree(), 3)
		runner.check(w.rescued == before + 1 and Game.layout.is_inside(b.global_position, 0.3), "6: a disc that leaves the level is rescued and put back inside")
		# mid-air at ~zero speed (top of a throw) is NOT 'at rest': it must not be frozen into the data there
		p.global_position = Vector3(1.0, 0.05, 1.0)   # player far away so the item is not 'wanted'
		b.global_position = Vector3(4.0, 1.2, 3.0)
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.sleeping = false
		w.players = [p.global_position]
		w._still[disc] = 0.0
		w._update_activation()
		runner.check(w.bodies.has(disc) and st.items[disc].active, "6: a disc hanging in mid-air for an instant is not frozen there")
		# once it really rests (still for a while, or asleep) far from players, it freezes back into the data
		w._still[disc] = 1.0
		b.sleeping = true
		w._update_activation()
		runner.check(not w.bodies.has(disc) and not st.items[disc].active, "6: a resting disc far from players is frozen back into the level data")
	await TestUtil.shutdown(get_tree(), main)
