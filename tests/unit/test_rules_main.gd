extends "res://tests/lib/test_case.gd"
## RulesMain: máu mất theo độ sáng ô (0 nhanh, 1–2 chậm, >= 3 không mất), không hồi dần.

func _at_level(lv: int) -> RulesMain:
	## Màn 0, tắt hết đèn rồi tìm ô sàn có đúng độ sáng lv (lv = 0 thì ô nào cũng tối).
	var s := GridState.new(LevelData.load_level(0))
	var r := RulesMain.new(s, 7)
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

func test_dark_drains_fast() -> void:
	var r := _at_level(0)
	r.tick(1000)
	eq(r.s.energy, r.s.max_energy - 10, "tối hẳn: 10 máu/giây")

func test_dim_drains_slow() -> void:
	for lv in [1, 2]:
		var r := _at_level(lv)
		if r == null:
			continue
		r.tick(1000)
		eq(r.s.energy, r.s.max_energy - 4, "sáng %d: 4 máu/giây" % lv)

func test_thick_skin_reduces_both_tiers() -> void:
	for lv in [1, 2]:
		var r := _at_level(0)
		r.s.world.upgrades["thick_skin"] = lv
		r.tick(1000)
		eq(r.s.energy, r.s.max_energy - (10 - lv), "Da dày cấp %d: tối hẳn %d máu/giây" % [lv, 10 - lv])
		var m := _at_level(1)
		if m != null:
			m.s.world.upgrades["thick_skin"] = lv
			m.tick(1000)
			eq(m.s.energy, m.s.max_energy - (4 - lv), "Da dày cấp %d: mờ %d máu/giây" % [lv, 4 - lv])

func test_bright_no_drain_no_regen() -> void:
	var r := _at_level(5)
	ok(r != null, "màn 0 có ô sáng 5")
	r.s.energy = 40
	r.tick(10_000)
	eq(r.s.energy, 40, "đủ sáng: không mất, không hồi")

func test_cloak_blocks_drain() -> void:
	var r := _at_level(0)
	r.s.world.equipped = GridState.CLOAK
	r.tick(5000)
	eq(r.s.energy, r.s.max_energy, "mặc áo choàng tu sĩ: không mất")

func _run(r: RulesMain, ms: int) -> void:
	for i in ms / 100:
		r.tick(100)

func test_cloak_time_limit() -> void:
	var r := _at_level(0)
	r.s.world.equipped = GridState.CLOAK
	_run(r, RulesMain.CLOAK_WEAR_MS - 100)
	eq(r.s.world.equipped, GridState.CLOAK, "chưa đủ 30 s: vẫn mặc")
	eq(r.s.energy, r.s.max_energy, "lúc còn mặc không mất máu")
	_run(r, 100)
	eq(r.s.world.equipped, -1, "mặc đủ 30 s không có tu sĩ: tự cởi")
	r.s.world.equipped = GridState.CLOAK
	_run(r, 1000)
	eq(r.s.world.equipped, -1, "đang chờ thì mặc lại bị cởi ngay")
	eq(r.s.energy, r.s.max_energy - 11, "cởi rồi thì tối lại mất máu (1,1 s tính cả nhịp vừa cởi)")
	r.s.energy = 1_000_000   # chờ hết thời gian nghỉ trong tối mà không chết
	_run(r, RulesMain.CLOAK_REST_MS)
	r.s.energy = r.s.max_energy
	r.s.world.equipped = GridState.CLOAK
	_run(r, 1000)
	eq(r.s.world.equipped, GridState.CLOAK, "chờ xong thì mặc lại được")

func test_cloak_timer_paused_near_monk() -> void:
	var r := _at_level(0)
	r.s.spawn_guard(r.s.player, 1, 0)
	r.s.world.equipped = GridState.CLOAK
	r.tick(RulesMain.CLOAK_WEAR_MS * 2)
	eq(r.s.world.equipped, GridState.CLOAK, "có tu sĩ gần: không đếm giờ, cải trang theo kịch bản không hỏng")
	eq(r.s.energy, r.s.max_energy, "không bị bắt, không mất máu")

func test_death_at_zero() -> void:
	var r := _at_level(0)
	r.s.energy = 5
	r.tick(1000)
	eq(r.s.energy, 0, "không xuống âm")
	ok(r.s.out.any(func(o): return o.type == "death"), "hết máu thì báo death")

func test_old_save_scaled() -> void:
	var path := "user://test_old_save.json"
	var w := World.new()
	w.save_game(path, 0, Vector2i(1, 1))
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d.energy = 3
	d.max_energy = 4
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(d))
	var w2: World = World.load_game(path).world
	eq([w2.energy, w2.max_energy], [75, 100], "save cũ 3/4 nấc -> 75/100 máu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
