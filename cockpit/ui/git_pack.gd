extends RefCounted
class_name GitPack
## ONE COMMIT'S OWN TIME, READ OUT OF A CHECKOUT'S `.git` WITH NO GIT PROCESS: the object store, loose or packed.
##
## Asked for on 2026-09-19: every build carries the time it was built, so two machines can say which is newer and by how
## much. A release has it baked (`BuildPlate.TIME_SETTING`). A DEV RUN has nothing baked, and the honest time for a dev
## tree is its commit's: the same on every machine at that commit, so two lanes at one commit agree to the second, where
## the day the game ran (what the dev line said until now) or the time HEAD moved (the reflog) differ by machine.
##
## WHY NOT ASK GIT. `git status` cost 65 to 187 ms a boot on this repo (lane/buildtag, 2026-09-18), and every suite boots
## the game. A `git log -1 --format=%ct` is the same process start. This reads the commit the way git does, from files:
##
##   LOOSE: `objects/ab/cdef...`, one zlib stream, "commit <size>\0tree ...\ncommitter Name <mail> 1758290000 +0100\n".
##   PACKED: every `objects/pack/*.idx` (version 2), a binary search of its sorted names for the pack offset, and the
##   object at that offset -- whole, or a DELTA against another object (an offset back in the same pack, or a name).
##
## PACKED IS THE COMMON CASE HERE, NOT A CORNER: on 2026-09-19 the shared repo held no loose objects at all, and 1,156
## of its 3,624 packed commits (32 %) were deltas (`git verify-pack -v`). A reader that gave up on a delta would have
## said "unknown" for a third of the commits a lane could be at. `tests/build_time.gd` reads forty commits back from
## HEAD and checks each against `git log --format=%ct`, which is how a delta chain gets exercised at all.
##
## THE ZLIB TRAP: `PackedByteArray.decompress_dynamic` loops for ever on a stream with bytes after its end (its inner
## loop waits for input or output to run out, and zlib at stream end consumes neither: `core/io/compression.cpp`), and
## an object in a pack is always followed by the next one. So a packed object is inflated with `decompress` to the exact
## size its header gives, which stops at the end of the stream; only a loose file, which holds one stream and nothing
## after it, goes through `decompress_dynamic`.

## Object types in a pack's entry header.
const COMMIT: int = 1
const OFS_DELTA: int = 6
const REF_DELTA: int = 7
## How deep a delta chain may go before the reader gives up. git's own default `--depth` is 50.
const DEEPEST: int = 64
## What an `.idx` of version 2 starts with: "\xfftOc", then the version.
const IDX_MAGIC: int = 0xff744f63


## THE COMMITTER TIME OF `hash`, epoch seconds UTC, from the object store under `common` (the repo's own `.git`, which a
## worktree's `commondir` names), or 0 when it cannot be read. 0 is "unknown": a caller shows no date rather than a wrong
## one, and the handshake says the build did not say when it was made.
static func commit_time(common: String, hash: String) -> int:
	var found: Dictionary = read_object(common, hash)
	if int(found.get("type", 0)) != COMMIT:
		return 0
	var text: String = (found["data"] as PackedByteArray).get_string_from_utf8()
	for row in text.split("\n"):
		if row.is_empty():
			break
		if row.begins_with("committer "):
			# "committer Name <mail> 1758290000 +0100": the time is the second word from the end, and it is UTC.
			var words: PackedStringArray = row.split(" ")
			if words.size() >= 3 and words[words.size() - 2].is_valid_int():
				return int(words[words.size() - 2])
	return 0


## ONE OBJECT BY ITS NAME: {type, data}, whole (any delta applied), or {} when it is in neither the loose store nor a pack.
static func read_object(common: String, hash: String) -> Dictionary:
	hash = hash.to_lower()
	if hash.length() != 40 or not hash.is_valid_hex_number(false):
		return {}
	var objects: String = common.path_join("objects")
	var loose: String = objects.path_join(hash.substr(0, 2)).path_join(hash.substr(2))
	if FileAccess.file_exists(loose):
		return _read_loose(loose)
	var packs: String = objects.path_join("pack")
	for file in DirAccess.get_files_at(packs):
		if not file.ends_with(".idx"):
			continue
		var at: int = _offset_in(packs.path_join(file), hash)
		if at < 0:
			continue
		var pack := FileAccess.open(packs.path_join(file.get_basename() + ".pack"), FileAccess.READ)
		if pack == null:
			continue
		var found: Dictionary = _unpack(pack, at, common, 0)
		pack.close()
		return found
	return {}


static func _read_loose(path: String) -> Dictionary:
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		return {}
	var whole: PackedByteArray = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	var nul: int = whole.find(0)
	if nul < 0:
		return {}
	var head: PackedStringArray = whole.slice(0, nul).get_string_from_ascii().split(" ")
	var types: Dictionary = {"commit": COMMIT, "tree": 2, "blob": 3, "tag": 4}
	return {"type": int(types.get(head[0], 0)), "data": whole.slice(nul + 1)}


