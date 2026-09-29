extends "res://tests/test_base.gd"

func _state() -> GridState:
	return GridState.new(LevelData.load_level(0))

func _only(s: GridState, keep: int) -> void:
	for i in s.lights.size():
		s.lights[i].on = 1 if i == keep else 0

func test_shape() -> void:
	var m := LightField.compute(_state())
	eq(m.size(), 22, "22 hàng")
	eq(m[0].size(), 19, "19 cột")

func test_lit_near_lamp_dark_far() -> void:
	# light#1: (6,5) type 4 on radius 4. Start (6,4) sát đèn.
	var m := LightField.compute(_state())
	ok(m[4][6] > 0, "ô start sáng")
	ok(m[4][6] <= 7, "kẹp 7")
	eq(m[13][16], 0, "(16,13) ngoài tầm mọi đèn đang bật: tối")

func test_wall_blocks_light() -> void:
	# Chỉ bật light#1 (6,5); tường cột x=8 ngăn phòng.
	var s := _state()
	_only(s, 1)
	var m := LightField.compute(s)
	ok(m[5][7] > 0, "(7,5) cùng phòng với đèn: sáng")
	eq(m[5][9], 0, "(9,5) sau tường (8,5): tối")
	eq(m[5][8], 0, "ô vật thể luôn 0")

func test_all_off_all_dark() -> void:
	var s := _state()
	for l in s.lights:
		l.on = 0
	var total := 0
	for row in LightField.compute(s):
		for v in row:
			total += v
	eq(total, 0, "không đèn thì toàn tối")

func test_directional_light_has_no_back() -> void:
	# light#11: (12,12) type 6 dir 2 on radius 3. Theo method_152, dir 2 chắn mọi ô
	# có x nhỏ hơn đèn -> (11,12) tối, (13,12) sáng.
	var s := _state()
	_only(s, 11)
	var m := LightField.compute(s)
	eq(m[12][11], 0, "phía sau đèn có hướng: tối")
	ok(m[12][13] > 0, "phía trước đèn có hướng: sáng")
