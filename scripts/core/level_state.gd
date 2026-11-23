class_name LevelState
extends RefCounted
## Authoritative data model for a level: every item (case, disc, box, piece, cart), what contains
## what, which shelf bucket holds what, hidden stashes and per-product solve state.
## All gameplay mutations go through the op_* functions so host, clients and the bot solver share
## identical rules. Pure data: no nodes, safe to run headless.

signal item_changed(uid: int)          # any state change that needs a visual refresh
signal product_changed(pid: int, solved: bool)
signal bucket_changed(bid: int)

class Item:
	var uid := 0
	var kind := 0
	var product := -1
	var sub := 0              # disc index for discs
	var fmt := 0              # case format (platform format) for sizing
	var xf := Transform3D()   # world transform, or local transform when parent >= 0
	var parent := -1
	var contents := PackedInt32Array()
	var open := false
	var holder := 0           # peer id holding it (0 = none)
	var bucket := -1          # shelf bucket id
	var table := -1           # sort table cell code (table*100 + cell)
	var stash := -1           # hidden stash id
	var active := false       # runtime: simulated as a physics body (host) / interpolated puppet (client)
	var flags := 0

var level_id := 0
var seed := 0
var items: Array = []         # Array[Item], index == uid
var products: Array = []      # {pid, title, edition, root, disc_box, discs:[], pieces:[], bucket, sort, fmt, solved}
var sections: Array = []      # {id, label, platform, kind, buckets:[], color}
var buckets: Array = []       # {id, section, label, xf, width, depth, height, items:[], unit, row}
var stashes: Array = []       # {id, items:[], revealed, spill:Vector3, type}
var tables: Array = []        # {id, xf, cells: Vector2i, cell_size: Vector2, occupied: {cell: uid}}
var solved_count := 0
var hands := {}               # peer -> Array[int] held uids in pick-up order (top = last)
var stats := {}               # player name -> {sorted, mistakes, slips, distance, throws}
var elapsed := 0.0

var _hash := {}               # Vector2i -> PackedInt32Array-ish Array of uids (pickable spatial index)
var _hash_of := {}            # uid -> Vector2i
const HASH_CELL := 1.0

# =============================================================== creation helpers
func new_item(kind: int, product: int, fmt: int, sub := 0) -> Item:
	var it := Item.new()
	it.uid = items.size()
	it.kind = kind
	it.product = product
	it.fmt = fmt
	it.sub = sub
	items.append(it)
	return it

func item(uid: int) -> Item:
	return items[uid] if uid >= 0 and uid < items.size() else null

# =============================================================== geometry
func size_of(it: Item) -> Vector3:
	return Defs.item_size(it.kind, it.fmt)

## Local AABB including the flipped-open front panel of open cases.
func local_aabb(it: Item) -> AABB:
	var s := size_of(it)
	if it.kind == Defs.K_CART:
		return AABB(Vector3(-s.x * 0.5, 0.0, -s.z * 0.5), s)
	var box := AABB(-s * 0.5, s)
	if not it.open:
		return box
	if it.kind == Defs.K_CASE and is_flip_case(it):
		box = AABB(Vector3(-s.x * 1.5 - s.z, -s.y * 0.5, -s.z * 0.5), Vector3(s.x * 2.0 + s.z, s.y, s.z * 0.5))
	elif it.kind == Defs.K_CEBOX or it.kind == Defs.K_CASE:
		box = box.expand(Vector3(0, s.y * 0.5 + s.z, -s.z * 0.5))
	return box

## Small cases open like a book (front panel flips to the left); big boxes open a lid.
static func is_flip_case(it) -> bool:
	return it.fmt in [Defs.F_MODERN, Defs.F_HANDHELD, Defs.F_MINI, Defs.F_JEWEL]

func world_xf(uid: int) -> Transform3D:
	var it: Item = items[uid]
	if it.parent >= 0:
		return world_xf(it.parent) * it.xf
	return it.xf

## True when the item is directly visible in the world (not inside a closed container/stash/hand).
func is_visible(uid: int) -> bool:
	var it: Item = items[uid]
	if it.stash >= 0:
		return false
	if it.holder != 0 and it.kind != Defs.K_CART:
		return false
	if it.parent >= 0:
		var p: Item = items[it.parent]
		if p.kind != Defs.K_CART and not p.open:
			return false
		return is_visible(p.uid)
	return true

