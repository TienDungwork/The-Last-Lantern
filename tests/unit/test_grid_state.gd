extends "res://tests/lib/test_case.gd"

func _state() -> GridState:
	return GridState.new(LevelData.load_level(0))

func test_spawn_at_header_start() -> void:
	var s := _state()
	eq(s.player, Vector2i(6, 4), "vị trí đầu")
	eq(s.energy, s.max_energy, "đầy năng lượng")
	eq(s.inventory.size(), 0, "túi rỗng")

func test_solid() -> void:
	var s := _state()
	eq(s.is_solid(Vector2i(8, 4)), true, "tường 0x38")
	eq(s.is_solid(Vector2i(7, 4)), false, "sàn")
	eq(s.is_solid(Vector2i(5, 3)), true, "tờ giấy 0x5a là vật thể")
	eq(s.is_solid(Vector2i(-1, 0)), true, "ngoài biên coi như tường")
	eq(s.is_solid(Vector2i(0, 22)), true, "ngoài biên dưới")

func test_event_active_from_flags() -> void:
	var s := _state()
	eq(s.event_active[7], true, "event#7 active (flags 62)")
	eq(s.event_active.size(), 78, "một cờ mỗi sự kiện")

func test_move_and_bump() -> void:
	var s := _state()
	var o := s.step(1)
	eq(s.player, Vector2i(7, 4), "đi phải một ô")
	eq(o[0].type, "moved", "báo moved")
	o = s.step(1)
	eq(s.player, Vector2i(7, 4), "tường (8,4) chắn")
	eq(o[0].type, "bumped", "báo bumped")
	eq(s.facing, 1, "vẫn quay mặt phải")

func test_no_control_no_move() -> void:
	var s := _state()
	s.control = false
	s.step(2)
	eq(s.player, Vector2i(6, 4), "mất điều khiển thì đứng yên")

func test_event_fires_once_when_not_repeat() -> void:
	# event#7 (5,3) flags 62: active, mọi hướng, không repeat. Đi từ (5,4) lên -> chạm tờ giấy.
	var s := GridState.new(LevelData.load_level(0), Vector2i(5, 4))
	var vm := _CountingVM.new(s)
	s.vm = vm
	s.step(4)
	eq(s.player, Vector2i(5, 4), "tờ giấy là vật thể, không đi vào được")
	eq(vm.runs, 1, "sự kiện chạy")
	eq(s.event_active[7], false, "không repeat thì tắt")
	s.step(4)
	eq(vm.runs, 1, "không chạy lần hai")

func test_event_direction_filter() -> void:
	# event#2 (12,11) flags 19 = repeat|active|16. field_425 = {32,4,8,16}[dir-1]: 16 = đang đi LÊN (dir 4).
	# Hốc đèn gắn trên tường: đứng dưới (12,12) đâm lên thì kích. event#48 cùng ô nhận mọi hướng.
	var s := GridState.new(LevelData.load_level(0), Vector2i(12, 12))
	var ids_up := s.events_at(Vector2i(12, 11), 4).map(func(e): return int(e.id))
	var ids_down := s.events_at(Vector2i(12, 11), 2).map(func(e): return int(e.id))
	eq(ids_up.has(2), true, "đi lên: #2 khớp cờ 16")
	eq(ids_up.has(48), true, "#48 mọi hướng khớp")
	eq(ids_down.has(2), false, "đi xuống: #2 không khớp")

func test_walk_on_ignores_direction() -> void:
	# Đi vào ô được (method_94) gọi method_216 với dir 0: không lọc hướng.
	var s := GridState.new(LevelData.load_level(0))
	s.events = [{"id": 0, "x": 7, "y": 4, "w": 1, "h": 1, "flags": 2 | 16,
		"commands": [{"op": 2, "args": [10, 255, 255]}]}]
	s.event_active = [true]
	s.step(1)   # đi phải vào (7,4), sự kiện chỉ có cờ "đi lên"
	eq(s.out.filter(func(o): return o.type == "say").size(), 1, "vẫn kích dù hướng khác")

func test_on_enter_runs_intro() -> void:
	# event#11 (5..7,4..5) cờ 190 có 128: chạy khi vào màn tại (6,4): cảnh B, câu 175, 5, 6.
	var s := GridState.new(LevelData.load_level(0))
	var out := s.enter()
	eq(out.filter(func(o): return o.type == "say").map(func(o): return o.text_id), [175, 5, 6], "thoại mở màn")
	eq(s.event_active[11], false, "chạy xong, không repeat thì tắt")

func test_aborted_event_stays_active() -> void:
	# event#49 (1,16) IF_HOLDING Pub key: chưa có chìa -> hủy, vẫn bật để thử lại (method_208).
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run(s.events[49])
	eq(s.event_active[49], true, "hủy giữa chừng không tắt sự kiện")

func test_pickup_needs_light() -> void:
	var s := GridState.new(LevelData.load_level(0), Vector2i(5, 4))
	for l in s.lights:
		l.on = 0
	s.step(4)
	eq(s.inventory.size(), 0, "tối thì không nhặt được tờ giấy")
	eq(s.event_active[7], true, "sự kiện vẫn chờ")

func test_pressure_plate_opens_and_closes_door() -> void:
	# event#0 bàn đạp (14,8) mở cửa (13,9) (ô 0x52). Đứng lên thì cửa thành sàn, bước ra thì đóng lại.
	var s := GridState.new(LevelData.load_level(0), Vector2i(14, 7))
	s.step(2)
	eq(s.player, Vector2i(14, 8), "đứng lên bàn đạp")
	eq(s.tiles[9][13], 0, "cửa mở")
	s.step(4)
	eq(s.tiles[9][13], 0x52, "rời bàn đạp: cửa đóng")

class _CountingVM extends ScriptVM:
	var runs := 0
	func run(e: Dictionary) -> bool:
		runs += 1
		return super(e)
