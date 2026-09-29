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
	# event#2 (12,11) flags 19 = repeat|active|from_up; event#48 cùng ô nhận mọi hướng.
	var s := GridState.new(LevelData.load_level(0), Vector2i(12, 12))
	var ids_up := s.events_at(Vector2i(12, 11), 4).map(func(e): return int(e.id))
	var ids_down := s.events_at(Vector2i(12, 11), 2).map(func(e): return int(e.id))
	eq(ids_up.has(2), false, "đi lên = vào từ dưới: #2 không khớp from_up")
	eq(ids_up.has(48), true, "#48 mọi hướng vẫn khớp")
	eq(ids_down.has(2), true, "đi xuống = vào từ trên: #2 khớp")

class _CountingVM extends ScriptVM:
	var runs := 0
	func run(_e: Dictionary) -> void:
		runs += 1