## Container whose transform drives this item (top-most parent).
func root_of(uid: int) -> int:
	var u := uid
	while items[u].parent >= 0:
		u = items[u].parent
	return u

# =============================================================== container rules
func capacity_ok(child: Item, cont: Item) -> bool:
	if child.uid == cont.uid:
		return false
	var counts := {}
	for c in cont.contents:
		var k: int = items[c].kind
		counts[k] = counts.get(k, 0) + 1
	var have: int = counts.get(child.kind, 0)
	match cont.kind:
		Defs.K_CASE:
			if child.kind == Defs.K_DISC:
				return have < _disc_cap(cont)
			if child.kind == Defs.K_MANUAL and cont.fmt == Defs.F_BIGBOX:
				return have < 1
			return false
		Defs.K_CEBOX:
			if child.kind in [Defs.K_CASE, Defs.K_ARTBOOK, Defs.K_FIGURE, Defs.K_POSTER]:
				if child.kind == Defs.K_CASE and child.fmt != Defs.F_MODERN and child.fmt != Defs.F_JEWEL:
					return false
				return have < 1
			return false
		Defs.K_CART:
			if child.kind == Defs.K_CART:
				return false
			return cont.contents.size() < 30
	return false

func _disc_cap(cont: Item) -> int:
	if cont.product >= 0:
		return maxi(2, (products[cont.product].discs as Array).size())
	return 2

func needs_open(cont: Item) -> bool:
	return cont.kind != Defs.K_CART

func can_insert(child_uid: int, cont_uid: int) -> bool:
	var child := item(child_uid)
	var cont := item(cont_uid)
	if child == null or cont == null:
		return false
	if needs_open(cont) and not cont.open:
		return false
	if child.kind == Defs.K_CART:
		return false
	# no cycles
	var u := cont_uid
	while u >= 0:
		if u == child_uid:
			return false
		u = items[u].parent
	return capacity_ok(child, cont)

## Local transform for the n-th child of a container.
func slot_xf(cont: Item, child: Item, index: int) -> Transform3D:
	var s := size_of(cont)
	match cont.kind:
		Defs.K_CASE:
			if child.kind == Defs.K_DISC:
				var dz := -s.z * 0.5 + 0.004 + index * 0.0045
				var off := Vector3(0.0, 0.0, dz)
				if index > 0:
					off.x += 0.012 * index
					off.y -= 0.008 * index
				return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), off)
			# manual in big box
			return Transform3D(Basis(), Vector3(0, 0, s.z * 0.5 - 0.012))
		Defs.K_CEBOX:
			match child.kind:
				Defs.K_CASE:
					var cs := size_of(child)
					return Transform3D(Basis(), Vector3(-s.x * 0.5 + cs.x * 0.5 + 0.015, -s.y * 0.5 + cs.y * 0.5 + 0.01, s.z * 0.5 - cs.z * 0.5 - 0.01))
				Defs.K_ARTBOOK:
					var asz: Vector3 = Defs.PIECE_SIZE[Defs.K_ARTBOOK]
					return Transform3D(Basis(), Vector3(-s.x * 0.5 + asz.x * 0.5 + 0.02, -s.y * 0.5 + asz.y * 0.5 + 0.01, -s.z * 0.5 + asz.z * 0.5 + 0.01))
				Defs.K_FIGURE:
					return Transform3D(Basis(), Vector3(s.x * 0.5 - 0.06, -s.y * 0.5 + 0.09, 0.0))
				Defs.K_POSTER:
					return Transform3D(Basis(), Vector3(s.x * 0.5 - 0.035, 0.0, -s.z * 0.5 + 0.03))
		Defs.K_CART:
			var col := index % 3
			var row := (index / 3) % 5
			var layer := index / 15
			return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.2 + col * 0.2, 0.55 + layer * 0.06, -0.34 + row * 0.17))
	return Transform3D()

func _relayout_contents(cont: Item) -> void:
	for i in cont.contents.size():
		var c: Item = items[cont.contents[i]]
		c.xf = slot_xf(cont, c, i)
		item_changed.emit(c.uid)

