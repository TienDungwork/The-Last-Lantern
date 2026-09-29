class_name ScriptVM
extends RefCounted
## Chạy các lệnh kịch bản của một sự kiện lên GridState. Xem class_10.method_209 (bản gốc)
## và bảng đối số trong tools/df2_decode.py::disasm. Lệnh chưa cài -> out {"type":"todo"}.

const TODO_OPS := [1, 4, 5, 12, 13, 14, 18, 24, 25, 28]

var s: GridState

func _init(state: GridState) -> void:
	s = state

func run(e: Dictionary) -> void:
	for c in e.commands:
		if not _exec(int(c.op), c.args):
			return   # IF_HOLDING sai: dừng sự kiện

func _u16(hi: int, lo: int) -> int:
	var v := (hi << 8) | lo
	return -1 if v == 0xFFFF else v

func _same_level(v: int) -> bool:
	return (v & 0x7F) == s.level.index

func _exec(op: int, a: Array) -> bool:
	match op:
		2:
			s.out.append({"type": "say", "text_id": int(a[0]), "portrait": _u16(int(a[1]), int(a[2]))})
		3:
			s.energy = s.max_energy
		6:
			var to := Vector2i(int(a[0]), int(a[1]))
			if _same_level(int(a[2])):
				s.player = to
				s.out.append({"type": "teleported", "to": to})
			else:
				s.out.append({"type": "change_level", "level": int(a[2]) & 0x7F, "to": to})
		7:
			s.control = int(a[0]) != 0
		8:
			var dir := int(a[0])
			if GridState.DIR_VEC.has(dir):
				for i in int(a[1]):
					var t: Vector2i = s.player + GridState.DIR_VEC[dir]
					if s.is_solid(t):
						break
					s.player = t
					s.facing = dir
					s.out.append({"type": "moved", "to": t, "dir": dir, "scripted": true})
		9:
			if _same_level(int(a[2])):
				var at := Vector2i(int(a[0]), int(a[1]))
				s.tiles[at.y][at.x] = int(a[3])
				s.out.append({"type": "tile_changed", "at": at, "tile": int(a[3])})
		10:
			if int(a[0]) != 255:
				s.inventory.append(int(a[0]))
				s.out.append({"type": "pickup", "item": int(a[0])})
		11:
			var want_not := (int(a[0]) & 0x80) != 0
			if s.inventory.has(int(a[0]) & 0x7F) == want_not:
				return false
		15:
			s.out.append({"type": "map_reveal", "at": Vector2i(int(a[0]), int(a[1]))})
		16:
			s.out.append({"type": "change_level", "level": int(a[2]) & 0x7F, "to": Vector2i(int(a[0]), int(a[1]))})
		17:
			if _same_level(int(a[1])):
				var L: Dictionary = s.lights[int(a[0])]
				L.radius = int(a[2])
				L.on = 1 if int(a[2]) > 0 else 0
				s.out.append({"type": "light_changed", "light": int(a[0])})
		19:
			s.inventory.erase(int(a[0]))
			s.out.append({"type": "take_item", "item": int(a[0])})
		20:
			if _same_level(int(a[1])):
				s.event_active[int(a[0])] = true
		21:
			if _same_level(int(a[1])):
				s.event_active[int(a[0])] = false
		22:
			run(s.level.events[int(a[0])])
		23:
			s.out.append({"type": "bulb_socket", "light": int(a[0]) & 0x7F})
		26, 29:
			pass   # kiểu trang trí, view đọc trực tiếp từ level.events khi dựng cảnh
		27:
			s.out.append({"type": "actor_config", "mode": int(a[0]), "slot": int(a[1]), "args": a.slice(2)})
		30:
			s.out.append({"type": "special", "code": int(a[0])})
		_:
			if op in TODO_OPS:
				s.out.append({"type": "todo", "op": op, "args": a})
			else:
				push_error("ScriptVM: mã lệnh lạ %d" % op)
	return true