## WHERE `hash` IS IN THE PACK THIS `.idx` INDEXES, in bytes, or -1. Version 2 only: magic, version, 256 fan-out counts,
## the sorted names, their CRCs, their 31-bit offsets, and 64-bit offsets for any past 2 GB.
static func _offset_in(idx_path: String, hash: String) -> int:
	var idx := FileAccess.open(idx_path, FileAccess.READ)
	if idx == null:
		return -1
	idx.big_endian = true
	if idx.get_32() != IDX_MAGIC or idx.get_32() != 2:
		return -1
	var first: int = hash.substr(0, 2).hex_to_int()
	var fanout: int = 8
	idx.seek(fanout + 4 * 255)
	var count: int = idx.get_32()
	var low: int = 0
	if first > 0:
		idx.seek(fanout + 4 * (first - 1))
		low = idx.get_32()
	idx.seek(fanout + 4 * first)
	var high: int = idx.get_32()
	var names: int = fanout + 1024
	while low < high:
		var middle: int = (low + high) / 2
		idx.seek(names + 20 * middle)
		var here: String = idx.get_buffer(20).hex_encode()
		if here == hash:
			idx.seek(names + 24 * count + 4 * middle)
			var offset: int = idx.get_32()
			if offset & 0x80000000:
				idx.seek(names + 28 * count + 8 * (offset & 0x7fffffff))
				offset = idx.get_64()
			return offset
		if here < hash:
			low = middle + 1
		else:
			high = middle
	return -1


## THE OBJECT AT `offset` IN AN OPEN PACK, whole: its type and its bytes, a delta put back together against its base.
static func _unpack(pack: FileAccess, offset: int, common: String, depth: int) -> Dictionary:
	if depth > DEEPEST or offset <= 0 or offset >= pack.get_length():
		return {}
	pack.seek(offset)
	var byte: int = pack.get_8()
	var type: int = (byte >> 4) & 7
	var size: int = byte & 15
	var shift: int = 4
	while byte & 0x80:
		byte = pack.get_8()
		size |= (byte & 0x7f) << shift
		shift += 7
	if type >= 1 and type <= 4:
		var data: PackedByteArray = _inflate(pack, size)
		return {"type": type, "data": data} if data.size() == size else {}
	var base: Dictionary = {}
	if type == OFS_DELTA:
		byte = pack.get_8()
		var back: int = byte & 0x7f
		while byte & 0x80:
			byte = pack.get_8()
			back = ((back + 1) << 7) | (byte & 0x7f)
		var delta: PackedByteArray = _inflate(pack, size)
		base = _unpack(pack, offset - back, common, depth + 1)
		return _patched(base, delta, size)
	if type == REF_DELTA:
		var name: String = pack.get_buffer(20).hex_encode()
		var delta: PackedByteArray = _inflate(pack, size)
		base = read_object(common, name) if depth < DEEPEST else {}
		return _patched(base, delta, size)
	return {}


## `size` BYTES OF ZLIB STREAM, INFLATED, from where the pack is. Enough input for the stream's worst case: stored
## blocks cost five bytes in 64 KB, and the header and checksum six.
static func _inflate(pack: FileAccess, size: int) -> PackedByteArray:
	if size <= 0:
		return PackedByteArray()
	var take: int = mini(size + size / 1024 + 64, pack.get_length() - pack.get_position())
	return pack.get_buffer(take).decompress(size, FileAccess.COMPRESSION_DEFLATE)


static func _patched(base: Dictionary, delta: PackedByteArray, size: int) -> Dictionary:
	if base.is_empty() or delta.size() != size:
		return {}
	var whole: PackedByteArray = apply_delta(base["data"], delta)
	return {"type": base["type"], "data": whole} if not whole.is_empty() else {}


## A GIT DELTA APPLIED TO ITS BASE: the base's size and the result's, each a little-endian varint, then instructions --
## a high bit set copies a run of the base (offset and length in the bytes the low seven bits name; a length of 0 is
## 0x10000), clear inserts the next that-many bytes. Returns an empty array for a delta that does not fit its base.
static func apply_delta(base: PackedByteArray, delta: PackedByteArray) -> PackedByteArray:
	var at: Array[int] = [0]
	var read_size := func() -> int:
		var value: int = 0
		var shift: int = 0
		while at[0] < delta.size():
			var b: int = delta[at[0]]
			at[0] += 1
			value |= (b & 0x7f) << shift
			shift += 7
			if not b & 0x80:
				break
		return value
	if read_size.call() != base.size():
		return PackedByteArray()
	var wanted: int = read_size.call()
	var out := PackedByteArray()
	var i: int = at[0]
	while i < delta.size():
		var op: int = delta[i]
		i += 1
		if op & 0x80:
			var from: int = 0
			var length: int = 0
			for bit in range(7):
				if not op & (1 << bit):
					continue
				if i >= delta.size():
					return PackedByteArray()
				if bit < 4:
					from |= delta[i] << (8 * bit)
				else:
					length |= delta[i] << (8 * (bit - 4))
				i += 1
			if length == 0:
				length = 0x10000
			if from + length > base.size():
				return PackedByteArray()
			out.append_array(base.slice(from, from + length))
		elif op > 0 and i + op <= delta.size():
			out.append_array(delta.slice(i, i + op))
			i += op
		else:
			return PackedByteArray()
	return out if out.size() == wanted else PackedByteArray()
