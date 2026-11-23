extends Node
## Session orchestrator. Owns the current level (layout, LevelState, ItemWorld, players) and is the
## single entry point for item actions. The host is authoritative: clients call request_*(), the
## host validates and broadcasts compact events (ev_*) that every peer applies to its LevelState.
## Solo play runs the same code with an OfflineMultiplayerPeer (we are the server).

signal level_loaded
signal level_unloaded
signal progress_changed
signal toast_requested(text: String)
signal chat_received(name: String, text: String)
signal results_ready(data: Dictionary)
signal load_progress(frac: float, text: String)
signal player_list_changed
signal scanner_changed

const PLAYER_SCENE := preload("res://scripts/player/player.gd")
const REMOTE_SCENE := preload("res://scripts/player/remote_player.gd")
const SNAP_HZ := 15.0
const STATE_HZ := 20.0
const SCANNER_TIME := 8.0
const SCANNER_COOLDOWN := 20.0

var main: Node                   # scenes/main.gd
var level_def := {}
var layout: LevelLayout
var st: LevelState
var world: ItemWorld
var level_root: Node3D
var local_player: Player
var remotes := {}                # peer -> RemotePlayer
var built := {}                  # WorldBuilder output
var running := false
var finished := false
var ui_blocking := false
var level_seed := 0
var scanner_t := 0.0
var scanner_cd := 0.0
var _snap_t := 0.0
var _state_t := 0.0
var _time_sync_t := 0.0
var _bucket_grid := {}
var _scanner_marker: MeshInstance3D
var _highlighted := -1
var carts := {}                  # uid -> CartNode
var _dist_sent := 0.0
var _dist_t := 0.0
var _cart_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func me() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

# ======================================================================== level lifecycle
## Host / solo: start a level and tell clients to load it.
func host_start_level(id: int, seed := -1, resume_bytes := PackedByteArray()) -> void:
	if seed < 0:
		seed = randi() % 100000 + 1
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		ev_load_level.rpc(id, seed, Settings.get_value("warehouse_items"))
	await load_level(id, seed, Settings.get_value("warehouse_items"))
	if resume_bytes.size() > 0:
		st.deserialize(resume_bytes)
		world.clear_all()
		for it in st.items:
			world._dirty[it.uid] = true
		progress_changed.emit()
		# clients that finished loading first got the fresh state: resend the resumed one
		if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			ev_full_state.rpc(st.serialize(), _active_list())
	# give clients the authoritative state once they finished loading (they ask via srv_ready)

@rpc("authority", "call_remote", "reliable")
func ev_load_level(id: int, seed: int, wh_items: int) -> void:
	await load_level(id, seed, wh_items)
	srv_client_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func srv_client_ready() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not is_host() or st == null:
		return
	ev_full_state.rpc_id(peer, st.serialize(), _active_list())

func _active_list() -> Array:
	var out: Array = []
	for uid in world.bodies:
		out.append([uid, world.bodies[uid].global_transform])
	return out

@rpc("authority", "call_remote", "reliable")
func ev_full_state(bytes: PackedByteArray, active: Array) -> void:
	if st == null:
		return
	world.clear_all()
	st.deserialize(bytes)
	for it in st.items:
		it.active = false
		world._dirty[it.uid] = true
	for a in active:
		world.activate(a[0], a[1])
	progress_changed.emit()
	_refresh_stash_visuals()

func load_level(id: int, seed: int, wh_items := 400) -> void:
	unload_level()
	level_seed = seed
	level_def = Levels.get_def(id, wh_items, seed)
	load_progress.emit(0.05, "Generating the mess...")
	await get_tree().process_frame
	layout = Layouts.build(level_def, seed)
	st = MessGen.build(level_def, layout, seed)
	st.product_changed.connect(_on_product_changed)
	load_progress.emit(0.15, "Painting cover art...")
	var cb := func(f, t): load_progress.emit(0.15 + f * 0.6, t)
	Covers.progress.connect(cb)
	await Covers.build_level_atlases(st)
	Covers.progress.disconnect(cb)
	Covers.set_dust(0.6 if level_def.layout == "attic" else 0.0)
	load_progress.emit(0.8, "Building the room...")
	await get_tree().process_frame
	level_root = Node3D.new()
	level_root.name = "Level"
	main.world_holder.add_child(level_root)
	built = WorldBuilder.build(level_root, layout, st, seed)
	world = ItemWorld.new()
	world.name = "Items"
	level_root.add_child(world)
	world.setup(st, is_host())
	world.body_hit.connect(_on_body_hit)
	if level_def.layout == "store" or level_def.layout == "warehouse":
		world.ACTIVATE_R = 1.7
		world.MAX_ACTIVE = 70
	_build_bucket_grid()
	carts.clear()
	for it in st.items:
		if it.kind == Defs.K_CART:
			var cn := CartNode.new()
			cn.uid = it.uid
			level_root.add_child(cn)
			cn.global_transform = it.xf
			carts[it.uid] = cn
	_spawn_local_player()
	for peer in Net.players:
		if peer != me():
			_spawn_remote(peer)
	_make_scanner_marker()
	load_progress.emit(1.0, "Ready!")
	running = true
	finished = false
	_dist_sent = 0.0
	scanner_t = 0.0
	scanner_cd = 0.0
	Sfx.play_music(int(level_def.get("music", 0)))
	level_loaded.emit()
	progress_changed.emit()

