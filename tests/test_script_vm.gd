extends "res://tests/test_base.gd"

func _say_ids(out: Array) -> Array:
	var r := []
	for o in out:
		if o.type == "say":
			r.append(o.text_id)
	return r

func test_read_note_1() -> void:
	# event#7 tại (5,3): PICKUP Note 1, SAY 228 (chân dung 325), SAY 7 (chân dung 171), DISABLE 21,22,23
	var s := GridState.new(LevelData.load_level(0), Vector2i(5, 4))
	var out := s.step(4)
	eq(s.inventory, [0] as Array[int], "nhặt Note 1 (item 0)")
	eq(_say_ids(out), [228, 7], "hai câu thoại đúng thứ tự")
	var says := out.filter(func(o): return o.type == "say")
	eq(says[0].portrait, 325, "hình tờ giấy (khung 325)")
	eq(says[1].portrait, 171, "chân dung Hale")
	eq(s.event_active[21], false, "tắt #21")
	eq(s.event_active[22], false, "tắt #22")
	eq(s.event_active[23], false, "tắt #23")

func test_say_without_portrait() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 2, "args": [10, 255, 255]}]})
	eq(s.out[0].portrait, -1, "255,255 = không chân dung")

func test_player_control_and_move() -> void:
	# event#4 (9..10,1): control off, SAY 9, MOVE right 1, control on
	var s := GridState.new(LevelData.load_level(0), Vector2i(9, 1))
	s.vm.run(s.level.events[4])
	eq(s.player, Vector2i(10, 1), "kịch bản đẩy sang phải 1")
	eq(s.control, true, "trả lại điều khiển")

func test_if_holding_aborts() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var cmds := {"commands": [{"op": 11, "args": [3]}, {"op": 2, "args": [10, 255, 255]}]}
	s.vm.run(cmds)
	eq(s.out.size(), 0, "không cầm item 3 thì dừng, không SAY")
	s.inventory.append(3)
	s.vm.run(cmds)
	eq(s.out.size(), 1, "cầm rồi thì chạy tiếp")
	s.out.clear()
	s.vm.run({"commands": [{"op": 11, "args": [3 | 0x80]}, {"op": 2, "args": [10, 255, 255]}]})
	eq(s.out.size(), 0, "IF_NOT_HOLDING khi đang cầm thì dừng")

func test_set_tile_and_light() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 9, "args": [13, 2, 0, 82]}, {"op": 17, "args": [3, 0, 5]}]})
	eq(s.tiles[2][13], 82, "SET_TILE")
	eq(int(s.lights[3].radius), 5, "SET_LIGHT radius")
	eq(int(s.lights[3].on), 1, "SET_LIGHT bật đèn")

func test_teleport_same_level_and_exit_door() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 6, "args": [3, 9, 0]}]})
	eq(s.player, Vector2i(3, 9), "TELEPORT trong màn")
	s.vm.run({"commands": [{"op": 16, "args": [4, 13, 5]}]})
	eq(s.out.back().type, "change_level", "exit_door sang màn khác")
	eq(s.out.back().level, 5, "màn 5")

func test_enable_call_take_and_unknown() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.event_active[21] = false
	s.vm.run({"commands": [{"op": 20, "args": [21, 0]}]})
	eq(s.event_active[21], true, "ENABLE_EVENT")
	s.inventory.append(5)
	s.vm.run({"commands": [{"op": 19, "args": [5]}]})
	eq(s.inventory.has(5), false, "TAKE_ITEM")
	s.vm.run({"commands": [{"op": 22, "args": [7]}]})
	eq(s.inventory.has(0), true, "CALL_EVENT #7 nhặt Note 1")
	s.out.clear()
	s.vm.run({"commands": [{"op": 12, "args": [1]}]})
	eq(s.out[0].type, "todo", "lệnh chưa cài báo todo, không dừng")
	eq(s.out[0].op, 12, "kèm mã lệnh")
