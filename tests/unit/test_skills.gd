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
