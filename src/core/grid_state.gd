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
# Sự kiện có lệnh đầu là 16 (bàn đạp), 24 (hẹn giờ), 28 (cảm biến sáng) không kích hoạt bằng cách đi vào (method_216).
const SELF_DRIVEN_TYPES := [16, 24, 28]
const OUT_OF_BOUNDS_TILE := 8 + 48   # 0x38, tường

var level: LevelData
var world: World
var tiles: Array = []            # bản sao có thể đổi của level.grid
var lights: Array = []           # bản sao có thể đổi của level.lights
var events: Array = []           # bản sao sâu của level.events (COUNTER sửa số đếm trong đó)
var event_active: Array = []     # bool theo event id
var plate_saved: Dictionary = {} # event id bàn đạp đang mở -> ô cửa gốc
var boxes: Dictionary = {}       # Vector2i -> ô hộp; tách khỏi lưới lúc nạp (field_204..206)
var carried := -1                # chỉ số đèn đang cầm (field_149), -1 = tay không
var bulbs := 0                   # bóng đèn đang có (field_278), riêng từng màn
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
	for y in L.height:
		for x in L.width:
			var t: int = tiles[y][x]
			if t >= 8 and int(LevelData.tile_props(t).movable) == 1:
				boxes[Vector2i(x, y)] = t
				tiles[y][x] = 0
	for l in L.lights:
		var d: Dictionary = l.duplicate()
		d.life = int(l.radius) * 2 + 1   # field_228[6]: nến mất 1 mỗi bước, bán kính = life >> 1
		lights.append(d)
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

func is_blocked(p: Vector2i) -> bool:
	## method_93: ngoài bản đồ, có hộp, hoặc ô solid. Người chơi không tính (kéo hộp vào chỗ mình đứng).
	# ponytail: bản gốc còn chặn ở ô actor (field_379..382); thêm khi có actor.
	return not in_bounds(p) or boxes.has(p) or is_solid(p)

func light_map() -> Array:
	if light.is_empty():
		light = LightField.compute(self)
	return light

func light_level(p: Vector2i) -> int:
	## method_132: độ sáng một ô. Ô vật thể: vài loại tường mượn ô bên phải/dưới/chéo, còn lại lấy ô sàn sáng nhất quanh nó.
	if not in_bounds(p):
		return 0
	var t := tile_at(p)
	if t < 8:
		return light_map()[p.y][p.x]
	match t - 8:
		40, 46:
			return light_level(p + Vector2i(1, 1))
		41, 42, 47, 48:
			return light_level(p + Vector2i(1, 0))
		43, 44, 45, 49, 50, 51:
			return light_level(p + Vector2i(0, 1))
	var best := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if in_bounds(q) and tile_at(q) < 8:
				best = maxi(best, light_map()[q.y][q.x])
	return best

func is_lit(p: Vector2i) -> bool:
	return light_level(p) > 0   # method_133

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
	check_light_sensors()
	return out

func step(dir: int) -> Array:
	## Một lượt đi. Bị chắn: chạy sự kiện ô đích có lọc hướng. Đi được: chạy sự kiện ô mới, không lọc hướng.
	out.clear()
	if not control:
		return out
	if carried >= 0 and dir != facing and int(lights[carried].type) == 1:
		# Cầm đèn pin: đổi hướng chỉ xoay đèn, không bước.
		facing = dir
		lights[carried].dir = dir
		light = []
		out.append({"type": "bumped", "dir": dir})
		check_light_sensors()
		return out
	facing = dir
	var d: Vector2i = DIR_VEC[dir]
	var target: Vector2i = player + d
	if boxes.has(target):
		# method_92: đẩy hộp; phía sau hộp bị chặn thì thành kéo (lùi một ô, hộp vào chỗ cũ).
		var box_from := target
		var box_to := target + d
		if is_blocked(box_to):
			box_to = player
			target = player - d
			if is_blocked(target):
				return out
		boxes[box_to] = boxes[box_from]
		boxes.erase(box_from)
		light = []
		out.append({"type": "box_moved", "from": box_from, "to": box_to})
	if is_solid(target):
		out.append({"type": "bumped", "dir": dir})
		_press_switch(target)
		for e in events_at(target, dir):
			vm.run(e)
	else:
		player = target
		out.append({"type": "moved", "to": player, "dir": dir})
		if carried >= 0:
			_carry_light(dir)
		for e in events_at(target, 0):
			vm.run(e)
	update_plates()
	check_light_sensors()
	return out

func action() -> Array:
	## method_149/143, phím bắn: đang cầm đèn thì đặt xuống; tay không thì nhặt đèn (loại 0/1/2) ở ô đang đứng và bật nó.
	out.clear()
	if carried >= 0:
		carried = -1
		return out
	for i in lights.size():   # bản gốc không dừng ở đèn đầu: cầm đèn cuối cùng khớp
		var L: Dictionary = lights[i]
		if int(L.x) == player.x and int(L.y) == player.y and int(L.type) in [0, 1, 2]:
			carried = i
			if int(L.on) == 0 and (int(L.type) != 2 or int(L.life) != 0):
				L.on = 1
				light = []
	check_light_sensors()
	return out

