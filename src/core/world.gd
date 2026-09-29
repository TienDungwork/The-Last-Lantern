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

func play_time_text() -> String:
	var s := play_ms / 1000
	return "%dh %dm %ds" % [s / 3600, s % 3600 / 60, s % 60]

func save_game(path: String, level: int, at: Vector2i) -> void:
	## method_112, dạng JSON. Không dùng var_to_str/str_to_var: file do người dùng giữ, chỉ đọc dữ liệu thuần.
	var d := {"version": 1, "level": level, "x": at.x, "y": at.y, "inventory": inventory, "equipped": equipped,
		"energy": energy, "max_energy": max_energy, "creatures_killed": creatures_killed, "play_ms": play_ms,
		"steps": steps, "minigames": minigames,
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
