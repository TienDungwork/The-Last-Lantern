class_name World
extends RefCounted
## Trạng thái xuyên màn: túi đồ, năng lượng, điểm đánh dấu bản đồ, "sổ thay đổi" của các màn.
## Mô hình gốc (class_10.method_205/206): vào màn = nạp lại .dat rồi áp sổ; chỉ lệnh có bit persist (0x80)
## mới được ghi sổ. Loại: 0 bật sự kiện, 1 tắt sự kiện, 2 đổi ô, 3 đổi bán kính đèn.

enum { ENABLE, DISABLE, SET_TILE, SET_LIGHT }

var inventory: Array[int] = []
var equipped := -1               # món đang trang bị (field_267[field_274]), -1 = không
var creatures_killed := 0        # field_474, lưu vào save và hiện ở bảng thống kê
var max_energy: int = 4          # field_152
var energy: int = 4
var map_markers: Dictionary = {} # id -> true (op 4/5, field_313)
var map_revealed: Array = []     # Vector2i (op 15)
var log: Array = []              # {type, level, id, x, y, value}
var play_ms := 0                 # field_188, tổng thời gian chơi
var steps := 0                   # field_139, "số mét đã đi" = số bước người chơi tự đi
var minigames: Array = []        # op 12 đã tìm: 0 Semua Darts, 1 Lantern Worm, 2 King Bong (field_498/510/539)
var battery := 0                 # field_275: lượt flash của máy ảnh (pin, món 33)
var flash := false               # field_277: máy ảnh đã lắp pin (ghép 7 + 33)
var infinite_battery := false    # field_276: mã thưởng pin vô hạn
var grave_keys := 0              # field_280: mảnh chìa khóa hầm mộ (món 29)
var muffins := 0                 # field_279: bánh muffin (món 21)
var coins := 0                   # field_281: đồng xu (món 6)
var fuses := 0                   # field_282: cầu chì (món 14)
var _code_pos := [0, 0]          # field_168/169: đã gõ đúng bao nhiêu số của mỗi mã thưởng

const CAMERA := 7
const BATTERY := 33
const NOTES := [0, 22, 23, 24, 25]   # method_160: món mới chèn trước dãy ghi chú ở cuối túi
const NOTE_TEXT := {0: 228, 22: 229, 23: 230, 24: 232, 25: 231}   # field_272: chọn ghi chú = đọc
# field_273: [món đang chọn, món ghép vào, kết quả (-2 = máy ảnh có flash), món mất đi (-1 = không mất)]
const RECIPES := [[9, 17, 18, 17], [17, 9, 18, 17], [17, 30, 18, 17], [19, 9, 30, 19], [9, 19, 30, 19],
	[30, 17, 18, 17], [1, 16, 31, -1], [16, 1, 31, -1], [7, 33, -2, 33], [33, 7, -2, 33]]
const CODES := ["7825537", "683346"]   # field_180 áo choàng tu sĩ, field_181 pin vô hạn (phím số)

# method_218: ngưỡng xếp hạng. Điểm minigame luôn 0 (chưa làm minigame) -> mỗi trò cộng 5.
const GRADE_KILLS := [200, 170, 130, 90, 50, -1]         # field_440, giết nhiều hơn -> tốt hơn
const GRADE_STEPS := [1900, 2100, 2300, 2500, 2700, 100000]   # field_441, đi ít hơn -> tốt hơn
const GRADE_DARTS := [45, 40, 35, 30, 25, -1]            # field_442
const GRADE_BONG := [400, 300, 200, 150, 100, -100000]   # field_443
const GRADE_WORM := [4000, 3500, 3000, 2500, 2000, -1]   # field_444

func grade(darts := 0, bong := 0, worm := 0) -> String:
	var g := 0
	for i in 6:
		if creatures_killed > GRADE_KILLS[i]:
			g = i
			break
	for i in 6:
		if steps < GRADE_STEPS[i]:
			g += i
			break
	for pair in [[darts, GRADE_DARTS], [bong, GRADE_BONG], [worm, GRADE_WORM]]:
		for i in 6:
			if pair[0] > pair[1][i]:
				g += i
				break
	return "ABCDEF"[mini((g + 3) / 5, 5)]