func unload_level() -> void:
	running = false
	carts.clear()
	if level_root:
		level_root.queue_free()
	level_root = null
	local_player = null
	remotes.clear()
	world = null
	st = null
	_scanner_marker = null
	level_unloaded.emit()

func _spawn_local_player() -> void:
	var p := PLAYER_SCENE.new()
	p.name = "Player_%d" % me()
	p.peer_id = me()
	level_root.add_child(p)
	var idx := Net.player_index(me())
	var sp: Vector3 = layout.spawns[idx % layout.spawns.size()] if not layout.spawns.is_empty() else Vector3.ZERO
	p.global_position = sp + Vector3(0, 0.05, 0)
	if not layout.mirror.is_empty():
		var to: Vector3 = layout.mirror.pos - sp
		p.look_yaw = atan2(-to.x, -to.z) + 0.6
	local_player = p
	if st.hands.has(me()):
		pass

func _spawn_remote(peer: int) -> void:
	if remotes.has(peer) or level_root == null:
		return
	var r := REMOTE_SCENE.new()
	r.name = "Remote_%d" % peer
	r.peer_id = peer
	level_root.add_child(r)
	r.apply_look(Net.players.get(peer, {}).get("look", {}))
	remotes[peer] = r

func on_peer_joined_level(peer: int) -> void:
	_spawn_remote(peer)

func on_peer_left(peer: int) -> void:
	var at: Vector3 = layout.spawns[0] if layout and not layout.spawns.is_empty() else Vector3.ZERO
	if remotes.has(peer):
		at = remotes[peer].global_position
		remotes[peer].queue_free()
		remotes.erase(peer)
	if is_host() and st:
		var i := 0
		for uid in st.held_by(peer).duplicate():
			var xf := Transform3D(Basis(), at + Vector3(0, 0.8 + i * 0.05, 0))
			ev_release.rpc(uid, xf, Vector3.ZERO, Vector3.ZERO, peer)
			i += 1

# ======================================================================== per-frame
func _process(delta: float) -> void:
	if not running or st == null:
		return
	if is_host() and not finished:
		st.elapsed += delta
		_time_sync_t -= delta
		if _time_sync_t <= 0.0 and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_time_sync_t = 2.0
			ev_time.rpc(st.elapsed)
	# host: player positions for activation
	if is_host() and world:
		var ps: Array = []
		if local_player:
			ps.append(local_player.global_position + Vector3(0, 0.3, 0))
		for r in remotes.values():
			ps.append(r.global_position + Vector3(0, 0.3, 0))
		world.players = ps
		_snap_t -= delta
		if _snap_t <= 0.0 and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			_snap_t = 1.0 / SNAP_HZ
			var snap := world.pack_snapshot()
			if (snap[0] as PackedInt32Array).size() > 0:
				ev_snap.rpc(snap[0], snap[1])
	# each peer reports its walked distance for the results screen
	_dist_t -= delta
	if _dist_t <= 0.0 and local_player and not finished:
		_dist_t = 4.0
		var d := local_player.distance_walked - _dist_sent
		if d > 0.5:
			_dist_sent = local_player.distance_walked
			_call_host("stat_self", ["distance", d])
	# scanner
	if scanner_cd > 0.0:
		scanner_cd -= delta
	if scanner_t > 0.0:
		scanner_t -= delta
		if scanner_t <= 0.0:
			scanner_changed.emit()
	_update_scanner_visual()

@rpc("authority", "call_remote", "unreliable_ordered")
func ev_time(t: float) -> void:
	if st:
		st.elapsed = t

@rpc("authority", "call_remote", "unreliable")
func ev_snap(uids: PackedInt32Array, data: PackedFloat32Array) -> void:
	if world:
		world.apply_snapshot(uids, data)

func on_item_activated(uid: int, xf: Transform3D) -> void:
	pass # clients create puppets lazily from snapshots / release events

func on_item_rest(uid: int, xf: Transform3D) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		ev_rest.rpc(uid, xf)

