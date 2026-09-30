extends "res://tests/lib/test_case.gd"
## Tuyến Clara: bỏng khi sáng >= ngưỡng đau, virus trong tối, hồi ở vùng mờ, bắt sống, che đèn, Mắt đêm, Nuốt sáng, chuỗi ghi đè.

func _clara_at(lv: int) -> RulesClara:
	## Màn 0, tìm ô sàn có đúng độ sáng lv (lv = 0: tắt hết đèn).
	var w := World.new()
	w.hero = "clara"
	var s := GridState.new(LevelData.load_level(0), Vector2i(-1, -1), w)
	var r := RulesClara.new(s, 7)
	if lv == 0:
		for l in s.lights:
			l.on = 0
		r.refresh_light()
	for y in s.level.height:
		for x in s.level.width:
			var p := Vector2i(x, y)
			if not s.is_blocked(p) and s.light_level(p) == lv:
				s.player = p
				return r
	return null

func _run(r: RulesClara, ms: int) -> void:
	for i in ms / 100:
		r.tick(100)

func test_pain_threshold_follows_keys() -> void:
	var r := _clara_at(0)
	eq(r.pain_threshold(), 5, "0 mảnh: ngưỡng 5")
	r.s.world.grave_keys = 3
	eq(r.pain_threshold(), 4, "3 mảnh: ngưỡng 4")
	r.s.world.grave_keys = 6
	eq(r.pain_threshold(), 3, "6 mảnh: ngưỡng 3")

func test_bright_burns_cloak_blocks() -> void:
	var r := _clara_at(5)
	ok(r != null, "màn 0 có ô sáng 5")
	r.tick(1000)
	eq(r.s.energy, r.s.max_energy - 7, "sáng >= ngưỡng: 7 máu/giây")
	r.s.world.upgrades["hood"] = 2
	r.tick(1000)
	eq(r.s.energy, r.s.max_energy - 12, "Mũ trùm cấp 2: 5 máu/giây")
	r.s.world.equipped = GridState.CLOAK
	r.tick(1000)
	eq(r.s.energy, r.s.max_energy - 12, "áo choàng chặn bỏng")

func test_dark_no_hp_loss_but_virus_and_monster() -> void:
	var r := _clara_at(0)
	_run(r, 4900)
	eq([r.s.energy, r.monster], [r.s.max_energy, false], "tối hẳn: không mất máu, chưa hóa quái")
	_run(r, 100)
	eq([r.virus, r.monster], [100, true], "5 s tối hẳn: thanh đầy, hóa quái")
	r.s.lights[0].on = 1
	r.refresh_light()
	r.s.player = Vector2i(int(r.s.lights[0].x), int(r.s.lights[0].y))
	ok(r.s.light_level(r.s.player) > 0, "đứng cạnh đèn")
	r.s.energy = 1_000_000
	_run(r, 4900)
	ok(r.monster, "chưa về 0 thì vẫn là quái")
	_run(r, 100)
	eq([r.virus, r.monster], [0, false], "về 0: tỉnh lại")

func test_regen_in_dim_after_wait() -> void:
	var r: RulesClara = null
	for lv in [1, 2, 3, 4]:
		r = _clara_at(lv)
		if r != null:
			break
	ok(r != null, "có ô mờ")
	r.s.energy = 50
	_run(r, 1900)
	eq(r.s.energy, 50, "chưa đủ 2 s yên: chưa hồi")
	_run(r, 1100)
	eq(r.s.energy, 52, "sau đó 2 máu/giây")
	r.s.energy = r.s.max_energy - 1
	_run(r, 5000)
	eq(r.s.energy, r.s.max_energy, "không vượt tối đa")

func test_no_heal_from_scripts() -> void:
	var r := _clara_at(0)
	r.s.energy = 10
	r.s.vm._exec({}, 3, [])
	eq(r.s.energy, 10, "op 3 không hồi cho Clara")

func test_monk_captures_and_blend_in_dark() -> void:
	var r := _clara_at(1)
	if r == null:
		r = _clara_at(2)
	var s := r.s
	s.entry = Vector2i(1, 1)
	s.spawn_guard(s.player, 1, 0)
	s.inventory.append(5)
	r.tick(100)
	eq([s.player, s.energy > 0, s.inventory.has(5)], [Vector2i(1, 1), true, true], "bị bắt: về ô vào màn, còn sống, túi đồ giữ")
	ok(s.out.any(func(o): return o.get("text_id", -1) == 169), "câu bị bắt")
	var d := _clara_at(0)
	d.s.spawn_guard(d.s.player, 1, 0)
	var at := d.s.player
	d.tick(100)
	eq(d.s.player, at, "đứng ô sáng 0: tu sĩ không thấy")

func test_hidden_lamp_and_night_eye() -> void:
	var r := _clara_at(0)
	var s := r.s
	var i: int = range(s.level.lights.size()).filter(func(k): return int(s.lights[k].type) in [0, 1]).front()
	var L: Dictionary = s.lights[i]
	s.player = Vector2i(int(L.x), int(L.y))
	L.on = 1
	s.action()
	eq([s.carried, int(L.on)], [i, 0], "Clara cầm đèn: che trong áo, tắt")
	s.action()
	eq([s.carried, int(L.on)], [-1, 1], "đặt xuống: sáng lại")
	var item := {"id": s.events.size(), "x": 3, "y": 3, "w": 1, "h": 1, "flags": GridState.F_ACTIVE, "commands": [{"op": 10, "args": [5]}]}
	s.events.append(item)
	s.event_active.append(true)
	L.on = 0
	s.light = []
	ok(s.events_at(Vector2i(3, 3), 0).has(item), "Mắt đêm: vật phẩm ở ô tối vẫn kích")

func test_swallow_light_restores() -> void:
	var r := _clara_at(0)
	var s := r.s
	var L: Dictionary = s.lights[0]
	L.on = 1
	s.player = Vector2i(int(L.x), int(L.y))
	var sk := Skills.new(s)
	eq(sk.use(0), "", "Nuốt sáng")
	eq(int(L.on), 0, "đèn tắt")
	sk.tick(Skills.SWALLOW_MS[0] - 1)
	eq(int(L.on), 0, "chưa hết giờ")
	sk.tick(1)
	eq(int(L.on), 1, "hết giờ: bật lại")

func test_clara_strings_and_portraits() -> void:
	LevelData.hero = "clara"
	var t := LevelData.text(162)
	var p := [LevelData.portrait(1, 171), LevelData.portrait(1, 179), LevelData.portrait(120, 179), LevelData.portrait(1, 5)]
	LevelData.hero = "daniel"
	ok(t.begins_with("Clara"), "tuyến Clara dùng câu ghi đè")
	eq(p, [179, 171, 179, 5], "hoán đổi 171 ↔ 179, câu 120 giữ 179")
	ok(not LevelData.text(162).begins_with("Clara"), "tuyến Daniel dùng câu gốc")