func add_item(id: int) -> Array:
	## method_160. Món cộng dồn chỉ chiếm một ô túi. Trả về id câu cần nói (đủ 18 muffin, đủ 6 mảnh chìa).
	var say := []
	var stack := false
	match id:
		21:
			stack = muffins > 0
			if muffins < 18:
				muffins += 1
				if muffins == 18:
					say.append(244)
		14:
			stack = fuses > 0
			fuses = mini(fuses + 1, 99)
		29:
			stack = grave_keys > 0
			if grave_keys < 6:
				grave_keys += 1
				if grave_keys == 6:
					say.append(233)
		6:
			stack = coins > 0
			coins = mini(coins + 1, 99)
		BATTERY:
			stack = battery < 99 if flash else battery > 0
			battery += 1
	if id < 0 or stack or inventory.has(id):
		return say
	var at := inventory.size() - 1   # bản gốc: chèn trước món cuối và trước dãy ghi chú liền trước nó
	while at > 0 and inventory[at - 1] in NOTES:
		at -= 1
	inventory.insert(maxi(at, 0), id)
	return say

func remove_item(id: int) -> void:
	## method_161 (op 19, ghép đồ): đồng xu / cầu chì bớt một, hết mới mất khỏi túi. Luôn cất món đang cầm.
	if (id == 6 and coins > 1) or (id == 14 and fuses > 1):
		if id == 6: coins -= 1
		else: fuses -= 1
		return
	if id == 6: coins = 0
	if id == 14: fuses = 0
	inventory.erase(id)
	equipped = -1

func count(id: int) -> int:
	## method_167: số hiện trên ô túi, -1 = không hiện.
	match id:
		21: return muffins
		14: return fuses
		29: return grave_keys
		6: return coins
		BATTERY: return -1 if flash else battery
		CAMERA: return battery if flash else -1
	return -1

func _recipe(a: int, b: int) -> Array:
	for r in RECIPES:
		if r[0] == a and r[1] == b:
			return r
	return []

func can_combine(id: int) -> bool:
	## Dòng 4318: món có công thức, kết quả chưa có (máy ảnh chưa lắp pin).
	for r in RECIPES:
		if r[0] == id and inventory.has(r[1]) and not (r[2] == -2 and flash) and not inventory.has(r[2]):
			return true
	return false

func combine(a: int, b: int) -> bool:
	## Dòng 4282: thêm kết quả, bỏ món mất đi, cầm luôn kết quả (máy ảnh nếu vừa lắp pin).
	var r := _recipe(a, b)
	if r.is_empty() or not (inventory.has(a) and inventory.has(b)) or inventory.has(r[2]) or (r[2] == -2 and flash):
		return false
	add_item(r[2])
	remove_item(r[3])
	if r[2] == -2:
		flash = true
	equipped = CAMERA if r[2] == -2 else r[2]
	return true

func type_digit(d: int) -> Array:
	## method_59 dòng 1211: gõ đủ một mã thưởng là nhận ngay; gõ sai thì mã đó đếm lại từ đầu.
	var said := []
	for k in CODES.size():
		var code: String = CODES[k]
		_code_pos[k] = _code_pos[k] + 1 if code[_code_pos[k]] == str(d) else 0
		if _code_pos[k] == code.length():
			_code_pos[k] = 0
			if k == 0:
				add_item(GridState.CLOAK)
			else:
				battery = 99
				infinite_battery = true
			said.append(k)
	return said

## method_176/173: ô bản đồ 0 = không phải đường, 1 = đường chưa tới, 2 = đường đã tới (tô loang 4 hướng
## qua ô đường từ mỗi điểm op 15). Trả về mảng hàng, mỗi hàng là mảng int.
func map_cells() -> Array:
	var rows: Array = LevelData.read_json("res://data/citymap.json").rows
	var cells: Array = rows.map(func(r: String): return Array(r.split("")).map(func(c): return 1 if c == "#" else 0))
	var todo: Array = map_revealed.duplicate()
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if p.y < 0 or p.y >= cells.size() or p.x < 0 or p.x >= cells[p.y].size() or cells[p.y][p.x] != 1:
			continue
		cells[p.y][p.x] = 2
		todo.append_array([p + Vector2i.RIGHT, p + Vector2i.DOWN, p + Vector2i.LEFT, p + Vector2i.UP])
	return cells

