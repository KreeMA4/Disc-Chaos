extends Node
## M1 / audit A3, A4, C1, B15, B13: save compatibility and persistence.
##  * real v1.0 save files (tests/fixtures/saves) still load, and are migrated
##  * items held at save time survive a resume under different peer ids
##  * old/damaged saves never trap the game on the loading screen
##  * the scanner highlight bit is not persisted
##  * autosave and the client clock
var runner

const FIX := "res://tests/fixtures/saves/"
const SCRATCH := "user://test_saves"
const LEGACY_CLIENT := 1865923442   # the random peer id recorded in the v1.0 fixtures

func run() -> void:
	_header_validation()
	_legacy_fixtures()
	_slot_round_trip()
	_flags_and_live_sync()
	_damaged_state()
	await _resume_flow()
	await _autosave_and_clock()

func _facts(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIX + name + ".json"))

func _rel_peers() -> Dictionary:
	return {0: 1}

func _floor_xf(_uid: int) -> Transform3D:
	return Transform3D(Basis(), Vector3(2, 0.1, 2))

# ---------------------------------------------------------------- A3: header validation
func _header_validation() -> void:
	var good := {"level": 1, "seed": 5, "state": _bytes(20), "version": Defs.CATALOG_VERSION, "format": SaveMigration.FORMAT}
	runner.check(SaveMigration.inspect(good).status == SaveMigration.Status.OK, "A3: a current save is OK")
	var legacy := good.duplicate()
	legacy.erase("format")
	runner.check(SaveMigration.inspect(legacy).status == SaveMigration.Status.LEGACY, "A3: a save without 'format' is a resumable legacy (v1.0) save")
	runner.check(SaveMigration.is_resumable(SaveMigration.inspect(legacy)), "A3: legacy saves are resumable")
	for v in [1, 3, 4]:
		var old := good.duplicate()
		old.version = v
		var r := SaveMigration.inspect(old)
		runner.check(r.status == SaveMigration.Status.STALE and not SaveMigration.is_resumable(r) and r.message != "", "A3: a save from catalog v%d is reported as not resumable, with a message" % v)
	var future := good.duplicate()
	future.format = 99
	runner.check(SaveMigration.inspect(future).status == SaveMigration.Status.FUTURE, "A3: a newer save format is reported, not loaded")
	var newer_cat := good.duplicate()
	newer_cat.version = Defs.CATALOG_VERSION + 1
	runner.check(SaveMigration.inspect(newer_cat).status == SaveMigration.Status.FUTURE, "A3: a save from a newer catalog is reported")
	runner.check(SaveMigration.inspect("junk").status == SaveMigration.Status.CORRUPT, "A3: a non-dictionary file is corrupt")
	runner.check(SaveMigration.inspect(null).status == SaveMigration.Status.CORRUPT, "A3: a null file is corrupt")
	var no_state := good.duplicate()
	no_state.erase("state")
	runner.check(SaveMigration.inspect(no_state).status == SaveMigration.Status.CORRUPT, "A3: a save without state is corrupt")
	var tiny := good.duplicate()
	tiny.state = PackedByteArray([1, 2, 3])
	runner.check(SaveMigration.inspect(tiny).status == SaveMigration.Status.CORRUPT, "A3: a truncated state is corrupt")
	var huge := good.duplicate()
	var hb := _bytes(20)
	hb.encode_u32(0, 0x7fffffff)
	huge.state = hb
	runner.check(SaveMigration.inspect(huge).status == SaveMigration.Status.CORRUPT, "A3: an absurd decompressed size is rejected (no giant allocation)")
	var wrong_type := good.duplicate()
	wrong_type.seed = "x"
	runner.check(SaveMigration.inspect(wrong_type).status == SaveMigration.Status.CORRUPT, "A3: wrong field types are corrupt")
	runner.check(SaveMigration.read("user://does_not_exist.save").status == SaveMigration.Status.MISSING, "A3: a missing file is MISSING")

