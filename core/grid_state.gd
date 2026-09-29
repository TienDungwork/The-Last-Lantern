class_name GridState
extends RefCounted
## Trạng thái động của màn đang chơi: vị trí, năng lượng, túi đồ, ô đã đổi, đèn, cờ sự kiện.
## Không có gì về đồ họa. Mỗi hành động ghi vào `out` (Dictionary) cho view/ui xử lý.

const DIR_VEC := {1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0), 4: Vector2i(0, -1)}
# Cờ sự kiện: 1 repeat, 2 active, 4 from_down, 8 from_left, 16 from_up, 32 from_right, 64 by_actor, 128 on_action
const F_REPEAT := 1
const F_ACTIVE := 2
const F_BY_ACTOR := 64
const F_ON_ACTION := 128
# Hướng người chơi đang đi -> cờ "vào từ phía": đi lên (4) là vào ô đích từ phía dưới (bit 4).
# ponytail: giả định từ tên cờ; Task 13 so với bản gốc, sai thì đổi bảng này.
const ENTER_FLAG := {4: 4, 1: 8, 2: 16, 3: 32}
const OUT_OF_BOUNDS_TILE := 8 + 48   # 0x38, tường

var level: LevelData
var tiles: Array = []            # bản sao có thể đổi của level.grid
var lights: Array = []           # bản sao có thể đổi của level.lights
var event_active: Array = []     # bool theo event id
var player: Vector2i
var facing: int = 2
var control: bool = true
var max_energy: int = 4          # field_152 bản gốc (= 4, đối chiếu tests/parity)
var energy: int = 4
var inventory: Array[int] = []
var equipped: int = -1
var out: Array = []
var vm: ScriptVM

func _init(L: LevelData, spawn: Vector2i = Vector2i(-1, -1)) -> void:
	level = L
	for row in L.grid:
		tiles.append(PackedInt32Array(row))
	for l in L.lights:
		lights.append(l.duplicate())
	for e in L.events:
		event_active.append(bool(int(e.flags) & F_ACTIVE))
	player = spawn if spawn.x >= 0 else L.start
	energy = max_energy
	vm = ScriptVM.new(self)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < level.width and p.y < level.height

func tile_at(p: Vector2i) -> int:
	return tiles[p.y][p.x] if in_bounds(p) else OUT_OF_BOUNDS_TILE

func is_solid(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t >= 8 and int(LevelData.tile_props(t).solid) == 1

func events_at(p: Vector2i, moving_dir: int) -> Array:
	## Sự kiện đang bật, phủ ô p, cho phép vào theo hướng đang đi, không phải loại by_actor/on_action.
	var r := []
	for e in level.events:
		if not event_active[int(e.id)]:
			continue
		var flags := int(e.flags)
		if flags & (F_BY_ACTOR | F_ON_ACTION):
			continue
		if p.x < int(e.x) or p.y < int(e.y) or p.x >= int(e.x) + int(e.w) or p.y >= int(e.y) + int(e.h):
			continue
		if not (flags & ENTER_FLAG[moving_dir]):
			continue
		r.append(e)
	return r

func step(dir: int) -> Array:
	## Một lượt đi của người chơi. Đi trước (nếu không chắn), rồi chạy sự kiện tại ô đích
	## (chạy cả khi bị chắn: "đi về phía tờ giấy để đọc"). Trả về out cho view.
	out.clear()
	if not control:
		return out
	facing = dir
	var target: Vector2i = player + DIR_VEC[dir]
	if is_solid(target):
		out.append({"type": "bumped", "dir": dir})
	else:
		player = target
		out.append({"type": "moved", "to": player, "dir": dir})
	for e in events_at(target, dir):
		vm.run(e)
		if not (int(e.flags) & F_REPEAT):
			event_active[int(e.id)] = false
	return out