func play_time_text() -> String:
	var s := play_ms / 1000
	return "%dh %dm %ds" % [s / 3600, s % 3600 / 60, s % 60]

func save_game(path: String, level: int, at: Vector2i) -> void:
	## method_112, dạng JSON. Không dùng var_to_str/str_to_var: file do người dùng giữ, chỉ đọc dữ liệu thuần.
	var d := {"version": 1, "level": level, "x": at.x, "y": at.y, "inventory": inventory, "equipped": equipped,
		"energy": energy, "max_energy": max_energy, "creatures_killed": creatures_killed, "play_ms": play_ms,
		"steps": steps, "minigames": minigames, "battery": battery, "flash": flash, "infinite_battery": infinite_battery,
		"grave_keys": grave_keys, "muffins": muffins, "coins": coins, "fuses": fuses,
		"map_markers": map_markers.keys(), "map_revealed": map_revealed.map(func(p): return [p.x, p.y]), "log": log}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Không ghi được save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(d))

static func load_game(path: String) -> Dictionary:
	## method_114. Trả về {world, level, at}; file không có hoặc hỏng -> {}.
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or int(d.get("version", 0)) != 1:
		push_error("Save hỏng hoặc khác phiên bản: %s" % path)
		return {}
	var w := World.new()
	w.inventory.assign(d.inventory.map(func(v): return int(v)))
	w.equipped = int(d.equipped)
	w.energy = int(d.energy)
	w.max_energy = int(d.max_energy)
	w.creatures_killed = int(d.creatures_killed)
	w.play_ms = int(d.play_ms)
	w.steps = int(d.get("steps", 0))
	w.minigames = d.get("minigames", []).map(func(v): return int(v))
	for k in ["battery", "grave_keys", "muffins", "coins", "fuses"]:
		w.set(k, int(d.get(k, 0)))
	w.flash = bool(d.get("flash", false))
	w.infinite_battery = bool(d.get("infinite_battery", false))
	for k in d.map_markers:
		w.map_markers[int(k)] = true
	w.map_revealed = d.map_revealed.map(func(p): return Vector2i(int(p[0]), int(p[1])))
	for c in d.log:
		var e := {}
		for k in ["type", "level", "id", "x", "y", "value"]:
			e[k] = int(c[k])
		w.log.append(e)
	return {"world": w, "level": int(d.level), "at": Vector2i(int(d.x), int(d.y))}

func enter_level(n: int, spawn: Vector2i = Vector2i(-1, -1)) -> GridState:
	var s := GridState.new(LevelData.load_level(n), spawn, self)
	for c in log:
		if int(c.level) != n:
			continue
		match int(c.type):
			ENABLE: s.event_active[c.id] = true
			DISABLE: s.event_active[c.id] = false
			SET_TILE: s.tiles[c.y][c.x] = c.value
			SET_LIGHT:
				s.lights[c.id].radius = c.value
				s.lights[c.id].on = 1 if c.value > 0 else 0
	return s

func log_change(type: int, level: int, id: int, x: int = 0, y: int = 0, value: int = 0) -> void:
	for i in log.size():
		var c: Dictionary = log[i]
		if c.level != level:
			continue
		var opposite: bool = (c.type == ENABLE and type == DISABLE) or (c.type == DISABLE and type == ENABLE)
		if opposite and c.id == id:
			log.remove_at(i)       # bật rồi tắt (hoặc ngược lại) = không còn gì
			return
		if c.type == type:
			match type:
				ENABLE, DISABLE:
					if c.id == id:
						return
				SET_LIGHT:
					if c.id == id:
						c.value = value
						return
				SET_TILE:
					if c.x == x and c.y == y:
						c.value = value
						return
	log.append({"type": type, "level": level, "id": id, "x": x, "y": y, "value": value})