# =============================================================== detaching
## Remove an item from wherever it is (container, bucket, table, stash). Leaves xf as world xf.
func detach(uid: int) -> void:
	var it: Item = items[uid]
	var wxf := world_xf(uid)
	if it.parent >= 0:
		var cont: Item = items[it.parent]
		var idx := cont.contents.find(uid)
		if idx >= 0:
			cont.contents.remove_at(idx)
		it.parent = -1
		_relayout_contents(cont)
		_check_product(cont.product)
		_check_owner_products(cont)
	if it.bucket >= 0:
		var b: Dictionary = buckets[it.bucket]
		(b.items as Array).erase(uid)
		it.bucket = -1
		_relayout_bucket(b.id)
	if it.table >= 0:
		var t: Dictionary = tables[it.table / 100]
		(t.occupied as Dictionary).erase(it.table % 100)
		it.table = -1
	if it.stash >= 0:
		(stashes[it.stash].items as Array).erase(uid)
		it.stash = -1
	it.xf = wxf
	_unindex(uid)
	_check_product(it.product)

func held_by(peer: int) -> Array:
	return hands.get(peer, [])

func _unhold(uid: int) -> void:
	var it: Item = items[uid]
	if it.holder != 0:
		var arr: Array = hands.get(it.holder, [])
		arr.erase(uid)
	it.holder = 0

# =============================================================== ops (return true on success)
func op_grab(uid: int, peer: int) -> bool:
	var it := item(uid)
	if it == null or it.holder != 0 or it.stash >= 0:
		return false
	if it.parent >= 0:
		var p: Item = items[it.parent]
		if p.kind != Defs.K_CART and not p.open:
			return false
	detach(uid)
	it.holder = peer
	it.active = false
	if not hands.has(peer):
		hands[peer] = []
	(hands[peer] as Array).append(uid)
	if it.kind != Defs.K_CART:
		_unindex_tree(uid)
	item_changed.emit(uid)
	return true

## Move a cart (pushed by its holder); its contents follow.
func op_cart_move(uid: int, xf: Transform3D) -> void:
	var it := item(uid)
	if it == null or it.kind != Defs.K_CART:
		return
	it.xf = xf
	_index_tree(uid)
	item_changed.emit(uid)

## Release a held item into the world at xf.
func op_release(uid: int, xf: Transform3D) -> bool:
	var it := item(uid)
	if it == null:
		return false
	if it.parent >= 0 or it.bucket >= 0 or it.table >= 0:
		detach(uid)
	_unhold(uid)
	it.xf = xf
	_index_tree(uid)
	item_changed.emit(uid)
	_check_product(it.product)
	return true

## Release everything a peer holds at a position (disconnects, slips).
func release_all(peer: int, at: Vector3) -> Array:
	var out: Array = []
	for uid in (hands.get(peer, []) as Array).duplicate():
		op_release(uid, Transform3D(Basis(), at + Vector3(randf_range(-0.2, 0.2), 0.3 + out.size() * 0.05, randf_range(-0.2, 0.2))))
		out.append(uid)
	return out

## Update a free item's transform (physics/network).
func op_move(uid: int, xf: Transform3D) -> void:
	var it := item(uid)
	if it == null or it.parent >= 0 or it.bucket >= 0 or it.holder != 0:
		return
	it.xf = xf
	_index_tree(uid)

func op_insert(child_uid: int, cont_uid: int) -> bool:
	if not can_insert(child_uid, cont_uid):
		return false
	var child: Item = items[child_uid]
	var cont: Item = items[cont_uid]
	detach(child_uid)
	_unhold(child_uid)
	child.parent = cont_uid
	cont.contents.append(child_uid)
	child.xf = slot_xf(cont, child, cont.contents.size() - 1)
	_unindex_tree(child_uid)
	if is_visible(child_uid):
		_index_tree(child_uid)
	item_changed.emit(child_uid)
	item_changed.emit(cont_uid)
	_check_product(cont.product)
	_check_product(child.product)
	_check_owner_products(cont)
	return true

