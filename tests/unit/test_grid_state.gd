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

func test_box_extracted_from_grid() -> void:
	var s := GridState.new(LevelData.load_level(0))
	eq(s.boxes, {Vector2i(16, 8): 67}, "màn 0 có một hộp ở (16,8)")
	eq(s.tiles[8][16], 0, "ô dưới hộp là sàn")

func test_push_box_onto_plate_opens_door() -> void:
	# Đẩy hộp (16,8) sang trái hai lần: hộp nằm trên bàn đạp (14,8), cửa (13,9) mở và giữ mở khi người đi.
	var s := GridState.new(LevelData.load_level(0), Vector2i(17, 8))
	s.step(3)
	eq(s.out[0], {"type": "box_moved", "from": Vector2i(16, 8), "to": Vector2i(15, 8)}, "đẩy lần 1")
	eq(s.player, Vector2i(16, 8), "người vào chỗ hộp cũ")
	s.step(3)
	ok(s.boxes.has(Vector2i(14, 8)), "hộp trên bàn đạp")
	eq(s.tiles[9][13], 0, "cửa mở")
	s.step(1)
	eq(s.tiles[9][13], 0, "người đi, hộp vẫn đè: cửa mở")

func test_push_blocked_becomes_pull() -> void:
	# Hộp sát tường: đẩy vào thì người lùi một ô và kéo hộp theo.
	var s := GridState.new(LevelData.load_level(0), Vector2i(16, 8))
	s.boxes = {Vector2i(15, 8): 67}
	s.set_tile(Vector2i(14, 8), 0x38)
	s.step(3)
	eq(s.boxes.keys(), [Vector2i(16, 8)], "hộp vào chỗ người đứng")
	eq(s.player, Vector2i(17, 8), "người lùi một ô")
	eq(s.facing, 3, "vẫn quay mặt về hộp")
	s.set_tile(Vector2i(15, 8), 0x38)
	s.step(3)   # trước hộp là tường, sau lưng (18,8) là tường: kẹt, không ai nhúc nhích
	eq(s.player, Vector2i(17, 8), "kẹt: người đứng yên")
	eq(s.boxes.keys(), [Vector2i(16, 8)], "kẹt: hộp đứng yên")

func test_box_blocks_light() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var before: Array = s.light_map().duplicate(true)
	s.boxes.clear()
	s.light = []
	ok(s.light_map() != before, "bỏ hộp thì bản đồ sáng đổi")

func _light_at(s: GridState, p: Vector2i) -> int:
	for i in s.lights.size():
		if Vector2i(int(s.lights[i].x), int(s.lights[i].y)) == p:
			return i
	return -1

func test_carry_lantern() -> void:
	# Đèn lồng tắt ở (8,13) màn 0: nhặt thì bật, đi thì đèn theo, đặt xuống thì ở lại.
	var s := GridState.new(LevelData.load_level(0), Vector2i(8, 13))
	var i := _light_at(s, Vector2i(8, 13))
	s.action()
	eq(s.carried, i, "đang cầm")
	eq(int(s.lights[i].on), 1, "nhặt lên thì bật")
	s.step(3)
	eq(Vector2i(int(s.lights[i].x), int(s.lights[i].y)), Vector2i(7, 13), "đèn đi theo")
	ok(s.light_map()[13][6] > 0, "ô trước mặt sáng")
	s.action()
	s.step(1)
	eq(Vector2i(int(s.lights[i].x), int(s.lights[i].y)), Vector2i(7, 13), "đặt xuống thì ở lại")

func test_nothing_to_pick_up() -> void:
	var s := GridState.new(LevelData.load_level(0), Vector2i(7, 13))
	s.action()
	eq(s.carried, -1, "ô trống: tay không")

func test_flashlight_turns_without_stepping() -> void:
	var s := GridState.new(LevelData.load_level(0), Vector2i(16, 2))
	var i := _light_at(s, Vector2i(16, 2))
	s.action()
	s.step(3)
	eq(s.player, Vector2i(16, 2), "đổi hướng: đứng yên")
	eq(int(s.lights[i].dir), 3, "đèn pin quay trái")
	s.step(3)
	eq(s.player, Vector2i(15, 2), "cùng hướng: bước")

func test_candle_burns_down() -> void:
	# Nến (2,2) màn 6 bán kính 5: life 11, mỗi bước -1, bán kính = life >> 1.
	var s := GridState.new(LevelData.load_level(6), Vector2i(2, 2))
	var i := _light_at(s, Vector2i(2, 2))
	s.action()
	s.step(1)
	eq(int(s.lights[i].radius), 5, "bước 1: life 10")
	s.step(1)
	eq(int(s.lights[i].radius), 4, "bước 2: life 9")

func test_timer_fires_after_its_ms() -> void:
	# event#42 màn 0: hẹn giờ 1200 ms (0,0,4,176), tắt sẵn, bật bằng op 20.
	var s := GridState.new(LevelData.load_level(0))
	s.tick_timers(5000)
	eq(s.out.size(), 0, "đang tắt: không đếm")
	s.event_active[42] = true
	s.tick_timers(1199)
	eq(s.out.size(), 0, "chưa tới giờ")
	s.tick_timers(1)
	eq(s.out.filter(func(o): return o.type == "say").map(func(o): return o.text_id), [8, 9], "tới giờ: chạy")
	eq(s.event_active[42], false, "không repeat: tắt")

func test_wall_switch_toggles_spotlight_once() -> void:
	# method_92: đâm công tắc ô 71 (khung 63) -> bật/tắt đèn loại 5 ở ô trái/phải, ô thành 70 (đã gạt, gạt lại không có tác dụng).
	var s := GridState.new(LevelData.load_level(0), Vector2i(3, 13))
	eq(int(s.lights[9].on), 0, "đèn chiếu (3,13) đang tắt")
	s.step(3)
	eq(int(s.lights[9].on), 1, "gạt công tắc: đèn bật")
	eq(s.tile_at(Vector2i(2, 13)), 70, "công tắc đổi sang đã gạt")
	s.step(3)
	eq(int(s.lights[9].on), 1, "gạt lại: không đổi")

func test_bulb_socket_take_and_put() -> void:
	# Op 23 (event#2 màn 0, đèn #11 ở hốc (12,11) đang sáng): đâm vào lấy bóng, đâm hốc tối thì lắp bóng.
	var s := GridState.new(LevelData.load_level(0), Vector2i(12, 12))
	s.step(4)
	eq(s.bulbs, 1, "lấy được một bóng")
	eq(int(s.lights[11].on), 0, "hốc tắt")
	eq(s.out.filter(func(o): return o.type == "say").map(func(o): return o.text_id), [17, 18], "hướng dẫn bóng đèn lần đầu")
	s.step(4)
	eq(s.bulbs, 0, "lắp lại bóng")
	eq(int(s.lights[11].on), 1, "hốc sáng lại")
	s.step(4)
	s.bulbs = 0
	s.step(4)
	eq(s.bulbs, 0, "hốc tối, hết bóng: không làm gì")
	eq(int(s.lights[11].on), 0, "vẫn tối")

func test_bulbs_are_per_level() -> void:
	var w := World.new()
	var s := w.enter_level(0, Vector2i(12, 12))
	s.step(4)
	eq(s.bulbs, 1, "có bóng")
	eq(w.enter_level(0).bulbs, 0, "vào lại màn: bóng về 0 (field_278 reset khi nạp màn)")

class _CountingVM extends ScriptVM:
	var runs := 0
	func run(e: Dictionary) -> bool:
		runs += 1
		return super(e)
