class_name BotSolver
extends RefCounted
## Solves a LevelState using only the public op_* rules, while estimating human playtime.
## Model: walking at 3.0 m/s with 1.4x path detour, per-action costs, a search overhead per
## item that grows with level size, and stack-carrying up to 5 prepared cases per shelf run.

const WALK := 3.0
const DETOUR := 1.4
const T_GRAB := 0.7
const T_INSERT := 0.9
const T_OPEN := 0.5
const T_SHELVE := 1.1
const T_REVEAL := 1.5
const T_INSPECT := 1.2
const STACK := 5

var st: LevelState
var pos := Vector3.ZERO
var time := 0.0
var walked := 0.0
var actions := 0
var peer := 1
var search_cost := 2.0
var log_errors: Array = []

func _init(state: LevelState, start: Vector3) -> void:
	st = state
	pos = start
	search_cost = 1.6 + 0.9 * log(maxf(1.0, st.items.size() / 100.0) + 1.0)

func _walk_to(p: Vector3) -> void:
	var d := Vector2(pos.x, pos.z).distance_to(Vector2(p.x, p.z)) * DETOUR
	walked += d
	time += d / WALK
	pos = p

func _act(t: float) -> void:
	time += t
	actions += 1

func _where(uid: int) -> Vector3:
	return st.world_xf(st.root_of(uid)).origin

func _err(msg: String) -> void:
	log_errors.append(msg)

func solve() -> bool:
	# reveal all stashes
	for s in st.stashes:
		if not s.revealed and not (s.items as Array).is_empty():
			_walk_to(s.pos)
			_act(T_REVEAL)
			var rng := RandomNumberGenerator.new()
			rng.seed = s.id
			st.op_reveal(s.id, st.spill_positions(s.id, rng))
	var order: Array = st.products.duplicate()
	# nearest-first-ish: sort by distance of root from origin to keep runs local
	var prepared: Array = []
	var remaining := order.filter(func(p): return not p.solved)
	while not remaining.is_empty():
		# pick nearest unsolved product root
		var best = null
		var bd := 1e9
		for p in remaining:
			var d := pos.distance_to(_where(p.root))
			if d < bd:
				bd = d
				best = p
		remaining.erase(best)
		if not _prepare(best):
			return false
		prepared.append(best)
		if prepared.size() >= STACK or remaining.is_empty():
			_deliver(prepared)
			prepared.clear()
	st.recheck_all()
	return st.solved_count == st.products.size()

func _fetch(uid: int) -> bool:
	# get uid into hand: walk there, open its container if needed, grab
	var it: LevelState.Item = st.items[uid]
	if it.holder == peer:
		return true
	_walk_to(_where(uid))
	time += search_cost
	if it.parent >= 0:
		var par: LevelState.Item = st.items[it.parent]
		if par.kind != Defs.K_CART and not par.open:
			# container might itself be shelved / in a box: grab it is not needed, just open in place
			st.op_set_open(par.uid, true)
			_act(T_OPEN)
	if it.kind == Defs.K_DISC and it.parent < 0 and it.xf.basis.y.y < 0.0:
		_act(T_INSPECT) # face-down: needs a look
	if not st.op_grab(uid, peer):
		_err("grab failed uid %d" % uid)
		return false
	_act(T_GRAB)
	return true

func _put_in(child: int, cont: int) -> bool:
	if not st.op_insert(child, cont):
		_err("insert failed %d -> %d" % [child, cont])
		return false
	_act(T_INSERT)
	return true

func _prepare(p: Dictionary) -> bool:
	if p.solved:
		return true
	var root: int = p.root
	if not _fetch(root):
		return false
	# Holding root. Release it in front of us to work (sorting-table style), keeping logic simple.
	st.op_release(root, Transform3D(Basis(), pos + Vector3(0, 0.8, 0)))
	if not st.items[root].open:
		st.op_set_open(root, true)
		_act(T_OPEN)
	var box: int = p.disc_box
	if p.edition == Defs.E_CE:
		# eject anything wrong from the CE box
		for c in Array(st.items[root].contents):
			if c != box and not (p.pieces as Array).has(c):
				st.op_eject(root, 0, Transform3D(Basis(), pos))
				_act(T_GRAB)
		if st.items[box].parent != root:
			if not _fetch(box):
				return false
			_walk_to(st.world_xf(root).origin)
			st.op_release(box, Transform3D(Basis(), pos + Vector3(0.3, 0.8, 0)))
		else:
			st.op_eject(root, 0, Transform3D(Basis(), pos + Vector3(0.3, 0.8, 0)), box)
		_fix_disc_box(p, box, st.world_xf(root).origin)
		if st.items[box].holder == 0 and st.items[box].parent != root:
			st.op_grab(box, peer)
		if not _put_in(box, root):
			return false
		for pc in p.pieces:
			if st.items[pc].parent != root:
				if not _fetch(pc):
					return false
				_walk_to(st.world_xf(root).origin)
				if not _put_in(pc, root):
					return false
	else:
		_fix_disc_box(p, root, st.world_xf(root).origin)
		if not st.items[root].open:
			st.op_set_open(root, true)
		for pc in p.pieces:
			if st.items[pc].parent != root:
				if not _fetch(pc):
					return false
				_walk_to(st.world_xf(root).origin)
				if not _put_in(pc, root):
					return false
	st.op_set_open(root, false)
	_act(T_OPEN)
	st.op_grab(root, peer)
	return true

func _fix_disc_box(p: Dictionary, box: int, home: Vector3) -> void:
	if not st.items[box].open:
		st.op_set_open(box, true)
		_act(T_OPEN)
	for c in Array(st.items[box].contents):
		if not (p.discs as Array).has(c):
			st.op_eject(box, 0, Transform3D(Basis(), pos + Vector3(0.5, 0.02, 0)), c)
			_act(T_GRAB)
	for d in p.discs:
		if st.items[d].parent == box:
			continue
		if not _fetch(d):
			return
		_walk_to(home)
		_put_in(d, box)
	st.op_set_open(box, false)
	_act(T_OPEN)

func _deliver(prepared: Array) -> void:
	var left := prepared.duplicate()
	while not left.is_empty():
		var best = null
		var bd := 1e9
		for p in left:
			var bp: Vector3 = (st.buckets[p.bucket].xf as Transform3D).origin
			var d := pos.distance_to(bp)
			if d < bd:
				bd = d
				best = p
		left.erase(best)
		var b: Dictionary = st.buckets[best.bucket]
		_walk_to((b.xf as Transform3D).origin)
		# make room: remove wrong items occupying the bucket if needed
		if not st.bucket_has_room(b.id, best.root):
			for u in (b.items as Array).duplicate():
				if st.correct_bucket_for(u) != b.id:
					st.op_grab(u, peer)
					st.op_release(u, Transform3D(Basis(), pos + Vector3(0, 0.05, 0.6)))
					_act(T_GRAB)
					if st.bucket_has_room(b.id, best.root):
						break
		if not st.op_shelve(best.root, b.id):
			_err("shelve failed pid %d bucket %d" % [best.pid, b.id])
		_act(T_SHELVE)