## Remove the last (or a given) content of an open container; it becomes held by peer, or free at
## out_xf when peer == 0.
func op_eject(cont_uid: int, peer: int, out_xf: Transform3D, which := -1) -> int:
	var cont := item(cont_uid)
	if cont == null or cont.contents.is_empty():
		return -1
	if needs_open(cont) and not cont.open:
		return -1
	var c: int = which if which >= 0 else cont.contents[cont.contents.size() - 1]
	if cont.contents.find(c) < 0:
		return -1
	detach(c)
	var it: Item = items[c]
	if peer != 0:
		it.holder = peer
		if not hands.has(peer):
			hands[peer] = []
		(hands[peer] as Array).append(c)
		_unindex_tree(c)
	else:
		it.xf = out_xf
		_index_tree(c)
	item_changed.emit(c)
	item_changed.emit(cont_uid)
	return c

func op_set_open(uid: int, open: bool) -> bool:
	var it := item(uid)
	if it == null or not (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX):
		return false
	if it.open == open:
		return false
	it.open = open
	# contents visibility changes
	for c in it.contents:
		if open and is_visible(c):
			_index_tree(c)
		else:
			_unindex_tree(c)
		item_changed.emit(c)
	if it.bucket >= 0:
		_relayout_bucket(it.bucket)
	if it.holder == 0 and it.parent < 0 and it.bucket < 0 and it.stash < 0:
		_index(uid)
	item_changed.emit(uid)
	_check_product(it.product)
	_check_owner_products(it)
	return true

## Flip a free item upside down (face-down discs etc.).
func op_flip(uid: int) -> bool:
	var it := item(uid)
	if it == null or it.parent >= 0 or it.bucket >= 0 or it.holder != 0:
		return false
	it.xf.basis = Basis(Vector3.RIGHT, PI) * it.xf.basis
	item_changed.emit(uid)
	return true

## Shelve an item into a bucket; keeps the bucket sorted A-Z. Fails if the bucket is full.
func op_shelve(uid: int, bid: int) -> bool:
	var it := item(uid)
	if it == null or bid < 0 or bid >= buckets.size():
		return false
	if not (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX):
		return false
	var b: Dictionary = buckets[bid]
	if not bucket_has_room(bid, uid):
		return false
	detach(uid)
	_unhold(uid)
	it.open = false if it.kind == Defs.K_CASE else it.open
	it.bucket = bid
	var arr: Array = b.items
	arr.append(uid)
	arr.sort_custom(func(a, c): return sort_key_of(a) < sort_key_of(c))
	_relayout_bucket(bid)
	_check_product(it.product)
	_check_owner_products(it)
	return true

func op_table(uid: int, table_id: int, cell: int) -> bool:
	var it := item(uid)
	if it == null or table_id < 0 or table_id >= tables.size():
		return false
	var t: Dictionary = tables[table_id]
	if (t.occupied as Dictionary).has(cell):
		return false
	detach(uid)
	_unhold(uid)
	it.table = table_id * 100 + cell
	t.occupied[cell] = uid
	it.xf = table_cell_xf(table_id, cell, it)
	_index_tree(uid)
	item_changed.emit(uid)
	return true

## Reveal a stash; returns the freed uids (they become free items at spill positions given).
func op_reveal(stash_id: int, positions: Array) -> Array:
	if stash_id < 0 or stash_id >= stashes.size():
		return []
	var s: Dictionary = stashes[stash_id]
	if s.revealed:
		return []
	s.revealed = true
	var freed: Array = (s.items as Array).duplicate()
	for i in freed.size():
		var it: Item = items[freed[i]]
		it.stash = -1
		it.xf = positions[i] if i < positions.size() else Transform3D(Basis(), s.spill)
		_index_tree(it.uid)
		item_changed.emit(it.uid)
	(s.items as Array).clear()
	return freed

func spill_positions(stash_id: int, rng: RandomNumberGenerator) -> Array:
	var s: Dictionary = stashes[stash_id]
	var out: Array = []
	for i in (s.items as Array).size():
		var a := rng.randf() * TAU
		var r := 0.12 + rng.randf() * 0.35
		var p: Vector3 = s.spill + Vector3(cos(a) * r, 0.15 + i * 0.05, sin(a) * r)
		out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	return out

# =============================================================== buckets / tables
func sort_key_of(uid: int) -> String:
	var it: Item = items[uid]
	if it.product >= 0:
		return products[it.product].sort
	return "~"