func _press_switch(p: Vector2i) -> void:
	## method_92: công tắc tường khung 63 (ngang) / 52 (dọc) bật-tắt đèn loại 5 ở ô trái-phải / dưới-trên,
	## rồi thành khung 62 / 53 (đã gạt, không gạt lại được).
	var t := tile_at(p) - 8
	var side: Vector2i
	match t:
		63: side = Vector2i(1, 0)
		52: side = Vector2i(0, 1)
		_: return
	set_tile(p, t + 8 + (-1 if t == 63 else 1))
	for q in [p + side, p - side]:
		var i := _light_index(q, 5)
		if i >= 0:
			lights[i].on = 1 - int(lights[i].on)
			out.append({"type": "light_changed", "light": i})
			return

func toggle_bulb(i: int) -> void:
	## Op 23 (method_209): hốc đèn sáng thì lấy bóng, tối thì lắp bóng nếu còn.
	var L: Dictionary = lights[i]
	if int(L.on) == 1:
		bulbs += 1
		L.on = 0
	elif bulbs > 0:
		bulbs -= 1
		L.on = 1
	else:
		return
	light = []
	out.append({"type": "light_changed", "light": i})

func _light_index(p: Vector2i, type: int) -> int:
	## method_142: đèn đầu tiên đúng loại ở ô p.
	for i in lights.size():
		if int(lights[i].x) == p.x and int(lights[i].y) == p.y and int(lights[i].type) == type:
			return i
	return -1

func _carry_light(dir: int) -> void:
	var L: Dictionary = lights[carried]
	L.x = player.x
	L.y = player.y
	if int(L.dir) != 0:
		L.dir = dir
	if int(L.type) == 2 and int(L.life) > 0:
		L.life = int(L.life) - 1
		L.radius = int(L.life) >> 1
		if int(L.radius) == 0:
			L.on = 0
	light = []

func update_plates() -> void:
	## method_215: bàn đạp (sự kiện lệnh đầu 16) mở ô cửa (x,y) khi vùng của nó có vật thể, người chơi
	## hoặc nguồn sáng; khi trống (và cửa không bị chặn) thì trả ô cửa về như cũ.
	for e in events:
		var id := int(e.id)
		if not event_active[id] or int(e.commands[0].op) != 16:
			continue
		var rect := Rect2i(int(e.x), int(e.y), int(e.w), int(e.h))
		var door := Vector2i(int(e.commands[0].args[0]), int(e.commands[0].args[1]))
		var pressed := rect.has_point(player)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var q := Vector2i(x, y)
				if in_bounds(q) and (tile_at(q) >= 8 or boxes.has(q)):
					pressed = true
		for L in lights:
			if rect.has_point(Vector2i(int(L.x), int(L.y))):
				pressed = true
			if int(L.x) == door.x and int(L.y) == door.y:
				pressed = true   # đèn chặn cửa: không đóng được
		if boxes.has(door):
			pressed = true
		if pressed and not plate_saved.has(id):
			plate_saved[id] = tile_at(door)
			set_tile(door, 0)
			vm.run(e)   # method_207: chạy lệnh sau op 16 (nếu có)
		elif not pressed and plate_saved.has(id):
			set_tile(door, plate_saved[id])
			plate_saved.erase(id)

func check_light_sensors() -> void:
	## method_214: sự kiện lệnh đầu 28 chạy (rồi tắt hẳn) khi ô (x,y) của nó sáng >= ngưỡng; ngưỡng 0 = khi ô tối hẳn.
	for e in events:
		var id := int(e.id)
		if not event_active[id] or int(e.commands[0].op) != 28:
			continue
		var need := int(e.commands[0].args[0])
		var lvl := light_level(Vector2i(int(e.x), int(e.y)))
		if (need != 0 or lvl == 0) and need <= lvl:
			event_active[id] = false
			vm.run(e)

func tick_timers(ms: int) -> void:
	## method_213: sự kiện lệnh đầu 24 đếm lùi số ms 32 bit trong 4 byte đối số, về <= 0 thì chạy.
	for e in events:
		if not event_active[int(e.id)] or int(e.commands[0].op) != 24:
			continue
		var a: Array = e.commands[0].args
		var left := (int(a[0]) << 24) | (int(a[1]) << 16) | (int(a[2]) << 8) | int(a[3])
		if left <= 0:
			continue
		left = maxi(left - ms, 0)
		a[0] = (left >> 24) & 0xFF
		a[1] = (left >> 16) & 0xFF
		a[2] = (left >> 8) & 0xFF
		a[3] = left & 0xFF
		if left == 0:
			vm.run(e)
