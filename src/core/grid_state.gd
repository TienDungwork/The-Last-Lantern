class_name GridState
extends RefCounted
## Trạng thái động của màn đang chơi: vị trí, ô đã đổi, đèn, cờ sự kiện, bàn đạp.
## Túi đồ/năng lượng nằm ở World (giữ qua các màn). Không có gì về đồ họa.
## Mỗi hành động ghi vào `out` (Dictionary) cho view/ui xử lý.

const DIR_VEC := {1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0), 4: Vector2i(0, -1)}
# Cờ sự kiện: 1 repeat, 2 active, 4/8/16/32 = đang đi xuống/trái/lên/phải, 64 by_actor, 128 on_enter
const F_REPEAT := 1
const F_ACTIVE := 2
const F_BY_ACTOR := 64
const F_ON_ENTER := 128
const MOVE_FLAG := {1: 32, 2: 4, 3: 8, 4: 16}   # field_425[dir-1]
# Sự kiện có lệnh đầu là 16 (bàn đạp), 24 (hẹn giờ), 28 (đếm hộp) không kích hoạt bằng cách đi vào (method_216).
const SELF_DRIVEN_TYPES := [16, 24, 28]
const OUT_OF_BOUNDS_TILE := 8 + 48   # 0x38, tường

var level: LevelData
var world: World
var tiles: Array = []            # bản sao có thể đổi của level.grid
var lights: Array = []           # bản sao có thể đổi của level.lights
var events: Array = []           # bản sao sâu của level.events (COUNTER sửa số đếm trong đó)
var event_active: Array = []     # bool theo event id
var plate_saved: Dictionary = {} # event id bàn đạp đang mở -> ô cửa gốc
var light: Array = []            # độ sáng từng ô; rỗng = cần tính lại (light_map())
var player: Vector2i
var facing: int = 2
var control: bool = true
var out: Array = []
var vm: ScriptVM

var inventory: Array[int]:
	get: return world.inventory
var energy: int:
	get: return world.energy
	set(v): world.energy = v
var max_energy: int:
	get: return world.max_energy
	set(v): world.max_energy = v

func _init(L: LevelData, spawn: Vector2i = Vector2i(-1, -1), w: World = null) -> void:
	level = L
	world = w if w else World.new()
	for row in L.grid:
		tiles.append(PackedInt32Array(row))
	for l in L.lights:
		lights.append(l.duplicate())
	events = L.events.duplicate(true)
	for e in events:
		event_active.append(bool(int(e.flags) & F_ACTIVE))
	player = spawn if spawn.x >= 0 else L.start
	vm = ScriptVM.new(self)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < level.width and p.y < level.height

func tile_at(p: Vector2i) -> int:
	return tiles[p.y][p.x] if in_bounds(p) else OUT_OF_BOUNDS_TILE

func set_tile(p: Vector2i, t: int) -> void:
	tiles[p.y][p.x] = t
	light = []
	out.append({"type": "tile_changed", "at": p, "tile": t})

func is_solid(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t >= 8 and int(LevelData.tile_props(t).solid) == 1

func light_map() -> Array:
	if light.is_empty():
		light = LightField.compute(self)
	return light

func is_lit(p: Vector2i) -> bool:
	## method_133: ô sàn sáng khi độ sáng > 0; ô vật thể lấy theo 8 ô quanh nó.
	# ponytail: bản gốc (method_132) có ngoại lệ cho vài loại tường (lấy ô chéo/bên cạnh); M2 sau đối chiếu.
	if not in_bounds(p):
		return false
	var m := light_map()
	if tile_at(p) < 8:
		return m[p.y][p.x] > 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if in_bounds(q) and tile_at(q) < 8 and m[q.y][q.x] > 0:
				return true
	return false

func events_at(p: Vector2i, moving_dir: int, on_enter_only: bool = false) -> Array:
	## method_216 cho người chơi. moving_dir 0 = không lọc hướng (đi vào ô, vào màn).
	var r := []
	for e in events:
		if not event_active[int(e.id)] or int(e.commands[0].op) in SELF_DRIVEN_TYPES:
			continue
		var flags := int(e.flags)
		if (on_enter_only and not (flags & F_ON_ENTER)) or (flags & F_BY_ACTOR):
			continue
		if int(e.commands[0].op) == 10 and not is_lit(Vector2i(int(e.x), int(e.y))):
			continue   # vật phẩm chỉ nhặt được khi ô sáng
		if p.x < int(e.x) or p.y < int(e.y) or p.x >= int(e.x) + int(e.w) or p.y >= int(e.y) + int(e.h):
			continue
		if moving_dir > 0 and not (flags & MOVE_FLAG[moving_dir]):
			continue
		r.append(e)
	return r

func enter() -> Array:
	## Vào màn: chạy sự kiện cờ 128 tại ô đang đứng (class_10 dòng 2407), cập nhật bàn đạp.
	out.clear()
	for e in events_at(player, 0, true):
		vm.run(e)
	update_plates()
	return out

func step(dir: int) -> Array:
	## Một lượt đi. Bị chắn: chạy sự kiện ô đích có lọc hướng. Đi được: chạy sự kiện ô mới, không lọc hướng.
	out.clear()
	if not control:
		return out
	facing = dir
	var target: Vector2i = player + DIR_VEC[dir]
	if is_solid(target):
		out.append({"type": "bumped", "dir": dir})
		for e in events_at(target, dir):
			vm.run(e)
	else:
		player = target
		out.append({"type": "moved", "to": player, "dir": dir})
		for e in events_at(target, 0):
			vm.run(e)
	update_plates()
	return out

func update_plates() -> void:
	## method_215: bàn đạp (sự kiện lệnh đầu 16) mở ô cửa (x,y) khi vùng của nó có vật thể, người chơi
	## hoặc nguồn sáng; khi trống (và cửa không bị chặn) thì trả ô cửa về như cũ.
	for e in events:
		var id := int(e.id)
		if not event_active[id] or int(e.commands[0].op) != 16:
			continue
		var rect := Rect2i(int(e.x), int(e.y), int(e.w), int(e.h))
		var door := Vector2i(int(e.commands[0].args[0]), int(e.commands[0].args[1]))
		var pressed := rect.has_point(player) or (plate_saved.has(id) and player == door)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if in_bounds(Vector2i(x, y)) and tile_at(Vector2i(x, y)) >= 8:
					pressed = true
		for L in lights:
			if rect.has_point(Vector2i(int(L.x), int(L.y))):
				pressed = true
		if pressed and not plate_saved.has(id):
			plate_saved[id] = tile_at(door)
			set_tile(door, 0)
		elif not pressed and plate_saved.has(id):
			set_tile(door, plate_saved[id])
			plate_saved.erase(id)