func thickness_of(uid: int) -> float:
	return size_of(items[uid]).z + 0.003

func bucket_has_room(bid: int, uid: int) -> bool:
	var b: Dictionary = buckets[bid]
	var used := 0.0
	for u in b.items:
		if u != uid:
			used += thickness_of(u)
	var s := size_of(items[uid])
	if s.y > float(b.height) + 0.001 or s.x > float(b.depth) + 0.04:
		return false
	return used + thickness_of(uid) <= float(b.width) + 0.0001

func bucket_item_xf(bid: int, index: int, uid: int, cursor: float) -> Transform3D:
	var b: Dictionary = buckets[bid]
	var s := size_of(items[uid])
	var t := s.z
	var local := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cursor + t * 0.5, s.y * 0.5 + 0.002, -s.x * 0.5 - 0.015))
	return (b.xf as Transform3D) * local

func _relayout_bucket(bid: int) -> void:
	var b: Dictionary = buckets[bid]
	var cursor := 0.006
	var i := 0
	for u in b.items:
		var it: Item = items[u]
		it.xf = bucket_item_xf(bid, i, u, cursor)
		cursor += thickness_of(u)
		_index_tree(u)
		item_changed.emit(u)
		i += 1
	bucket_changed.emit(bid)

## Where an item would land if shelved now (for the ghost preview).
func preview_xf(bid: int, uid: int) -> Transform3D:
	var b: Dictionary = buckets[bid]
	var arr: Array = (b.items as Array).filter(func(x): return x != uid)
	var key := sort_key_of(uid)
	var cursor := 0.006
	for u in arr:
		if sort_key_of(u) > key:
			break
		cursor += thickness_of(u)
	return bucket_item_xf(bid, 0, uid, cursor)

func table_cell_xf(table_id: int, cell: int, it: Item) -> Transform3D:
	var t: Dictionary = tables[table_id]
	var cells: Vector2i = t.cells
	var cs: Vector2 = t.cell_size
	var cx := cell % cells.x
	var cz := cell / cells.x
	var s := size_of(it)
	var lp := Vector3((cx - (cells.x - 1) * 0.5) * cs.x, float(t.height) + 0.012, (cz - (cells.y - 1) * 0.5) * cs.y)
	var basis := Basis(Vector3.RIGHT, -PI * 0.5)
	var up_extent := s.z
	if it.kind == Defs.K_DISC:
		basis = Basis()
		up_extent = s.y
	elif it.kind == Defs.K_FIGURE or it.kind == Defs.K_CEBOX:
		basis = Basis()
		up_extent = s.y
	lp.y += up_extent * 0.5
	return (t.xf as Transform3D) * Transform3D(basis, lp)

func nearest_free_cell(table_id: int, local_pos: Vector3) -> int:
	var t: Dictionary = tables[table_id]
	var cells: Vector2i = t.cells
	var cs: Vector2 = t.cell_size
	var best := -1
	var bd := 1e9
	for cell in cells.x * cells.y:
		if (t.occupied as Dictionary).has(cell):
			continue
		var cx := cell % cells.x
		var cz := cell / cells.x
		var p := Vector2((cx - (cells.x - 1) * 0.5) * cs.x, (cz - (cells.y - 1) * 0.5) * cs.y)
		var d := p.distance_to(Vector2(local_pos.x, local_pos.z))
		if d < bd:
			bd = d
			best = cell
	return best

# =============================================================== solving
func required_root_contents(p: Dictionary) -> Array:
	var req: Array = []
	if p.edition == Defs.E_CE:
		req.append(p.disc_box)
		req.append_array(p.pieces)
	else:
		req.append_array(p.discs)
		req.append_array(p.pieces) # manuals for big boxes
	return req

