extends Node
## Headless co-op test driver (run by tools/net_test.sh):
##   host:     --nettest-host        hosts, starts level 1 once client 1 is ready, solves a product
##   client 1: --nettest-client=1    joins before start, solves another product, contests a grab
##   client 2: --nettest-client=2    joins LATE (mid-level, full state sync), contests the same
##                                   grab, swaps a wrong disc, throws an item
## Each process writes tests/out/net_<role>.txt with a state checksum; the script compares them.

var mode := ""
var role := "host"
var idx := 0
var log_lines: Array = []

func _ready() -> void:
	if mode.begins_with("--nettest-client="):
		idx = int(mode.substr(17))
		role = "client%d" % idx
	get_tree().create_timer(110.0).timeout.connect(func(): _finish("TIMEOUT"))
	await get_tree().create_timer(0.5).timeout
	if role == "host":
		await _host()
	else:
		await _client()

func _l(s: String) -> void:
	log_lines.append(s)
	print("[%s] %s" % [role, s])

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _host() -> void:
	Profile.nickname = "Host Bean"
	if not Net.host():
		_finish("HOST_FAILED")
		return
	_l("hosting, code %s" % Net.room_code())
	while not (Net.players.size() >= 2 and Net.all_ready()):
		await _wait(0.2)
	_l("starting with %d players" % Net.players.size())
	Game.main.host_start(1)
	await Game.level_loaded
	await _wait(4.0)
	await _solve_index(0)
	Game.request_emote("dance")
	await _until(40.0)
	_finish("DONE", false)
	await _wait(5.0)
	get_tree().quit(0)

func _client() -> void:
	Profile.nickname = "Client %d" % idx
	if idx == 2:
		await _wait(9.0)  # late join: the level is already running
	Net.join("127.0.0.1", Net.PORT)
	await Net.joined_ok
	_l("joined")
	Net.set_ready(true)
	if not Game.running:
		await Game.level_loaded
	await _wait(3.0)
	_l("level running, items %d, solved %d" % [Game.st.items.size(), Game.st.solved_count])
	if idx == 1 and "--net-shot" in OS.get_cmdline_user_args():
		await _wait(1.0)
		var host_r = Game.remotes.get(1)
		if host_r:
			var me_p: Player = Game.local_player
			var hp: Vector3 = host_r.global_position
			me_p.global_position = hp + Vector3(0.2, 0, 1.6)
			me_p.look_yaw = atan2(-(hp.x - me_p.global_position.x), -(hp.z - me_p.global_position.z))
			me_p.look_pitch = -0.2
			Game.request_emote("wave")
			await _wait(1.0)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://tests/out/net_shot.png")
			_l("saved net shot")
	# B13: the client HUD clock must advance every frame, not in 2 s steps
	var seen := {}
	for i in 45:
		await get_tree().process_frame
		seen[snappedf(Game.st.elapsed, 0.0001)] = true
	_l("clock_distinct=%d" % seen.size())
	if idx == 1:
		await _solve_index(1)
	# contested grab: both clients try to grab the same item at the same moment
	var contested := _pick_contested()
	await _wait(maxf(0.1, 16.0 - Game.st.elapsed))
	_l("contesting uid %d" % contested)
	Game.request_grab(contested)
	await _wait(1.5)
	_l("holder of contested = %d (me %d)" % [Game.st.items[contested].holder, Game.me()])
	if idx == 2:
		await _swap_wrong_disc()
		await _throw_something()
	await _wait(6.0)
	if Game.st.items[contested].holder == Game.me():
		Game.request_release(contested, Transform3D(Basis(), Game.local_player.global_position + Vector3(0, 1, 0)), Vector3.ZERO, Vector3.ZERO)
	await _until(40.0)
	_finish("DONE")

func _until(t: float) -> void:
	while Game.st == null or Game.st.elapsed < t:
		await _wait(0.1)

func _pick_contested() -> int:
	for it in Game.st.items:
		if it.kind == Defs.K_CASE and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0 and not it.open:
			return it.uid
	return 0

