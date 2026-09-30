extends "res://tests/lib/test_case.gd"
## M4 đợt 1 (master plan 5.2): bóng đổ, chập chờn.

func _lamp_only() -> GridState:
	# Màn 0, chỉ bật light#1 (6,5) bán kính 4.
	var s := GridState.new(LevelData.load_level(0))
	for i in s.lights.size():
		s.lights[i].on = 1 if i == 1 else 0
	return s

func test_box_casts_shadow() -> void:
	var s := _lamp_only()
	var lamp := Vector2i(6, 5)
	var found := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var box: Vector2i = lamp + d   # bản gốc chỉ làm tối ô kề hộp; ô cách hộp 2 ô vẫn sáng
		var behind: Vector2i = lamp + d * 3
		if s.is_blocked(box) or s.is_blocked(lamp + d * 2) or s.is_blocked(behind):
			continue
		if LightField.compute(s, true)[behind.y][behind.x] == 0:
			continue
		found = true
		s.boxes[box] = 67
		eq(LightField.compute(s, true)[behind.y][behind.x], 0, "đèn – hộp – ô sau hộp tối")
		ok(LightField.compute(s)[behind.y][behind.x] > 0, "luật gốc: sáng lọt quanh hộp")
		s.boxes.erase(box)
		ok(LightField.compute(s, true)[behind.y][behind.x] > 0, "bỏ hộp thì sáng")
		break
	ok(found, "tìm được hàng đèn – hộp – ô sau")

func test_hard_shadow_never_brighter() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var soft := LightField.compute(s)
	var hard := LightField.compute(s, true)
	for y in soft.size():
		for x in soft[y].size():
			ok(hard[y][x] <= soft[y][x], "bóng đổ chỉ bớt sáng (%d,%d)" % [x, y])

func test_rules_main_uses_shadow_puzzle_does_not() -> void:
	var s := _lamp_only()
	s.boxes[Vector2i(6, 7)] = 67
	var r := RulesMain.new(s)
	var soft := LightField.compute(s)
	eq(s.light_map(), soft, "câu đố vẫn dùng ánh sáng gốc")
	eq(r.light, LightField.compute(s, true), "máu / hình vẽ dùng bóng đổ")

func test_flicker_sequence() -> void:
	var s := _lamp_only()
	s.lights[1].flicker = {"period_turns": 4, "off_turns": 1}
	var seq := []
	for i in 8:
		s.world.steps += 1
		s._tick_flicker()
		seq.append(int(s.lights[1].on))
	eq(seq, [1, 1, 1, 0, 1, 1, 1, 0], "tắt 1 bước mỗi 4 bước")

func test_flicker_does_not_relight_script_off() -> void:
	var s := _lamp_only()
	s.lights[0].flicker = {"period_turns": 2, "off_turns": 1}   # light#0 đang tắt từ đầu
	for i in 4:
		s.world.steps += 1
		s._tick_flicker()
		eq(int(s.lights[0].on), 0, "đèn tắt sẵn không bị chập chờn bật lên")

func test_op100_stops_flicker() -> void:
	var s := _lamp_only()
	s.lights[1].flicker = {"period_turns": 2, "off_turns": 1}
	s.vm.run({"flags": 0, "commands": [{"op": 100, "args": [1, 0]}]})
	for i in 4:
		s.world.steps += 1
		s._tick_flicker()
		eq(int(s.lights[1].on), 0, "op 100 ép tắt, hết chập chờn")