func _same_set(a: PackedInt32Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in b:
		if a.find(x) < 0:
			return false
	return true

func is_solved(pid: int) -> bool:
	var p: Dictionary = products[pid]
	var root: Item = items[p.root]
	if root.bucket != p.bucket or root.open or root.holder != 0:
		return false
	if not _same_set(root.contents, required_root_contents(p)):
		return false
	if p.edition == Defs.E_CE:
		var inner: Item = items[p.disc_box]
		if inner.open or not _same_set(inner.contents, p.discs):
			return false
	return true

func _check_product(pid: int) -> void:
	if pid < 0 or pid >= products.size():
		return
	var p: Dictionary = products[pid]
	var now := is_solved(pid)
	if now != p.solved:
		p.solved = now
		solved_count += 1 if now else -1
		product_changed.emit(pid, now)

func _check_owner_products(cont: Item) -> void:
	# A CE inner case change affects the CE product; parent chain products too.
	var u := cont.parent
	while u >= 0:
		_check_product(items[u].product)
		u = items[u].parent

func recheck_all() -> void:
	solved_count = 0
	for p in products:
		p.solved = is_solved(p.pid)
		if p.solved:
			solved_count += 1

func progress() -> float:
	return float(solved_count) / maxf(1.0, products.size())

func section_progress(sid: int) -> Vector2i:
	var done := 0
	var total := 0
	for p in products:
		if buckets[p.bucket].section == sid:
			total += 1
			if p.solved:
				done += 1
	return Vector2i(done, total)

## Is this item, as it currently is, where it belongs? Used for mistake counting & the scanner.
func correct_bucket_for(uid: int) -> int:
	var it: Item = items[uid]
	if it.product < 0:
		return -1
	var p: Dictionary = products[it.product]
	if uid == p.root:
		return p.bucket
	return -1

func correct_container_for(uid: int) -> int:
	var it: Item = items[uid]
	if it.product < 0:
		return -1
	var p: Dictionary = products[it.product]
	if it.kind == Defs.K_DISC:
		return p.disc_box
	if uid != p.root:
		return p.root
	return -1

# =============================================================== spatial index (pick queries)
func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / HASH_CELL), floori(p.z / HASH_CELL))

func _index(uid: int) -> void:
	var c := _cell_of(world_xf(uid).origin)
	if _hash_of.has(uid):
		if _hash_of[uid] == c:
			return
		_unindex(uid)
	if not _hash.has(c):
		_hash[c] = []
	(_hash[c] as Array).append(uid)
	_hash_of[uid] = c

func _unindex(uid: int) -> void:
	if not _hash_of.has(uid):
		return
	var c: Vector2i = _hash_of[uid]
	(_hash[c] as Array).erase(uid)
	_hash_of.erase(uid)

func _index_tree(uid: int) -> void:
	if not is_visible(uid):
		_unindex(uid)
		return
	_index(uid)
	var it: Item = items[uid]
	for c in it.contents:
		_index_tree(c)

func _unindex_tree(uid: int) -> void:
	_unindex(uid)
	for c in items[uid].contents:
		_unindex_tree(c)

func rebuild_index() -> void:
	_hash.clear()
	_hash_of.clear()
	for it in items:
		if is_visible(it.uid):
			_index(it.uid)

func query_box(center: Vector3, radius: float) -> Array:
	var out: Array = []
	var c0 := _cell_of(center - Vector3(radius, 0, radius))
	var c1 := _cell_of(center + Vector3(radius, 0, radius))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			var arr = _hash.get(Vector2i(x, z))
			if arr:
				out.append_array(arr)
	return out

## Ray pick against item OBBs. Returns {uid, dist} or {} .
## A container never shadows what is inside it: when both an item and one of its ancestors
## (cart, open case, open collector's box...) are hit, the ancestor is ignored so the deepest
## item wins. Everything else keeps the old rule (nearest entry wins).
func raycast(from: Vector3, dir: Vector3, max_dist: float, pad := 0.02, exclude := -1) -> Dictionary:
	var hits := {}   # uid -> entry distance
	var mid := from + dir * max_dist * 0.5
	for uid in query_box(mid, max_dist * 0.5 + 0.6):
		if uid == exclude:
			continue
		var it: Item = items[uid]
		if it.holder != 0:
			continue
		var wxf := world_xf(uid)
		var inv := wxf.affine_inverse()
		var lo := inv * from
		var ld := (inv.basis * dir)
		var box := local_aabb(it).grow(pad)
		var hit = _ray_aabb(lo, ld, box)
		if hit != null and hit < max_dist:
			hits[uid] = hit
	if hits.is_empty():
		return {}
	var shadowed := {}
	for uid in hits:
		var par: int = items[uid].parent
		while par >= 0:
			if hits.has(par):
				shadowed[par] = true
			par = items[par].parent
	var best := {}
	var bd := max_dist
	for uid in hits:
		if shadowed.has(uid):
			continue
		if hits[uid] < bd:
			bd = hits[uid]
			best = {"uid": uid, "dist": hits[uid]}
	return best

