class_name ScriptVM
extends RefCounted
## Chạy lệnh kịch bản của một sự kiện lên GridState. Xem class_10.method_207/208/209 (bản gốc)
## và bảng đối số trong tools/df2_decode.py::disasm. Lệnh chưa cài -> out {"type":"todo"}.
## Sự kiện chạy hết -> tắt nếu không có cờ repeat. Bị hủy giữa chừng (IF_HOLDING sai, COUNTER chưa tới,
## PICKUP trong tối) -> vẫn bật, lần sau chạy lại được.

const TODO_OPS := [1, 12, 13]
const PERSIST := 0x80
const MARKER_GROUP_FRAME := 380   # op 4: bật một điểm nhóm 380 thì tắt các điểm 380 khác

var _s: WeakRef                   # GridState sở hữu VM; tham chiếu yếu để không tạo vòng RefCounted
var s: GridState:
	get: return _s.get_ref()

static var _markers: Array = []

func _init(state: GridState) -> void:
	_s = weakref(state)

func run(e: Dictionary, actor: int = -1) -> bool:
	## actor >= 0: sự kiện do tu sĩ đó kích (field_432), lệnh 6/8 tác động lên tu sĩ thay vì người chơi.
	var st := s
	for c in e.commands:
		if not _exec(e, int(c.op), c.args, actor):
			return false
	if e.has("id") and not (int(e.flags) & GridState.F_REPEAT):
		st.event_active[int(e.id)] = false
	return true

func _u16(hi: int, lo: int) -> int:
	var v := (hi << 8) | lo
	return -1 if v == 0xFFFF else v

func _level_arg(v: int, type: int, id: int, x: int = 0, y: int = 0, value: int = 0) -> bool:
	## Byte "màn" của lệnh 9/17/20/21: bit 0x80 = ghi sổ World. Trả về true nếu áp cho màn hiện tại.
	var n := v & 0x7F
	if v & PERSIST:
		s.world.log_change(type, n, id, x, y, value)
	return n == s.level.index