func _bytes(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	b.encode_u32(0, 100)
	return b

# ---------------------------------------------------------------- real v1.0 fixtures
func _legacy_fixtures() -> void:
	for lv in [1, 2]:
		var facts := _facts("legacy_v1_level%d" % lv)
		var info := SaveMigration.read(FIX + "legacy_v1_level%d.save" % lv)
		runner.check(info.status == SaveMigration.Status.LEGACY, "A3: real v1.0 level-%d save is recognised as legacy" % lv)
		if info.status != SaveMigration.Status.LEGACY:
			continue
		var r := TestUtil.fresh(lv, int(info.data.seed))
		var st: LevelState = r[2]
		runner.check(st.deserialize(info.data.state), "A3: v1.0 level-%d state deserializes into the regenerated level" % lv)
		runner.check(st.items.size() == int(facts.items) and st.products.size() == int(facts.products), "A3: level %d item/product counts match the save (%d/%d)" % [lv, st.items.size(), st.products.size()])
		runner.check(st.solved_count == int(facts.solved), "A3: level %d progress is preserved (%d solved)" % [lv, st.solved_count])
		runner.check(st.checksum() == int(facts.checksum), "A3: level %d state is bit-identical to what v1.0 saved" % lv)
		var has_held := facts.has("host_held")
		if has_held:
			runner.check(st.items[int(facts.client_held)].holder == LEGACY_CLIENT and st.items[int(facts.host_held)].holder == 1, "A4 setup: the v1.0 save has an item held by the host (uid %d) and one by client peer %d (uid %d)" % [int(facts.host_held), LEGACY_CLIENT, int(facts.client_held)])
		if facts.has("flagged"):
			runner.check(st.items[int(facts.flagged)].flags & LevelState.TRANSIENT_FLAGS != 0, "C1 setup: the v1.0 save has the highlight bit set on uid %d" % int(facts.flagged))
		var released := st.restore_after_load(1, _rel_peers(), _floor_xf)
		var stranded := 0
		for it in st.items:
			if it.holder != 0 and it.holder != 1:
				stranded += 1
		runner.check(stranded == 0 and not st.hands.has(LEGACY_CLIENT), "A4: after migration nobody is recorded as holding items under a dead peer id")
		if has_held:
			runner.check(st.items[int(facts.host_held)].holder == 1 and st.held_by(1) == [int(facts.host_held)], "A4: the item the host held is still held by the host")
			runner.check(released == [int(facts.client_held)] and st.items[int(facts.client_held)].holder == 0, "A4: the item a client held is back in the world, nothing lost")
			var uid := int(facts.client_held)
			runner.check(st.op_grab(uid, 1), "A4: the released item can be picked up again")
		var flagged := 0
		for it in st.items:
			if it.flags & LevelState.TRANSIENT_FLAGS:
				flagged += 1
		runner.check(flagged == 0, "C1: the scanner highlight bit from the v1.0 save is cleared")

# ---------------------------------------------------------------- A4: slots across sessions
func _slot_round_trip() -> void:
	var r := TestUtil.fresh(5, 31)
	var st: LevelState = r[2]
	var cases := TestUtil.free_cases(st, 6)
	var cart := -1
	for it in st.items:
		if it.kind == Defs.K_CART:
			cart = it.uid
			break
	# session 1: host = peer 1 (slot 0), clients with random ids on slots 1 and 2
	var peers := {1: 0, 70011: 1, 99887: 2}
	var slot_of := func(p: int) -> int: return peers.get(p, LevelState.SLOT_LOST)
	st.op_grab(cases[0], 1)
	st.op_grab(cases[1], 1)
	st.op_grab(cases[2], 70011)
	st.op_grab(cases[3], 99887)
	st.op_grab(cases[4], 99887)
	st.op_grab(cart, 70011)
	var ck := st.checksum()
	var bytes := st.serialize(slot_of)
	# session 2: same level, the clients now have different peer ids (and the slot-2 player is absent)
	var r2 := TestUtil.fresh(5, 31)
	var st2: LevelState = r2[2]
	runner.check(st2.deserialize(bytes), "A4: slot-format state deserializes")
	var released := st2.restore_after_load(2, {0: 1, 1: 424242}, _floor_xf)
	runner.check(st2.items[cases[0]].holder == 1 and st2.items[cases[1]].holder == 1, "A4: host items stay with the host")
	runner.check(st2.items[cases[2]].holder == 424242 and st2.items[cart].holder == 424242, "A4: a client's items (and cart) go to whoever now plays that slot")
	runner.check(st2.held_by(424242) == [cases[2], cart] or st2.held_by(424242) == [cart, cases[2]], "A4: the new peer's hand list is rebuilt")
	runner.check(st2.held_by(1) == [cases[0], cases[1]], "A4: pick-up order is preserved (top of the stack stays on top)")
	runner.check(released.size() == 2 and st2.items[cases[3]].holder == 0 and st2.items[cases[4]].holder == 0, "A4: items of an absent player are put back in the world (%d)" % released.size())
	runner.check(not st2.hands.has(70011) and not st2.hands.has(99887), "A4: the old session's peer ids are gone")
	runner.check(st2.op_grab(cases[3], 1), "A4: an item released from an absent player can be grabbed")
	runner.check(not st2.op_grab(cases[2], 1), "A4: ...while an item held by the present client cannot be stolen")
	runner.check(st2.op_release(cases[2], Transform3D()), "A4: the new peer can put its restored item down")
	# a client that is first to reconnect under yet another id after the host saves again
	var peers2 := {1: 0, 424242: 1}
	var bytes2 := st2.serialize(func(p: int) -> int: return peers2.get(p, LevelState.SLOT_LOST))
	var r3 := TestUtil.fresh(5, 31)
	var st3: LevelState = r3[2]
	runner.check(st3.deserialize(bytes2) and st3.restore_after_load(2, {0: 1, 1: 5}, _floor_xf).is_empty(), "A4: a second save/resume cycle loses nothing")
	runner.check(st3.items[cart].holder == 5, "A4: the cart is still with the player of slot 1 after two cycles")
	runner.check(ck != 0, "A4 sanity: checksum computed")

# ---------------------------------------------------------------- C1 + live sync unchanged
func _flags_and_live_sync() -> void:
	var r := TestUtil.fresh(1, 9)
	var st: LevelState = r[2]
	st.items[3].flags |= 2
	st.items[4].flags |= 5   # unrelated bits must survive
	var saved := st.serialize(func(_p: int) -> int: return 0)
	var r2 := TestUtil.fresh(1, 9)
	var st2: LevelState = r2[2]
	st2.deserialize(saved)
	st2.restore_after_load(2, {0: 1}, _floor_xf)
	runner.check(st2.items[3].flags == 0, "C1: the highlight bit does not survive a save")
	runner.check(st2.items[4].flags == 5 & ~2 and (st2.items[4].flags & 1) == 1, "C1: other flag bits are kept")
	# live network sync (no slot callable) is byte-for-byte what v1.0 sends: peer ids and flags untouched
	st.op_grab(10, 123456789)
	var live := st.serialize()
	var r3 := TestUtil.fresh(1, 9)
	var st3: LevelState = r3[2]
	runner.check(st3.deserialize(live), "live: state deserializes")
	runner.check(st3.items[10].holder == 123456789 and st3.hands.has(123456789) and st3.items[3].flags & 2 != 0, "live: sync keeps peer ids and flags (mixed-version sessions unaffected)")
	runner.check(st3.checksum() == st.checksum(), "live: checksums match after sync")

# ---------------------------------------------------------------- A3: structural validation
func _damaged_state() -> void:
	var r := TestUtil.fresh(1, 9)
	var st: LevelState = r[2]
	var ck := st.checksum()
	var good := st.serialize()
	var cut := good.slice(0, good.size() / 2)
	runner.check(not st.deserialize(cut) and st.checksum() == ck, "A3: a truncated state is rejected and leaves the level untouched")
	var garbage := PackedByteArray()
	garbage.resize(200)
	garbage.encode_u32(0, 1000)
	runner.check(not st.deserialize(garbage) and st.checksum() == ck, "A3: garbage state is rejected and leaves the level untouched")
	var other := TestUtil.fresh(2, 9)[2] as LevelState
	runner.check(not st.deserialize(other.serialize()), "A3: a state from a different level layout is rejected")
	var bad := {"n": st.items.size(), "ints": PackedInt32Array([1, 2]), "xfs": PackedFloat32Array(), "conts": [], "bks": [], "sts": [], "tbs": [], "stats": {}, "elapsed": 0.0}
	var raw := var_to_bytes(bad)
	var packed := PackedByteArray()
	packed.resize(4)
	packed.encode_u32(0, raw.size())
	packed.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	runner.check(not st.deserialize(packed) and st.checksum() == ck, "A3: arrays of the wrong size are rejected before anything is applied")

# ---------------------------------------------------------------- A3/A4 end to end
func _clean_scratch() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	for f in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH + "/" + f)