static func _ray_aabb(o: Vector3, d: Vector3, box: AABB):
	var tmin := -1e9
	var tmax := 1e9
	for a in 3:
		if absf(d[a]) < 1e-8:
			if o[a] < box.position[a] or o[a] > box.end[a]:
				return null
		else:
			var t1 := (box.position[a] - o[a]) / d[a]
			var t2 := (box.end[a] - o[a]) / d[a]
			if t1 > t2:
				var tt := t1; t1 = t2; t2 = tt
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return null
	if tmax < 0.0:
		return null
	return maxf(tmin, 0.0)

# =============================================================== serialization
## Transient visual flags that must never persist in a save (scanner highlight glow).
const TRANSIENT_FLAGS := 2
## Slot recorded for a holder that has no player slot (should not happen; restored to the floor).
const SLOT_LOST := 99
const MAX_RAW_BYTES := 32 * 1024 * 1024

## `slot_of` (peer id -> player slot) switches to *save mode*: holders and hands are stored as
## slot + 1 instead of the session's random peer ids and transient flags are dropped. Without it the
## state is serialized as-is for live network sync.
func serialize(slot_of := Callable()) -> PackedByteArray:
	var saving := slot_of.is_valid()
	var n := items.size()
	var ints := PackedInt32Array()
	ints.resize(n * 8)
	var xfs := PackedFloat32Array()
	xfs.resize(n * 12)
	for i in n:
		var it: Item = items[i]
		ints[i * 8 + 0] = it.parent
		ints[i * 8 + 1] = int(it.open)
		ints[i * 8 + 2] = (0 if it.holder == 0 else int(slot_of.call(it.holder)) + 1) if saving else it.holder
		ints[i * 8 + 3] = it.bucket
		ints[i * 8 + 4] = it.table
		ints[i * 8 + 5] = it.stash
		ints[i * 8 + 6] = (it.flags & ~TRANSIENT_FLAGS) if saving else it.flags
		ints[i * 8 + 7] = 0
		var x := it.xf
		var vals := [x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z,
			x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]
		for k in 12:
			xfs[i * 12 + k] = vals[k]
	var conts := []
	for it in items:
		conts.append(it.contents)
	var bks := []
	for b in buckets:
		bks.append(PackedInt32Array(b.items))
	var sts := []
	for s in stashes:
		sts.append([s.revealed, PackedInt32Array(s.items)])
	var tbs := []
	for t in tables:
		tbs.append(t.occupied)
	var saved_hands := hands
	if saving:
		saved_hands = {}
		for peer in hands:
			var k := int(slot_of.call(peer)) + 1
			if not saved_hands.has(k):
				saved_hands[k] = []
			(saved_hands[k] as Array).append_array(hands[peer])
	var d := {"level": level_id, "seed": seed, "n": n, "ints": ints, "xfs": xfs, "conts": conts,
		"bks": bks, "sts": sts, "tbs": tbs, "stats": stats, "elapsed": elapsed, "hands": saved_hands}
	var raw := var_to_bytes(d)
	var comp := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(comp)
	return out

## Decodes and structurally validates serialized state without touching anything. {} when invalid.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8:
		return {}
	var raw_size := bytes.decode_u32(0)
	if raw_size == 0 or raw_size > MAX_RAW_BYTES:
		return {}
	var raw := bytes.slice(4).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {}
	var d = bytes_to_var(raw)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	for k in ["n", "ints", "xfs", "conts", "bks", "sts", "tbs", "stats", "elapsed"]:
		if not d.has(k):
			return {}
	if typeof(d.n) != TYPE_INT or typeof(d.ints) != TYPE_PACKED_INT32_ARRAY or typeof(d.xfs) != TYPE_PACKED_FLOAT32_ARRAY:
		return {}
	var n: int = d.n
	if (d.ints as PackedInt32Array).size() != n * 8 or (d.xfs as PackedFloat32Array).size() != n * 12:
		return {}
	if typeof(d.conts) != TYPE_ARRAY or (d.conts as Array).size() != n:
		return {}
	for k in ["bks", "sts", "tbs"]:
		if typeof(d[k]) != TYPE_ARRAY:
			return {}
	if typeof(d.stats) != TYPE_DICTIONARY or (typeof(d.elapsed) != TYPE_FLOAT and typeof(d.elapsed) != TYPE_INT):
		return {}
	return d