@rpc("authority", "call_remote", "reliable")
func ev_rest(uid: int, xf: Transform3D) -> void:
	if world == null:
		return
	if world.puppets.has(uid):
		world.deactivate(uid)
	st.op_move(uid, xf)
	world._dirty[uid] = true

# ======================================================================== carts
## Called every physics frame by the pushing player: move locally, sync at 10 Hz.
func local_cart_move(uid: int, xf: Transform3D) -> void:
	st.op_cart_move(uid, xf)
	_cart_t -= get_physics_process_delta_time()
	if _cart_t > 0.0 or not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	_cart_t = 0.1
	if is_host():
		ev_cart.rpc(uid, xf)
	else:
		rq_cart.rpc_id(1, uid, xf)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rq_cart(uid: int, xf: Transform3D) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if st and _held_by(peer, uid):
		st.op_cart_move(uid, xf)
		ev_cart.rpc(uid, xf)

@rpc("authority", "call_remote", "unreliable_ordered")
func ev_cart(uid: int, xf: Transform3D) -> void:
	if st and st.items[uid].holder != me():
		st.op_cart_move(uid, xf)

# ======================================================================== player state sync
func send_player_state(p: Player) -> void:
	_state_t -= get_physics_process_delta_time()
	if _state_t > 0.0 or not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	_state_t = 1.0 / STATE_HZ
	var flags := 0
	if p.crouching: flags |= 1
	if p.sprinting: flags |= 2
	if p.slipping > 0.0: flags |= 4
	if p.flashlight_on: flags |= 8
	if not p.held().is_empty(): flags |= 16
	ps_update.rpc(p.global_position, p.look_yaw, p.look_pitch, p.velocity, flags)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func ps_update(pos: Vector3, yaw: float, pitch: float, vel: Vector3, flags: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if remotes.has(peer):
		remotes[peer].net_update(pos, yaw, pitch, vel, flags)

# ======================================================================== requests (any peer -> host)
func _call_host(method: String, args: Array) -> void:
	if is_host():
		callv("_srv_" + method, [me()] + args)
	else:
		callv("rpc_id", [1, "rq_" + method] + args)

func request_grab(uid: int) -> void: _call_host("grab", [uid])
func request_release(uid: int, xf: Transform3D, vel: Vector3, ang: Vector3) -> void: _call_host("release", [uid, xf, vel, ang])
func request_insert(child: int, cont: int) -> void: _call_host("insert", [child, cont])
func request_eject(cont: int, out_xf: Transform3D) -> void: _call_host("eject", [cont, out_xf])
func request_open(uid: int, open: bool) -> void: _call_host("open", [uid, open])
func request_flip(uid: int) -> void: _call_host("flip", [uid])
func request_shelve(uid: int, bid: int, from_xf: Transform3D) -> void: _call_host("shelve", [uid, bid, from_xf])
func request_table(uid: int, table: int, cell: int, from_xf: Transform3D) -> void: _call_host("table", [uid, table, cell, from_xf])
func request_reveal(stash: int) -> void: _call_host("reveal", [stash])
func request_bump(target: int, push: Vector3) -> void: _call_host("bump", [target, push])
func request_emote(e: String) -> void: _call_host("emote", [e])
func request_chat(text: String) -> void: _call_host("chat", [text])

func request_kick(pos: Vector3, vel: Vector3) -> void:
	if is_host():
		_srv_kick(me(), pos, vel)
	else:
		rq_kick.rpc_id(1, pos, vel)

@rpc("any_peer", "call_remote", "reliable") func rq_grab(uid: int) -> void: _srv_grab(multiplayer.get_remote_sender_id(), uid)
@rpc("any_peer", "call_remote", "reliable") func rq_release(uid: int, xf: Transform3D, vel: Vector3, ang: Vector3) -> void: _srv_release(multiplayer.get_remote_sender_id(), uid, xf, vel, ang)
@rpc("any_peer", "call_remote", "reliable") func rq_insert(child: int, cont: int) -> void: _srv_insert(multiplayer.get_remote_sender_id(), child, cont)
@rpc("any_peer", "call_remote", "reliable") func rq_eject(cont: int, out_xf: Transform3D) -> void: _srv_eject(multiplayer.get_remote_sender_id(), cont, out_xf)
@rpc("any_peer", "call_remote", "reliable") func rq_open(uid: int, open: bool) -> void: _srv_open(multiplayer.get_remote_sender_id(), uid, open)
@rpc("any_peer", "call_remote", "reliable") func rq_flip(uid: int) -> void: _srv_flip(multiplayer.get_remote_sender_id(), uid)
@rpc("any_peer", "call_remote", "reliable") func rq_shelve(uid: int, bid: int, from_xf: Transform3D) -> void: _srv_shelve(multiplayer.get_remote_sender_id(), uid, bid, from_xf)
@rpc("any_peer", "call_remote", "reliable") func rq_table(uid: int, table: int, cell: int, from_xf: Transform3D) -> void: _srv_table(multiplayer.get_remote_sender_id(), uid, table, cell, from_xf)
@rpc("any_peer", "call_remote", "reliable") func rq_reveal(stash: int) -> void: _srv_reveal(multiplayer.get_remote_sender_id(), stash)
@rpc("any_peer", "call_remote", "reliable") func rq_bump(target: int, push: Vector3) -> void: _srv_bump(multiplayer.get_remote_sender_id(), target, push)
@rpc("any_peer", "call_remote", "reliable") func rq_emote(e: String) -> void: _srv_emote(multiplayer.get_remote_sender_id(), e)
@rpc("any_peer", "call_remote", "reliable") func rq_chat(text: String) -> void: _srv_chat(multiplayer.get_remote_sender_id(), text)
@rpc("any_peer", "call_remote", "unreliable") func rq_kick(pos: Vector3, vel: Vector3) -> void: _srv_kick(multiplayer.get_remote_sender_id(), pos, vel)

# ======================================================================== host validation
func _held_by(peer: int, uid: int) -> bool:
	return st != null and uid >= 0 and uid < st.items.size() and st.items[uid].holder == peer

func _srv_grab(peer: int, uid: int) -> void:
	if st == null or uid < 0 or uid >= st.items.size():
		return
	var it: LevelState.Item = st.items[uid]
	if it.holder != 0 or it.stash >= 0:
		return  # someone else already has it: grab ownership is first-come on the host
	if it.kind == Defs.K_CART and not st.held_by(peer).is_empty():
		return
	if it.parent >= 0 and st.items[it.parent].kind != Defs.K_CART and not st.items[it.parent].open:
		return
	var h := st.held_by(peer)
	if not h.is_empty():
		var top: LevelState.Item = st.items[h[h.size() - 1]]
		var stackable := (top.kind == Defs.K_CASE or top.kind == Defs.K_CEBOX) and not top.open and (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX) and not it.open
		if not stackable or h.size() >= Player.MAX_STACK:
			return
	ev_grab.rpc(uid, peer)

func _srv_release(peer: int, uid: int, xf: Transform3D, vel: Vector3, ang: Vector3) -> void:
	if not _held_by(peer, uid):
		return
	ev_release.rpc(uid, xf, vel.limit_length(12.0), ang, peer)

func _srv_insert(peer: int, child: int, cont: int) -> void:
	if st == null or not st.can_insert(child, cont):
		return
	var c: LevelState.Item = st.items[child]
	var k: LevelState.Item = st.items[cont]
	# must hold one of them (or both are within reach — trust the client for distance in co-op)
	if c.holder != 0 and c.holder != peer:
		return
	if k.holder != 0 and k.holder != peer:
		return
	ev_insert.rpc(child, cont, peer)

func _srv_eject(peer: int, cont: int, out_xf: Transform3D) -> void:
	if st == null or cont < 0 or cont >= st.items.size():
		return
	var k: LevelState.Item = st.items[cont]
	if k.holder != 0 and k.holder != peer:
		return
	if k.contents.is_empty() or not k.open:
		return
	ev_eject.rpc(cont, out_xf, peer)

func _srv_open(peer: int, uid: int, open: bool) -> void:
	if st == null or uid < 0 or uid >= st.items.size():
		return
	var it: LevelState.Item = st.items[uid]
	if it.holder != 0 and it.holder != peer:
		return
	if it.bucket >= 0:
		return
	ev_open.rpc(uid, open)

func _srv_flip(peer: int, uid: int) -> void:
	if st == null or uid < 0 or uid >= st.items.size():
		return
	var it: LevelState.Item = st.items[uid]
	if it.holder != 0 or it.parent >= 0 or it.bucket >= 0:
		return
	var xf: Transform3D = world.bodies[uid].global_transform if world.bodies.has(uid) else it.xf
	xf.basis = Basis(Vector3.RIGHT, PI) * xf.basis
	xf.origin.y += 0.03
	ev_flip.rpc(uid, xf)

func _srv_shelve(peer: int, uid: int, bid: int, from_xf: Transform3D) -> void:
	if not _held_by(peer, uid) or bid < 0 or bid >= st.buckets.size():
		return
	if not st.bucket_has_room(bid, uid):
		return
	ev_shelve.rpc(uid, bid, peer, from_xf)

func _srv_table(peer: int, uid: int, table: int, cell: int, from_xf: Transform3D) -> void:
	if not _held_by(peer, uid) or table < 0 or table >= st.tables.size():
		return
	if (st.tables[table].occupied as Dictionary).has(cell):
		return
	ev_table.rpc(uid, table, cell, from_xf)

func _srv_reveal(peer: int, stash: int) -> void:
	if st == null or stash < 0 or stash >= st.stashes.size() or st.stashes[stash].revealed:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	ev_reveal.rpc(stash, st.spill_positions(stash, rng))

func _srv_bump(peer: int, target: int, push: Vector3) -> void:
	ev_bump.rpc(target, push.limit_length(7.0), peer)

func _srv_emote(peer: int, e: String) -> void:
	ev_emote.rpc(peer, e.left(16))

func _srv_chat(peer: int, text: String) -> void:
	ev_chat.rpc(peer, text.left(60))

func _srv_kick(peer: int, pos: Vector3, vel: Vector3) -> void:
	if world:
		world.kick_near(pos, vel)

# ======================================================================== events (host -> all)
@rpc("authority", "call_local", "reliable")
func ev_grab(uid: int, peer: int) -> void:
	if st == null:
		return
	if st.items[uid].active:
		world.deactivate(uid)
	var parent: int = st.items[uid].parent
	st.op_grab(uid, peer)
	if parent >= 0:
		world.refresh_visual(parent)
	_sfx_at("grab", uid, peer)
	if peer == me():
		_haptic(15)

@rpc("authority", "call_local", "reliable")
func ev_release(uid: int, xf: Transform3D, vel: Vector3, ang: Vector3, peer: int) -> void:
	if st == null:
		return
	st.op_release(uid, xf)
	if st.items[uid].kind == Defs.K_CART:
		Sfx.play("thud", xf.origin)
		return
	world.activate(uid, xf, vel, ang)

@rpc("authority", "call_local", "reliable")
func ev_insert(child: int, cont: int, peer: int) -> void:
	if st == null:
		return
	if st.items[child].active:
		world.deactivate(child)
	var correct := st.correct_container_for(child) == cont
	st.op_insert(child, cont)
	world.refresh_visual(cont)
	var it: LevelState.Item = st.items[child]
	if it.kind == Defs.K_DISC or it.kind == Defs.K_CASE or it.product >= 0:
		_stat(peer, "mistakes" if not correct else "matched", 1)
	Sfx.play("disc_in" if it.kind == Defs.K_DISC else "click", st.world_xf(st.root_of(cont)).origin, 1.0 if correct else 0.85)
	if peer == me():
		_haptic(25)
		if correct and Settings.get_value("casual_scanner"):
			toast("Match!")

@rpc("authority", "call_local", "reliable")
func ev_eject(cont: int, out_xf: Transform3D, peer: int) -> void:
	if st == null:
		return
	var c := st.op_eject(cont, 0, out_xf)
	world.refresh_visual(cont)
	if c >= 0:
		world.activate(c, out_xf, (out_xf.basis.z * -0.3) + Vector3(0, 1.0, 0))
		Sfx.play("pop", out_xf.origin)

@rpc("authority", "call_local", "reliable")
func ev_open(uid: int, open: bool) -> void:
	if st == null:
		return
	st.op_set_open(uid, open)
	world.refresh_visual(uid)
	Sfx.play("case_open" if open else "case_close", st.world_xf(st.root_of(uid)).origin if st.items[uid].holder == 0 else _holder_pos(uid))

@rpc("authority", "call_local", "reliable")
func ev_flip(uid: int, xf: Transform3D) -> void:
	if st == null:
		return
	var it: LevelState.Item = st.items[uid]
	if world.bodies.has(uid):
		var b: RigidBody3D = world.bodies[uid]
		b.global_transform = xf
		b.sleeping = false
	elif world.puppets.has(uid):
		world.puppets[uid].target = xf
	it.xf = xf
	world._dirty[uid] = true
	Sfx.play("flip", xf.origin)

@rpc("authority", "call_local", "reliable")
func ev_shelve(uid: int, bid: int, peer: int, from_xf: Transform3D) -> void:
	if st == null:
		return
	var b: Dictionary = st.buckets[bid]
	var before := {}
	for u in b.items:
		before[u] = st.items[u].xf
	var p: int = st.items[uid].product
	var was_solved: bool = p >= 0 and st.products[p].solved
	st.op_shelve(uid, bid)
	world.animate_from(uid, from_xf, 0.22)
	for u in before:
		if st.items[u].xf.origin.distance_to(before[u].origin) > 0.002:
			world.animate_from(u, before[u], 0.16)
	var correct := st.correct_bucket_for(uid) == bid
	if p >= 0 and st.products[p].solved and not was_solved:
		_stat(peer, "sorted", 1)
		Sfx.play("snap_good", st.world_xf(uid).origin)
		_sparkle(st.world_xf(uid).origin)
	elif not correct:
		_stat(peer, "mistakes", 1)
		Sfx.play("snap", st.world_xf(uid).origin, 0.9)
	else:
		Sfx.play("snap", st.world_xf(uid).origin)
	if peer == me():
		_haptic(30)

@rpc("authority", "call_local", "reliable")
func ev_table(uid: int, table: int, cell: int, from_xf: Transform3D) -> void:
	if st == null:
		return
	st.op_table(uid, table, cell)
	world.animate_from(uid, from_xf, 0.2)
	Sfx.play("place", st.world_xf(uid).origin)

@rpc("authority", "call_local", "reliable")
func ev_reveal(stash: int, xfs: Array) -> void:
	if st == null:
		return
	var freed := st.op_reveal(stash, xfs)
	var node: Node3D = built.stash_nodes.get(stash)
	if node:
		_animate_stash(node, st.stashes[stash].type)
	for i in freed.size():
		var xf: Transform3D = xfs[i] if i < xfs.size() else Transform3D()
		world.activate(freed[i], xf, Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
	Sfx.play("reveal", st.stashes[stash].pos)
	toast("Found %d hidden item%s!" % [freed.size(), "" if freed.size() == 1 else "s"])

@rpc("authority", "call_local", "reliable")
func ev_bump(target: int, push: Vector3, from: int) -> void:
	Sfx.play("bonk", _player_pos(target))
	if target == me() and local_player:
		local_player.apply_bump(push)
		_haptic(40)
	elif remotes.has(target):
		remotes[target].bean.bump(2.0)
	if remotes.has(from):
		remotes[from].bean.bump(1.0)

@rpc("authority", "call_local", "reliable")
func ev_emote(peer: int, e: String) -> void:
	if peer == me() and local_player:
		local_player.bean.play_emote(e)
	elif remotes.has(peer):
		remotes[peer].bean.play_emote(e)
	Sfx.play("emote", _player_pos(peer))

@rpc("authority", "call_local", "reliable")
func ev_chat(peer: int, text: String) -> void:
	var n: String = Net.players.get(peer, {}).get("name", Profile.nickname if peer == me() else "?")
	chat_received.emit(n, text)
	if remotes.has(peer):
		remotes[peer].say(text)
	Sfx.play("chat", Vector3.ZERO)

@rpc("authority", "call_local", "reliable")
func ev_stat(peer: int, key: String, amount: float) -> void:
	if st == null:
		return
	var k := str(peer)
	if not st.stats.has(k):
		st.stats[k] = {"name": Net.players.get(peer, {}).get("name", Profile.nickname), "sorted": 0, "mistakes": 0, "slips": 0, "distance": 0.0, "throws": 0, "matched": 0}
	st.stats[k][key] = st.stats[k].get(key, 0) + amount

func _stat(peer: int, key: String, amount: float) -> void:
	if is_host():
		ev_stat.rpc(peer, key, amount)

func on_local_slip(p: Player) -> void:
	_call_host("stat_self", ["slips", 1.0])
	Sfx.play("slip", p.global_position)
	_haptic(60)

func on_local_throw() -> void:
	_call_host("stat_self", ["throws", 1.0])

func _srv_stat_self(peer: int, key: String, amount: float) -> void:
	if key in ["slips", "throws", "distance"]:
		ev_stat.rpc(peer, key, amount)

@rpc("any_peer", "call_remote", "reliable")
func rq_stat_self(key: String, amount: float) -> void:
	_srv_stat_self(multiplayer.get_remote_sender_id(), key, amount)

# ======================================================================== progress / completion
func _on_product_changed(pid: int, solved: bool) -> void:
	progress_changed.emit()
	if is_host() and running and not finished and st.solved_count >= st.products.size():
		_finish()

func _finish() -> void:
	finished = true
	if local_player:
		_stat(me(), "distance", local_player.distance_walked - _dist_sent)
		_dist_sent = local_player.distance_walked
	ev_complete.rpc(st.elapsed)

@rpc("authority", "call_local", "reliable")
func ev_complete(time: float) -> void:
	finished = true
	if st:
		st.elapsed = time
	await get_tree().create_timer(1.2).timeout
	if st == null:
		return
	var players := maxi(1, Net.players.size())
	var par := Levels.par_seconds(level_def, players)
	var mistakes := 0
	for k in st.stats:
		mistakes += int(st.stats[k].get("mistakes", 0))
	var stars := 1
	if time <= par * 1.35:
		stars = 2
	if time <= par and mistakes <= maxi(3, st.products.size() / 25):
		stars = 3
	if level_def.id <= 5:
		Profile.record_result(level_def.id, stars, time)
	else:
		Profile.record_result(level_def.id, stars, time)
	Sfx.play("jingle", Vector3.ZERO)
	results_ready.emit({"time": time, "par": par, "stars": stars, "stats": st.stats.duplicate(true), "level": level_def, "products": st.products.size()})

func progress_text() -> String:
	if st == null:
		return ""
	return "%d / %d" % [st.solved_count, st.products.size()]

func hidden_count() -> int:
	var n := 0
	if st:
		for s in st.stashes:
			n += (s.items as Array).size()
	return n

# ======================================================================== scanner
func use_scanner() -> void:
	if Settings.get_value("casual_scanner"):
		toast("Casual mode: scanner is always on")
		return
	if scanner_cd > 0.0:
		toast("Scanner recharging... %ds" % ceili(scanner_cd))
		Sfx.play("error", Vector3.ZERO)
		return
	scanner_t = SCANNER_TIME
	scanner_cd = SCANNER_COOLDOWN
	Sfx.play("scanner", Vector3.ZERO)
	scanner_changed.emit()

func scanner_active() -> bool:
	return scanner_t > 0.0 or bool(Settings.get_value("casual_scanner"))

func scanner_target() -> Dictionary:
	## Where the held item belongs: {"bucket": bid} or {"item": uid}
	if local_player == null or st == null:
		return {}
	var top := local_player.top_held()
	if top < 0:
		return {}
	var it: LevelState.Item = st.items[top]
	var cont := st.correct_container_for(top)
	if cont >= 0 and it.parent != cont:
		return {"item": cont}
	if it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX:
		var p: Dictionary = st.products[it.product]
		if top == p.root:
			# first: the case should be complete
			for d in p.discs:
				if st.items[d].parent != p.disc_box:
					return {"item": d}
			for pc in p.pieces:
				if st.items[pc].parent != p.root:
					return {"item": pc}
			if p.edition == Defs.E_CE and st.items[p.disc_box].parent != p.root:
				return {"item": p.disc_box}
			return {"bucket": p.bucket}
	return {}

func _make_scanner_marker() -> void:
	_scanner_marker = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	_scanner_marker.mesh = bm
	var m: ShaderMaterial = WorldBuilder.mat("ghost").duplicate()
	m.set_shader_parameter("color", Color(0.4, 1.0, 0.5))
	_scanner_marker.material_override = m
	_scanner_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scanner_marker.visible = false
	level_root.add_child(_scanner_marker)

func _update_scanner_visual() -> void:
	if _scanner_marker == null or not is_instance_valid(_scanner_marker):
		return
	var tgt := scanner_target() if scanner_active() else {}
	if _highlighted >= 0 and st and _highlighted < st.items.size():
		if not tgt.has("item") or tgt.item != _highlighted:
			st.items[_highlighted].flags &= ~2
			world._dirty[_highlighted] = true
			_highlighted = -1
	if tgt.has("bucket"):
		var b: Dictionary = st.buckets[tgt.bucket]
		_scanner_marker.visible = true
		_scanner_marker.global_transform = (b.xf as Transform3D) * Transform3D(Basis().scaled(Vector3(b.width, b.height, b.depth)), Vector3(b.width * 0.5, b.height * 0.5, -b.depth * 0.5))
	else:
		_scanner_marker.visible = false
	if tgt.has("item") and _highlighted != tgt.item:
		_highlighted = tgt.item
		st.items[_highlighted].flags |= 2
		world._dirty[_highlighted] = true

# ======================================================================== helpers
func _build_bucket_grid() -> void:
	_bucket_grid.clear()
	for b in st.buckets:
		var c := (b.xf as Transform3D) * Vector3(b.width * 0.5, 0, 0)
		var key := Vector2i(floori(c.x / 2.0), floori(c.z / 2.0))
		if not _bucket_grid.has(key):
			_bucket_grid[key] = []
		_bucket_grid[key].append(b)

func bucket_cache_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(floori((p.x - r) / 2.0), floori((p.z - r) / 2.0))
	var c1 := Vector2i(floori((p.x + r) / 2.0), floori((p.z + r) / 2.0))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			out.append_array(_bucket_grid.get(Vector2i(x, z), []))
	return out

func item_title(uid: int) -> String:
	var it: LevelState.Item = st.items[uid]
	if it.product < 0:
		return Defs.KIND_NAMES[it.kind]
	var p: Dictionary = st.products[it.product]
	var t: Dictionary = Catalog.titles[p.title]
	if it.kind == Defs.K_DISC and it.parent < 0 and it.xf.basis.y.y < -0.2 and it.holder == 0:
		return "Disc (face down)"
	return t.name

func item_detail(uid: int) -> String:
	var it: LevelState.Item = st.items[uid]
	if it.product < 0:
		return ""
	var p: Dictionary = st.products[it.product]
	var t: Dictionary = Catalog.titles[p.title]
	if it.kind == Defs.K_DISC and it.parent < 0 and it.xf.basis.y.y < -0.2 and it.holder == 0:
		return "Flip or inspect it to read the label"
	var kind: String = Defs.KIND_NAMES[it.kind]
	if it.kind == Defs.K_CASE:
		kind = Defs.FORMAT_NAMES[it.fmt]
	var ed: String = Defs.EDITION_NAMES[p.edition]
	var extra := ""
	if it.kind == Defs.K_DISC and int(t.discs) > 1:
		extra = " · Disc %d/%d" % [it.sub + 1, t.discs]
	elif (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX):
		var n := 0
		for c in it.contents:
			if st.items[c].kind == Defs.K_DISC:
				n += 1
		extra = " · %s" % ("empty" if it.contents.is_empty() else "%d inside" % it.contents.size())
	return "%s · %s · %s%s" % [Defs.PLATFORMS[t.platform].name, ed, kind, extra]

func _holder_pos(uid: int) -> Vector3:
	return _player_pos(st.items[uid].holder)

func _player_pos(peer: int) -> Vector3:
	if peer == me() and local_player:
		return local_player.global_position
	if remotes.has(peer):
		return remotes[peer].global_position
	return Vector3.ZERO

func _sfx_at(name: String, uid: int, peer: int) -> void:
	Sfx.play(name, _player_pos(peer))

func _on_body_hit(uid: int, speed: float) -> void:
	if speed > 1.2:
		var it: LevelState.Item = st.items[uid]
		Sfx.play("clink" if it.kind == Defs.K_DISC else "thud", world.bodies[uid].global_position if world.bodies.has(uid) else Vector3.ZERO, randf_range(0.9, 1.2), clampf(-18.0 + speed * 4.0, -18.0, 0.0))

func _sparkle(pos: Vector3) -> void:
	if level_root == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.3, 1.15, 0.5)
	sm.material = mat
	p.mesh = sm
	level_root.add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _animate_stash(node: Node3D, type: String) -> void:
	var body := node.get_node_or_null("Body") as Node3D
	var sp := node.get_node_or_null("Sparkle")
	if sp:
		sp.queue_free()
	if body == null:
		return
	var tw := node.create_tween()
	match type:
		"beanbag", "dust_sheet":
			tw.tween_property(body, "position", Vector3(0, 0.35, 0.3), 0.15)
			tw.parallel().tween_property(body, "scale", Vector3(1.2, 0.7, 1.2), 0.15)
			tw.tween_property(body, "position", Vector3(0.0, 0, -0.35), 0.25)
			tw.parallel().tween_property(body, "scale", Vector3(1, 1, 1), 0.25)
		"dresser", "nightstand", "trunk", "suitcase":
			tw.tween_property(body, "position", Vector3(0, 0, 0.12), 0.12)
			tw.tween_property(body, "position", Vector3(0, 0, 0), 0.2)
		_:
			tw.tween_property(body, "rotation", Vector3(0, 0, 0.15), 0.1)
			tw.tween_property(body, "rotation", Vector3(0, 0, -0.1), 0.1)
			tw.tween_property(body, "rotation", Vector3.ZERO, 0.15)

func _refresh_stash_visuals() -> void:
	for s in st.stashes:
		if s.revealed and built.stash_nodes.has(s.id):
			var sp = built.stash_nodes[s.id].get_node_or_null("Sparkle")
			if sp:
				sp.queue_free()

func toast(text: String) -> void:
	toast_requested.emit(text)

func _haptic(ms: int) -> void:
	if Settings.get_value("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ======================================================================== save / resume
func save_path(level_id: int) -> String:
	return "user://saves/level_%d.save" % level_id

func save_game() -> bool:
	if not is_host() or st == null:
		return false
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(save_path(level_def.id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var({"level": level_def.id, "seed": level_seed, "state": st.serialize(), "version": Defs.CATALOG_VERSION,
		"wh": Settings.get_value("warehouse_items"), "date": Time.get_datetime_string_from_system()})
	toast("Game saved")
	return true

func has_save(level_id: int) -> bool:
	return FileAccess.file_exists(save_path(level_id))

func load_save(level_id: int) -> Dictionary:
	var f := FileAccess.open(save_path(level_id), FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != Defs.CATALOG_VERSION:
		return {}
	return d

func delete_save(level_id: int) -> void:
	if has_save(level_id):
		DirAccess.remove_absolute(save_path(level_id))

func resume(level_id: int) -> void:
	var d := load_save(level_id)
	if d.is_empty():
		return
	Settings.values["warehouse_items"] = d.get("wh", 400)
	await host_start_level(level_id, int(d.seed), d.state)