func _candidates() -> Array:
	var out: Array = []
	for p in Game.st.products:
		if p.solved or p.edition == Defs.E_CE:
			continue
		var root: LevelState.Item = Game.st.items[p.root]
		if root.stash >= 0 or root.holder != 0:
			continue
		var ok := true
		for d in p.discs:
			if Game.st.items[d].stash >= 0:
				ok = false
		if ok:
			out.append(p)
	return out

func _solve_index(i: int) -> void:
	var c := _candidates()
	if c.size() <= i:
		_l("no candidate %d" % i)
		return
	var p: Dictionary = c[i]
	_l("solving pid %d %s" % [p.pid, Catalog.titles[p.title].name])
	var st: LevelState = Game.st
	var root: int = p.root
	Game.request_grab(root)
	await _wait(0.4)
	if st.items[root].holder != Game.me():
		_l("grab failed")
		return
	Game.request_open(root, true)
	await _wait(0.3)
	for cu in Array(st.items[root].contents):
		if not (p.discs as Array).has(cu) and not (p.pieces as Array).has(cu):
			Game.request_eject(root, Transform3D(Basis(), Game.local_player.global_position + Vector3(0.3, 1.0, 0)))
			await _wait(0.3)
	for d in p.discs:
		if st.items[d].parent == root:
			continue
		var par: int = st.items[d].parent
		if par >= 0 and not st.items[par].open:
			Game.request_open(par, true)
			await _wait(0.3)
		Game.request_insert(d, root)
		await _wait(0.3)
	for pc in p.pieces:
		if st.items[pc].parent != root:
			Game.request_insert(pc, root)
			await _wait(0.3)
	Game.request_open(root, false)
	await _wait(0.3)
	Game.request_shelve(root, p.bucket, Game.local_player.hold_point.global_transform)
	await _wait(0.5)
	_l("pid %d solved=%s" % [p.pid, str(st.products[p.pid].solved)])

func _swap_wrong_disc() -> void:
	# find a case holding someone else's disc, take it out, put it where it belongs
	var st: LevelState = Game.st
	for p in st.products:
		var box: LevelState.Item = st.items[p.disc_box]
		if box.holder != 0 or box.bucket >= 0 or box.stash >= 0 or box.parent >= 0:
			continue
		for cu in box.contents:
			if not (p.discs as Array).has(cu):
				var target := st.correct_container_for(cu)
				var t: LevelState.Item = st.items[target]
				if t.holder != 0 or t.stash >= 0 or t.parent >= 0 and not st.items[t.parent].open:
					continue
				_l("swap: disc %d from case %d to case %d" % [cu, box.uid, target])
				Game.request_open(box.uid, true)
				Game.request_open(target, true)
				await _wait(0.4)
				Game.request_insert(cu, target)
				await _wait(0.4)
				_l("swap result parent=%d" % st.items[cu].parent)
				return

func _throw_something() -> void:
	var st: LevelState = Game.st
	for it in st.items:
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0:
			Game.request_grab(it.uid)
			await _wait(0.4)
			Game.request_release(it.uid, Transform3D(Basis(), Game.local_player.global_position + Vector3(0, 1.2, 0)), Vector3(0, 3, -3), Vector3.ONE)
			_l("threw disc %d" % it.uid)
			return

func _finish(status: String, quit := true) -> void:
	var st: LevelState = Game.st
	var lines := ["status=%s" % status]
	if st:
		lines.append("checksum=%d" % st.checksum())
		lines.append("solved=%d" % st.solved_count)
		lines.append("players=%d" % Net.players.size())
		var held := []
		for it in st.items:
			if it.holder != 0:
				held.append("%d:%d" % [it.uid, it.holder])
		lines.append("held=%s" % ",".join(held))
	lines.append_array(log_lines)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var f := FileAccess.open("res://tests/out/net_%s.txt" % role, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("[%s] finished %s" % [role, status])
	if quit or status == "TIMEOUT":
		get_tree().quit(0)