func deserialize(bytes: PackedByteArray) -> bool:
	var d := decode(bytes)
	if d.is_empty() or int(d.n) != items.size():
		return false
	if (d.bks as Array).size() != buckets.size() or (d.sts as Array).size() != stashes.size() or (d.tbs as Array).size() != tables.size():
		return false
	var ints: PackedInt32Array = d.ints
	var xfs: PackedFloat32Array = d.xfs
	for i in items.size():
		var it: Item = items[i]
		it.parent = ints[i * 8 + 0]
		it.open = ints[i * 8 + 1] != 0
		it.holder = ints[i * 8 + 2]
		it.bucket = ints[i * 8 + 3]
		it.table = ints[i * 8 + 4]
		it.stash = ints[i * 8 + 5]
		it.flags = ints[i * 8 + 6]
		var o := i * 12
		it.xf = Transform3D(Basis(Vector3(xfs[o], xfs[o + 1], xfs[o + 2]), Vector3(xfs[o + 3], xfs[o + 4], xfs[o + 5]),
			Vector3(xfs[o + 6], xfs[o + 7], xfs[o + 8])), Vector3(xfs[o + 9], xfs[o + 10], xfs[o + 11]))
		it.contents = d.conts[i]
		it.active = false
	for bi in buckets.size():
		buckets[bi].items = Array(d.bks[bi])
	for si in stashes.size():
		stashes[si].revealed = d.sts[si][0]
		stashes[si].items = Array(d.sts[si][1])
	for ti in tables.size():
		tables[ti].occupied = d.tbs[ti]
	stats = d.stats
	elapsed = d.elapsed
	hands = d.get("hands", {})
	recheck_all()
	rebuild_index()
	return true

## After deserialize() of a *save file*: turns the stored holders back into this session's peers and
## cleans transient flags. `format` is the save format (1 = legacy peer ids, 2 = player slots),
## `peer_of_slot` maps a player slot to the peer currently playing it, `fallback_xf(uid)` gives a floor
## transform for an item whose holder is not in this session. Returns the uids put back on the floor.
func restore_after_load(format: int, peer_of_slot: Dictionary, fallback_xf: Callable) -> Array:
	var raw_hands := hands
	hands = {}
	var released: Array = []
	for it in items:
		it.flags &= ~TRANSIENT_FLAGS
		if it.holder == 0:
			continue
		var slot := SLOT_LOST
		if format >= 2:
			slot = it.holder - 1
		elif it.holder == 1:
			slot = 0    # legacy: peer 1 is always the host
		var peer: int = peer_of_slot.get(slot, 0)
		if peer != 0:
			it.holder = peer
		else:
			it.holder = 0
			it.active = false
			var xf: Transform3D = fallback_xf.call(it.uid)
			it.xf = xf
			released.append(it.uid)
	# pick-up order: the saved order for each holder, then anything the old order did not list
	for key in raw_hands:
		for uid in (raw_hands[key] as Array):
			if uid >= 0 and uid < items.size() and items[uid].holder != 0:
				var h: int = items[uid].holder
				if not hands.has(h):
					hands[h] = []
				if not (hands[h] as Array).has(uid):
					(hands[h] as Array).append(uid)
	for it in items:
		if it.holder != 0:
			if not hands.has(it.holder):
				hands[it.holder] = []
			if not (hands[it.holder] as Array).has(it.uid):
				(hands[it.holder] as Array).append(it.uid)
	recheck_all()
	rebuild_index()
	return released

func checksum() -> int:
	var h := 0
	for it in items:
		h = hash([h, it.parent, it.open, it.holder, it.bucket, it.table, it.stash, Array(it.contents)])
	for b in buckets:
		h = hash([h, b.items])
	return h
