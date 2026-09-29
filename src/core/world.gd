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
