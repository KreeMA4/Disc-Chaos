class_name SaveMigration
extends RefCounted
## Save-file compatibility (M1 / audit A3, A4, C1).
##
## v1.0 wrote  {level, seed, state, version = CATALOG_VERSION, wh, date}  where the state stored the
## *peer ids* of whoever was holding items. Peer ids are random per multiplayer session, so those
## items could never be picked up again after a resume.
##
## Format 2 adds  "format": 2  and stores holders as player *slots* (host = slot 0). Nothing else in
## the file changes, so a format-1 save of the same catalog version is read as "legacy", restored
## through the same slot logic (host-held items stay with the host; items held by a client are put
## back on the floor where they were picked up) and rewritten as format 2 on the first save, with
## the original kept next to it as level_N.save.v1.bak.
##
## Saves made with another catalog version cannot be rebuilt (the catalog generator, layouts and the
## mess generator are seeded and versioned together), so they are kept untouched on disk but reported
## as not resumable; the level menu offers to discard them.

const FORMAT := 2
const MAX_STATE_BYTES := 32 * 1024 * 1024

enum Status { OK, LEGACY, MISSING, CORRUPT, STALE, FUTURE }

## Reads and validates only the header of a save file. Returns
## {status: Status, data: Dictionary (empty unless resumable), format: int, catalog: int, message: String}.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(Status.MISSING)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _result(Status.CORRUPT)
	var d = f.get_var()   # objects are never decoded
	f.close()
	return inspect(d)

static func inspect(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return _result(Status.CORRUPT)
	for k in ["level", "seed", "version"]:
		if typeof(d.get(k)) != TYPE_INT:
			return _result(Status.CORRUPT)
	var state = d.get("state")
	if typeof(state) != TYPE_PACKED_BYTE_ARRAY or (state as PackedByteArray).size() < 8:
		return _result(Status.CORRUPT)
	var raw_size: int = (state as PackedByteArray).decode_u32(0)
	if raw_size == 0 or raw_size > MAX_STATE_BYTES:
		return _result(Status.CORRUPT)
	var format: int = int(d.get("format", 1))
	var catalog: int = int(d.version)
	if format > FORMAT or catalog > Defs.CATALOG_VERSION:
		return _result(Status.FUTURE, format, catalog)
	if catalog != Defs.CATALOG_VERSION:
		return _result(Status.STALE, format, catalog)
	return _result(Status.OK if format >= FORMAT else Status.LEGACY, format, catalog, d)

static func is_resumable(info: Dictionary) -> bool:
	return info.status == Status.OK or info.status == Status.LEGACY

static func _result(status: int, format := 0, catalog := 0, data := {}) -> Dictionary:
	return {"status": status, "format": format, "catalog": catalog, "data": data, "message": message_for(status)}

static func message_for(status: int) -> String:
	match status:
		Status.STALE: return "This save was made with an older version of the levels and can't be continued."
		Status.FUTURE: return "This save was made by a newer version of the game."
		Status.CORRUPT: return "This save file is damaged and can't be continued."
		Status.MISSING: return "No saved game found."
	return ""

## Copies a file next to itself as <path>.v1.bak unless a backup already exists.
static func backup_legacy(path: String) -> bool:
	var bak := path + ".v1.bak"
	if FileAccess.file_exists(bak) or not FileAccess.file_exists(path):
		return false
	return DirAccess.copy_absolute(path, bak) == OK

## Writes a save dictionary atomically (temp file + rename) so a crash mid-write cannot destroy the
## previous save.
static func write_atomic(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	var err := f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return DirAccess.rename_absolute(tmp, path) == OK