func _exec(e: Dictionary, op: int, a: Array, actor: int = -1) -> bool:
	var st := s
	if actor >= 0 and op in [6, 8]:
		_exec_actor(op, a, actor)
		return true
	match op:
		2:
			st.out.append({"type": "say", "text_id": int(a[0]), "portrait": _u16(int(a[1]), int(a[2]))})
		3:
			st.energy = st.max_energy
		4:
			var id := int(a[0])
			if _marker_frame(id) == MARKER_GROUP_FRAME:
				for k in st.world.map_markers.keys():
					if _marker_frame(k) == MARKER_GROUP_FRAME:
						st.world.map_markers.erase(k)
			st.world.map_markers[id] = true
		5:
			st.world.map_markers.erase(int(a[0]))
		6:
			var to := Vector2i(int(a[0]), int(a[1]))
			if int(a[2]) == st.level.index:
				st.player = to
				st.out.append({"type": "teleported", "to": to})
			else:
				st.out.append({"type": "change_level", "level": int(a[2]), "to": to})
		7:
			st.control = int(a[0]) != 0
		8:
			var dir := int(a[0])
			if GridState.DIR_VEC.has(dir):
				for i in int(a[1]):
					var t: Vector2i = st.player + GridState.DIR_VEC[dir]
					if st.is_solid(t):
						break
					st.player = t
					st.facing = dir
					st.out.append({"type": "moved", "to": t, "dir": dir, "scripted": true})
		9:
			var at := Vector2i(int(a[0]), int(a[1]))
			if _level_arg(int(a[2]), World.SET_TILE, 0, at.x, at.y, int(a[3])):
				st.set_tile(at, int(a[3]))
		10:
			if e.has("x"):   # method_209 case 10: ô sàn của sự kiện đang tối thì hủy
				var p := Vector2i(int(e.x), int(e.y))
				if st.tile_at(p) < 8 and st.light_map()[p.y][p.x] < 1:
					return false
			if e.has("id"):
				st.event_active[int(e.id)] = false
			if int(a[0]) != 255:
				var it := LevelData.item(int(a[0]))
				st.out.append({"type": "say", "text_id": 238, "portrait": int(it.frame), "args": [int(it.name_id)]})
				st.inventory.append(int(a[0]))
				st.out.append({"type": "pickup", "item": int(a[0])})
		11:
			var want_not := (int(a[0]) & 0x80) != 0
			if st.inventory.has(int(a[0]) & 0x7F) == want_not:
				return false
		15:
			st.world.map_revealed.append(Vector2i(int(a[0]), int(a[1])))
			st.out.append({"type": "map_reveal", "at": Vector2i(int(a[0]), int(a[1]))})
		16, 24, 28:
			pass   # bàn đạp / hẹn giờ / cảm biến sáng: GridState kích hoạt, lệnh đầu tự nó không làm gì
		17:
			var id := int(a[0])
			if _level_arg(int(a[1]), World.SET_LIGHT, id, 0, 0, int(a[2])):
				var L: Dictionary = st.lights[id]
				L.on = 1 if int(a[2]) > 0 else 0
				if int(a[2]) > 0:
					L.radius = int(a[2])
				st.light = []
				st.out.append({"type": "light_changed", "light": id})
		18:
			if int(a[0]) != 1:           # method_209 case 18: đếm lùi, chỉ chạy tiếp khi còn 1
				if int(a[0]) > 0:
					a[0] = int(a[0]) - 1
				return false
			a[0] = 0
		19:
			st.inventory.erase(int(a[0]))
			st.out.append({"type": "take_item", "item": int(a[0])})
		20:
			if _level_arg(int(a[1]), World.ENABLE, int(a[0])):
				st.event_active[int(a[0])] = true
		21:
			if _level_arg(int(a[1]), World.DISABLE, int(a[0])):
				st.event_active[int(a[0])] = false
		14:
			if int(a[3]) & 0x80:
				st.spawn_guard(Vector2i(int(a[0]), int(a[1])), int(a[2]), int(a[3]) & 0x7F)
			else:
				st.spawn_creature(Vector2i(int(a[0]), int(a[1])), int(a[2]), int(a[3]))
		22:   # tu sĩ chỉ đi theo vào sự kiện cờ 64
			var callee: Dictionary = st.events[int(a[0])]
			run(callee, actor if int(callee.flags) & GridState.F_BY_ACTOR else -1)
		23:
			st.toggle_bulb(int(a[0]) & 0x7F)
		25:   # method_209 case 25: hồi đầy năng lượng kèm câu 234
			st.out.append({"type": "say", "text_id": 234, "portrait": -1})
			st.energy = st.max_energy
		26, 29:
			pass   # kiểu trang trí, view đọc trực tiếp từ events khi dựng cảnh
		27:
			st.out.append({"type": "actor_config", "mode": int(a[0]), "slot": int(a[1]), "args": a.slice(2)})
		30:
			st.out.append({"type": "special", "code": int(a[0])})
		_:
			if op in TODO_OPS:
				st.out.append({"type": "todo", "op": op, "args": a})
			else:
				push_error("ScriptVM: mã lệnh lạ %d" % op)
	return true

func _exec_actor(op: int, a: Array, i: int) -> void:
	## method_209 case 6/8 khi field_432 >= 0.
	var st := s
	var g = st.guards[i]
	if g == null:
		return
	if op == 6:
		if int(a[2]) != st.level.index:
			st.guards[i] = null
		else:
			g.to = Vector2i(int(a[0]), int(a[1]))
			g.pos = g.to * GridState.GUARD_TILE_MS
	else:
		g.dir = int(a[0])
		g.to = st.guard_tile(i) + GridState.DIR_VEC.get(g.dir, Vector2i.ZERO) * int(a[1])

static func _marker_frame(id: int) -> int:
	if _markers.is_empty():
		_markers = LevelData.read_json("res://data/map_markers.json")
	return int(_markers[id].icon_frame) if id < _markers.size() else -1