func _write_raw(level: int, d: Variant) -> void:
	var f := FileAccess.open("%s/level_%d.save" % [SCRATCH, level], FileAccess.WRITE)
	f.store_var(d)
	f.close()

func _resume_flow() -> void:
	_clean_scratch()
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	Game.save_dir = SCRATCH
	# --- a save from an older catalog: kept on disk, reported, never loads, never hangs
	_write_raw(1, {"level": 1, "seed": 5, "state": _bytes(40), "version": 3, "wh": 400, "date": "x"})
	var t0 := Time.get_ticks_msec()
	runner.check(not Game.has_save(1) and Game.has_save_file(1), "A3: an old-catalog save is not offered for Continue but is kept")
	var ok: bool = await Game.resume(1)
	runner.check(not ok and Game.st == null and not Game.running, "A3: resuming an old-catalog save fails cleanly, no level is loaded")
	runner.check(Time.get_ticks_msec() - t0 < 1500 and Game.last_resume_error != "", "A3: ...immediately, with a reason (%s)" % Game.last_resume_error)
	main.start_solo(1, true)
	await TestUtil.frames(get_tree(), 5)
	runner.check(not main.loading.visible, "A3: Continue on an old save does not show the loading screen")
	runner.check(FileAccess.file_exists(SCRATCH + "/level_1.save"), "A3: the old save file is still on disk")
	Game.delete_save(1)
	runner.check(not Game.has_save_file(1), "A3: Discard removes the file")
	# --- corrupt file
	var f := FileAccess.open(SCRATCH + "/level_1.save", FileAccess.WRITE)
	f.store_string("this is not a save")
	f.close()
	runner.check(not Game.has_save(1), "A3: a garbage file is not offered for Continue")
	ok = await Game.resume(1)
	runner.check(not ok and Game.st == null, "A3: resuming a garbage file fails cleanly")
	Game.delete_save(1)
	# --- real v1.0 fixture end to end
	DirAccess.copy_absolute(FIX + "legacy_v1_level1.save", SCRATCH + "/level_1.save")
	var facts := _facts("legacy_v1_level1")
	runner.check(Game.has_save(1), "A3: the real v1.0 save is offered for Continue")
	ok = await Game.resume(1)
	await TestUtil.frames(get_tree(), 5)
	runner.check(ok and Game.running and Game.st != null, "A3: resuming the real v1.0 save loads the level")
	if Game.st != null:
		runner.check(Game.st.solved_count == int(facts.solved), "A3: progress restored from the v1.0 save (%d solved)" % Game.st.solved_count)
		runner.check(Game.st.held_by(Game.me()) == [int(facts.host_held)], "A4: the host's carried item is back in the host's hands")
		var stray := 0
		for it in Game.st.items:
			if it.holder != 0 and it.holder != Game.me():
				stray += 1
		runner.check(stray == 0, "A4: nothing is left held by an unknown peer")
	runner.check(FileAccess.file_exists(SCRATCH + "/level_1.save.v1.bak"), "A3: the original v1.0 file was backed up")
	var after := SaveMigration.read(SCRATCH + "/level_1.save")
	runner.check(after.status == SaveMigration.Status.OK, "A3: the save was rewritten in the new format")
	var bak := SaveMigration.read(SCRATCH + "/level_1.save.v1.bak")
	runner.check(bak.status == SaveMigration.Status.LEGACY, "A3: the backup is still a valid v1.0 save")
	# a second resume of the migrated file keeps the same progress
	main.leave_to_menu()
	await TestUtil.frames(get_tree(), 3)
	ok = await Game.resume(1)
	await TestUtil.frames(get_tree(), 5)
	runner.check(ok and Game.st.solved_count == int(facts.solved) and Game.st.held_by(Game.me()) == [int(facts.host_held)], "A3: the migrated save resumes with the same progress and carried items")
	main.leave_to_menu()
	await TestUtil.frames(get_tree(), 3)
	Game.save_dir = "user://saves"
	main.queue_free()
	await TestUtil.frames(get_tree(), 2)

