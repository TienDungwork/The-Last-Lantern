extends "res://tests/lib/test_case.gd"
## Chiêu chủ động: hồi chiêu, Tay quen, Băng bó chỉ ở chỗ sáng, Mồi lửa thắp lại nến tàn.

func _tile(s: GridState, lit: bool) -> Vector2i:
	for y in s.level.height:
		for x in s.level.width:
			var p := Vector2i(x, y)
			if s.tile_at(p) < 8 and (s.light_level(p) >= Skills.BANDAGE_MIN_LIGHT) == lit:
				return p
	return Vector2i(-1, -1)

func _run(sk: Skills, ms: int) -> void:
	for i in ms / 100:
		sk.tick(100)

func test_bandage_needs_light_and_heals() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	s.player = _tile(s, false)
	eq(sk.use(1), Skills.TOO_DARK, "tối: báo, không băng")
	eq(int(sk.cd.get("bandage", 0)), 0, "tối: không tốn hồi chiêu")
	s.player = _tile(s, true)
	s.energy = 50
	eq(sk.use(1), "", "sáng: bắt đầu băng")
	_run(sk, 3000)
	eq(s.energy, 60, "đứng yên 3 s: hồi 10")
	eq(int(sk.cd.bandage), 20000, "hồi chiêu 20 s")

func test_bandage_cancelled_by_moving() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	s.player = _tile(s, true)
	s.energy = 50
	sk.use(1)
	_run(sk, 1000)
	s.player += Vector2i(1, 0)
	_run(sk, 3000)
	eq(s.energy, 50, "đi: hủy, không hồi")
	eq(int(sk.cd.get("bandage", 0)), 0, "hủy: không tốn hồi chiêu")

func test_quick_hands_and_kindle_lv2_cooldowns() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	eq(sk.cooldown_max("bandage"), 20000, "gốc")
	s.world.upgrades["quick_hands"] = 2
	eq(sk.cooldown_max("bandage"), 15000, "Tay quen 2: -25%")
	eq(sk.cooldown_max("twin_lamp"), 1000, "Đèn đôi không bị Tay quen")
	s.world.upgrades["kindle"] = 2
	eq(sk.cooldown_max("kindle"), 4500, "Mồi lửa 2: 6 s, rồi -25%")

## Ô đầu dãy 7 ô trống liền nhau theo hàng ngang (ô 0..6).
func _row7(s: GridState) -> Vector2i:
	for y in s.level.height:
		for x in s.level.width - 6:
			if range(7).all(func(k): return not s.is_blocked(Vector2i(x + k, y))):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_fire_wall_stops_monk_then_burns_out() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	var p := _row7(s)
	ok(p.x >= 0, "màn 0 có dãy 7 ô trống")
	s.player = p
	s.facing = 1
	eq(sk.use(2), "", "chưa hạ Boss 1: chưa mở, im lặng")
	eq(int(sk.cd.get("fire_wall", 0)), 0, "chưa mở: không tốn hồi chiêu")
	s.world.bosses_down = 1
	eq(sk.use(2), "", "ném được")
	var fire := p + Vector2i(4, 0)
	ok(fire in s.fire_tiles, "rơi xa 4 ô")
	ok(s.light_level(fire) >= 6, "ô lửa sáng mức 6")
	eq(int(sk.cd.fire_wall), 50000, "hồi chiêu 50 s")
	s.spawn_guard(p + Vector2i(6, 0), 3, 5)   # đi sang trái qua ô lửa
	for i in 60:
		s.tick_guards(100)
	eq(s.guard_tile(0), p + Vector2i(5, 0), "tu sĩ dừng trước lửa")
	eq(int(s.guards[0].dir), 1, "và quay đầu")
	_run(sk, Skills.FIRE_MS)
	eq(s.fire_tiles, [], "8 s: lửa tắt")
	ok(s.light_level(fire) < 6, "hết sáng")
	for i in 30:
		s.tick_guards(100)
	eq(s.guard_tile(0), p + Vector2i(1, 0), "lửa tắt: tu sĩ đi tiếp")

func test_fire_wall_ends_when_boss_douses_one_tile() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	s.world.bosses_down = 1
	s.player = _row7(s)
	s.facing = 1
	sk.use(2)
	var n := s.lights.size()
	s.lights[n - 3].on = 0   # Boss 2 dập một ô đang cháy (tick_boss2 đặt on = 0)
	ok(sk.tick(100), "vẽ lại")
	eq(s.fire_tiles, [], "cả vệt tắt")
	ok(s.lights.slice(n - 3).all(func(L): return int(L.on) == 0), "3 đèn lửa tắt")

func test_twin_lamp_swaps_hand_and_back() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var sk := Skills.new(s)
	s.world.bosses_down = 2
	s.player = _row7(s)
	eq(sk.use(3), Skills.NO_TWIN, "tay không, lưng không: báo")
	var a := s.lights.size()
	s.lights.append({"x": s.player.x, "y": s.player.y, "type": 0, "on": 1, "radius": 3, "dir": 0, "life": 0})
	s.carried = a
	eq(sk.use(3), "", "đổi được")
	eq([s.carried, s.carried_back], [-1, a], "đèn sang lưng, tay trống")
	s.step(1)
	eq(Vector2i(int(s.lights[a].x), int(s.lights[a].y)), s.player, "đèn lưng đi theo")
	eq(int(s.lights[a].on), 1, "vẫn sáng")
	s.action()
	eq(s.carried, -1, "E không nhặt đèn lưng")
	eq(sk.use(3), "", "đang hồi chiêu 1 s")
	eq(s.carried_back, a, "chưa đổi")
	_run(sk, 1000)
	sk.use(3)
	eq([s.carried, s.carried_back], [a, -1], "đổi lại về tay")

func test_kindle_relights_burnt_candle_with_boost() -> void:
	var s := GridState.new(LevelData.load_level(6))
	var sk := Skills.new(s)
	s.world.upgrades["kindle"] = 1
	var i := -1
	for k in s.level.lights.size():
		if int(s.lights[k].type) == 2:
			i = k
			break
	ok(i >= 0, "màn 6 có nến")
	var L: Dictionary = s.lights[i]
	var full := int(s.level.lights[i].radius)
	L.on = 0
	L.life = 0
	L.radius = 0
	s.player = Vector2i(int(L.x), int(L.y)) + Vector2i(1, 0)
	eq(sk.use(0), "", "có nến tàn kề bên")
	eq(int(L.on), 1, "nến sáng lại")
	eq(int(L.life), full * 2 + 1, "nạp đầy")
	eq(int(L.radius), full + 1, "cấp 1: sáng rộng thêm 1 ô")
	eq(int(sk.cd.kindle), 8000, "hồi chiêu 8 s")
	eq(sk.use(0), "", "đang hồi chiêu: không làm gì")
	_run(sk, Skills.KINDLE_BOOST_MS)
	eq(int(L.radius), full, "hết 10 s: về bán kính thường")
	eq(sk.use(0), Skills.NO_LAMP, "hết hồi chiêu, không còn đèn tắt: báo")
