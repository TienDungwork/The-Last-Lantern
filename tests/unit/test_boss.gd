extends "res://tests/lib/test_case.gd"
## Boss 1 (SPECIAL 2/8), class_10.method_196. Màn 3: event#11 (5,2) thả boss, event#14 chạy khi boss chết xong.

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	return r

func _tick(s: GridState, ms: int, rng: RandomNumberGenerator) -> void:
	for i in ms / 100:
		s.tick_boss(100, rng)

func _cornered() -> GridState:
	## Boss ở (5,2) bị hộp chặn 3 phía (phía trên là tường): đứng yên.
	var s := GridState.new(LevelData.load_level(3), Vector2i(1, 8))
	s.vm.run(s.events[11])
	for p in [Vector2i(4, 2), Vector2i(6, 2), Vector2i(5, 3)]:
		s.boxes[p] = 67
	return s

func test_special_2_spawns_boss_that_blocks() -> void:
	var s := GridState.new(LevelData.load_level(3), Vector2i(1, 8))
	s.vm.run(s.events[11])
	eq(s.boss.tile, Vector2i(5, 2), "boss ở ô của sự kiện")
	ok(s.is_blocked(Vector2i(5, 2)), "boss chặn đường")

func test_touch_hurts_once_every_2s() -> void:
	var s := _cornered()
	var rng := _rng()
	s.player = Vector2i(5, 2)
	s.tick_boss(100, rng)
	eq(s.energy, s.max_energy - 1, "chạm lần đầu: -1 ngay")
	_tick(s, 2000, rng)
	eq(s.energy, s.max_energy - 1, "chưa quá 2 s: không trừ tiếp")
	s.tick_boss(100, rng)
	eq(s.energy, s.max_energy - 2, "quá 2 s: -1 nữa")

func test_burns_in_light_then_special_8() -> void:
	var s := _cornered()
	var rng := _rng()
	s.lights[0].x = 5
	s.lights[0].y = 3
	s.lights[0].radius = 6
	s.light = []
	ok(s.light_level(Vector2i(5, 2)) >= 4, "ô boss sáng >= 4")
	_tick(s, 6300, rng)
	eq(s.boss.dying, false, "6,3 s: còn sống (máu 25600, mất 4/ms)")
	s.tick_boss(100, rng)
	eq(s.boss.dying, true, "6,4 s: gục")
	s.energy = 1
	_tick(s, 4900, rng)
	ok(not s.boss.is_empty(), "chưa đủ 5 s")
	s.tick_boss(100, rng)
	ok(s.boss.is_empty(), "5 s sau: event#14 SPECIAL 8 gỡ boss")
	eq(s.tile_at(Vector2i(3, 5)), 0, "event#14 mở lối (3,5)")
	eq(s.energy, s.max_energy, "event#14 hồi năng lượng")

## Boss 2 (SPECIAL 10/11/12), method_199/200. Màn 14: event#107 (3,19) thả, #118..120 lửa cột 20, #121 khi chết.

func _street(player: Vector2i) -> GridState:
	var s := GridState.new(LevelData.load_level(14), player)
	s.vm.run(s.events[107])
	return s

func test_boss2_sweeps_right_and_kills_behind() -> void:
	var s := _street(Vector2i(10, 19))
	var rng := _rng()
	s.tick_boss2(100, rng)
	eq(s.energy, s.max_energy, "người ở trước mặt: an toàn")
	for i in 30:
		s.tick_boss2(100, rng)
	eq(s.boss2.pos.x / GridState.BOSS2_TILE, 4, "3 s (5/3 px<<8 mỗi ms): qua 1 ô")
	s.player = Vector2i(5, 18)
	s.tick_boss2(100, rng)
	eq(s.energy, 0, "người ở cột trước mặt boss hoặc sau nó: chết (mọi hàng)")

func test_boss2_fireball_kills() -> void:
	var s := _street(Vector2i(20, 19))
	s.step(1)
	s.step(3)   # bước vào (20,19) chạy event#119: SPECIAL 11 thả lửa ngay ô đó
	eq(s.fireballs, [Vector2i(20, 19)], "có lửa")
	s.tick_boss2(100, _rng())
	eq(s.energy, 0, "đứng trên lửa: chết")

func test_boss2_eats_lamps_then_special_12() -> void:
	var s := _street(Vector2i(15, 19))
	var rng := _rng()
	for i in 4:   # 4 đèn mang được đặt ngay cột trước mặt, mỗi đèn -6400 máu và tắt
		var L: Dictionary = s.lights[i]
		L.merge({"x": 4, "y": 19, "type": 0, "on": 1, "radius": 2}, true)
	s.tick_boss2(100, rng)
	eq(int(s.lights[0].on), 0, "đèn bị dập")
	ok(s.boss2.is_empty(), "hết máu: event#121 SPECIAL 12 gỡ boss")
	eq(s.event_active[118], false, "event#121 tắt lửa")

func test_chases_visible_player() -> void:
	var s := GridState.new(LevelData.load_level(3), Vector2i(6, 8))
	s.spawn_boss(Vector2i(10, 8))
	var rng := _rng()
	_tick(s, 4000, rng)
	eq(s.boss.goal, Vector2i(6, 8), "thấy người chơi (hàng 8 trống): đích = người chơi")
	ok(s.boss.tile.x <= 8, "4 s (800 ms/ô): đã áp sát, đang ở %s" % s.boss.tile)