# ---------------------------------------------------------------- B15 autosave, B13 clock
func _autosave_and_clock() -> void:
	_clean_scratch()
	var main := await TestUtil.boot(get_tree(), 1)
	Game.save_dir = SCRATCH
	var st: LevelState = Game.st
	runner.check(not Game.autosave_if_due(Game.AUTOSAVE_SECONDS + 1.0), "B15: nothing changed -> no autosave")
	runner.check(not Game.has_save_file(1), "B15: ...and no file written for an untouched level")
	var uid: int = TestUtil.free_cases(st, 1)[0]
	Game.request_grab(uid)
	await TestUtil.frames(get_tree(), 2)
	runner.check(not Game.autosave_if_due(5.0), "B15: a change alone does not save before the interval")
	runner.check(Game.autosave_if_due(Game.AUTOSAVE_SECONDS + 1.0), "B15: a change + the interval -> autosave written")
	var info := Game.save_info(1)
	runner.check(info.status == SaveMigration.Status.OK, "B15: the autosave is a valid, resumable save")
	runner.check(not Game.autosave_if_due(Game.AUTOSAVE_SECONDS + 1.0), "B15: no second save without a new change")
	Game.finished = true
	Game.request_release(uid, Transform3D(Basis(), Vector3(1, 0.1, 1)), Vector3.ZERO, Vector3.ZERO)
	await TestUtil.frames(get_tree(), 2)
	runner.check(not Game.autosave_if_due(Game.AUTOSAVE_SECONDS + 1.0), "B15: a finished level is never autosaved")
	Game.finished = false
	runner.check(not FileAccess.file_exists(SCRATCH + "/level_1.save.tmp"), "B15: no temp file is left behind")
	# an interrupted write cannot destroy the previous save: the temp file is separate
	var before := FileAccess.get_file_as_bytes(SCRATCH + "/level_1.save")
	var tmp := FileAccess.open(SCRATCH + "/level_1.save.tmp", FileAccess.WRITE)
	tmp.store_string("half written")
	tmp.close()
	runner.check(Game.save_info(1).status == SaveMigration.Status.OK and FileAccess.get_file_as_bytes(SCRATCH + "/level_1.save") == before, "B15: a stray half-written temp file does not affect the real save")
	# --- B13: the clock advances every frame and ev_time only corrects it
	var e0: float = st.elapsed
	await TestUtil.frames(get_tree(), 20)
	runner.check(st.elapsed > e0, "B13: the clock advances between syncs")
	st.elapsed = 10.0
	Game.ev_time(10.4)
	runner.check(is_equal_approx(st.elapsed, 10.2), "B13: a small drift is blended, not snapped (%.2f)" % st.elapsed)
	Game.ev_time(30.0)
	runner.check(is_equal_approx(st.elapsed, 30.0), "B13: a big difference snaps to the host's time")
	Game.save_dir = "user://saves"
	await TestUtil.shutdown(get_tree(), main)
