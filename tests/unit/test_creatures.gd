extends "res://tests/lib/test_case.gd"
## Sinh vật bóng tối (op 14 không bit 0x80): class_10.method_233/236/237/238.

func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _tick(s: GridState, ms: int, rng: RandomNumberGenerator) -> void:
	for i in ms / 100:
		s.tick_creatures(100, rng)

func _lit_run(s: GridState, n: int) -> Array:
	## [ô đầu, hướng] sao cho n+1 ô liên tiếp đều sáng.
	for y in s.level.height:
		for x in s.level.width:
			for dir in [1, 2, 3, 4]:
				var okay := true
				for i in n + 1:
					if s.light_level(Vector2i(x, y) + GridState.DIR_VEC[dir] * i) == 0:
						okay = false
						break
				if okay:
					return [Vector2i(x, y), dir]
	return []

func test_op14_spawns_walking_creature() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 14, "args": [10, 7, 4, 5]}], "flags": 0})
	eq(s.creatures.size(), 1, "một sinh vật")
	eq(s.creatures[0].state, GridState.C_MOVING, "có quãng đường: đang đi")
	eq(s.creatures[0].to, Vector2i(10, 2), "đi lên 5 ô")

func test_dies_after_1s_in_light_then_vanishes() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var run := _lit_run(s, 6)
	ok(not run.is_empty(), "màn 0 có đoạn 7 ô sáng")
	s.spawn_creature(run[0], run[1], 6)   # đi 6 ô x 200 ms qua toàn ô sáng
	var rng := _rng()
	_tick(s, 900, rng)
	eq(s.creatures[0].state, GridState.C_MOVING, "900 ms: còn sống")
	_tick(s, 100, rng)
	eq(s.creatures[0].state, GridState.C_DYING, "1000 ms trong sáng: chết")
	eq(s.world.creatures_killed, 1, "đếm số diệt")
	_tick(s, 1000, rng)
	eq(s.creatures[0], null, "1 s sau thì biến mất")

func test_flees_to_darkest_neighbour() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var run := _lit_run(s, 0)
	var p: Vector2i = run[0]
	s.spawn_creature(p, 1, 0)
	s.tick_creatures(10, _rng())
	var best := 99
	for d in GridState.DIR_VEC.values():
		if not s.is_blocked(p + d):
			best = mini(best, s.light_level(p + d))
	eq(s.creatures[0].state, GridState.C_MOVING, "bị chiếu: bỏ chạy")
	eq(s.light_level(s.creatures[0].to), best, "về ô kề tối nhất")

func test_box_crushes_creature() -> void:
	var s := GridState.new(LevelData.load_level(0), Vector2i(17, 8))
	s.spawn_creature(Vector2i(15, 8), 1, 0)
	s.step(3)
	eq(s.creatures[0], null, "hộp đẩy vào ô sinh vật: mất")

func test_random_spawn_on_dark_floor_each_second() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var rng := _rng(7)
	for i in 30:
		var before := s.creatures.filter(func(c): return c != null).size()
		s.tick_creatures(1000, rng)
		for c in s.creatures:
			if c != null and c.state == GridState.C_DECIDE and c.age == 0:
				var t: Vector2i = c.to
				ok(s.tile_at(t) < 8 and not s.is_lit(t), "sinh ở sàn tối %s" % t)
		ok(s.creatures.filter(func(c): return c != null).size() <= before + 1, "tối đa 1 con mỗi giây")
	ok(s.creatures.any(func(c): return c != null), "30 s thì có sinh vật")
	var street := GridState.new(LevelData.load_level(14))
	_tick(street, 5000, rng)
	eq(street.creatures.size(), 0, "màn 14 (phố) không sinh")
