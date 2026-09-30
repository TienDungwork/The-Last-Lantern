extends "res://tests/lib/test_case.gd"
## 3 minigame ẩn: LCG giống Java, luật tính điểm / chết / nảy bóng cốt lõi.

func test_lcg_matches_java() -> void:
	var r := Minigames.Lcg.new(0)
	eq([r.next(), r.next(), r.next(), r.next(), r.next()], [0, 4232237, 178803790, 758674372, 1565954732], "dãy java.util.Random seed 0 (tính bằng Python)")
	r = Minigames.Lcg.new(7)
	eq(r.u(1 << 30), 1346621, ">>> 1")
	r.next()
	eq(r.s(14), -1, "% có dấu như Java")

func test_darts_score_and_sixth_dart_resets() -> void:
	var d: Minigames.Darts = Minigames.create(0, 0, 0)
	d.aim = Vector2i.ZERO
	d.press("fire")
	eq(d.score, 10, "hồng tâm = 10")
	d.aim = Vector2i(60 << 8, 0)
	d.press("fire")
	eq(d.score, 10, "ngoài bia: 10 - 60/6 = 0 điểm")
	for i in 3:
		d.press("fire")
	eq(d.thrown.size(), 5, "5 phi tiêu")
	d.press("fire")
	eq([d.thrown.size(), d.score, d.hi], [0, 0, 10], "phi tiêu thứ 6 xoá lượt, giữ điểm cao")

func _worm_room(level_id := 3) -> Minigames.Worm:
	var w: Minigames.Worm = Minigames.create(1, level_id, 0)
	w.need_new = false
	w.grid.fill(Minigames.Worm.EMPTY)
	w.head = Vector2i(10, 10)
	w.tail = Vector2i(11, 10)
	w.put(10, 10, Minigames.Worm.HEAD)
	w.put(11, 10, Minigames.Worm.BODY_L)
	w.press("left")
	return w

func test_worm_eats_last_gem_and_clears() -> void:
	var w := _worm_room()
	w.put(9, 10, Minigames.Worm.GEM)
	w.tick(w.period, 0)
	eq([w.score, w.head, w.tail, w.cleared], [60, Vector2i(9, 10), Vector2i(10, 10), true], "ăn đom đóm cuối cùng = qua màn")

func test_worm_dies_on_bug_except_level_15() -> void:
	var w := _worm_room()
	w.put(9, 10, Minigames.Worm.BUG)
	w.put(9, 12, Minigames.Worm.GEM)
	w.tick(w.period, 0)
	ok(w.dead, "đâm bọ = chết")
	w = _worm_room(15)
	w.put(9, 10, Minigames.Worm.BUG)
	w.bugs = [{"pos": Vector2i(9, 10), "dir": 1}]
	w.put(9, 12, Minigames.Worm.GEM)
	w.tick(w.period, 0)
	eq([w.dead, w.score, w.bugs[0].pos.x], [false, 41, -1], "màn 15: ăn bọ +40 (+1 như ô đất)")

func test_worm_crate_shrinks_and_rock_falls() -> void:
	var w := _worm_room()
	w.put(12, 10, Minigames.Worm.BODY_L)
	w.put(11, 10, Minigames.Worm.BODY_L)
	w.tail = Vector2i(12, 10)
	w.put(9, 10, Minigames.Worm.CRATE)
	w.put(5, 5, Minigames.Worm.ROCK)
	w.put(20, 20, Minigames.Worm.GEM)
	w.tick(w.period, 0)
	ok(w.shrinking and w.score == 30, "ăn hộp: +30, co đuôi")
	eq(w.cell(5, 6), Minigames.Worm.ROCK, "đá rơi xuống ô trống")
	w.tick(w.period, 0)
	eq([w.shrinking, w.tail], [true, Vector2i(10, 10)], "đuôi co một ô mỗi nhịp")
	w.tick(w.period, 0)
	eq(w.shrinking, false, "đuôi sát đầu thì thôi co")

func test_worm_levels_are_fixed_by_seed() -> void:
	var a: Minigames.Worm = Minigames.create(1, 3, 0)
	var b: Minigames.Worm = Minigames.create(1, 3, 0)
	a.generate()
	b.generate()
	ok(a.grid == b.grid and a.grid.has(Minigames.Worm.GEM), "cùng màn = cùng bản đồ, có đom đóm")
	eq(a.cell(a.head.x, a.head.y), Minigames.Worm.HEAD, "đặt đầu giun")

func test_bong_paddle_bounce_and_game_over() -> void:
	var g: Minigames.Bong = Minigames.create(2, 0, 0)
	g.tick(0, 0)   # khởi tạo
	g.running = true
	g.bx[0] = 6 << 8
	g.by[0] = g.me_y
	g.bvx[0] = -(10 << 8)
	g.bvy[0] = 0
	g.tick(100, 0)
	ok(g.bvx[0] > 0 and g.score == 1, "vợt đỡ: bóng bật lại, +1")
	g.by[0] = Minigames.Bong.PAD_MAX + (30 << 8)
	g.bx[0] = 2 << 8
	g.bvx[0] = -(10 << 8)
	g.bvy[0] = 0
	g.tick(1000, 0)
	ok(g.over and g.score == -9, "lọt quả cuối = thua, -10")

func test_codes_and_high_scores_saved() -> void:
	var w := World.new()
	var got := []
	for c in "9676":
		got += w.type_digit(int(c))
	eq(got, [World.MINIGAME_CODE + 1], "mã 9676 mở Lantern Worm")
	w.minigame_hi = [12, 340, 56]
	var path := "user://test_minigame_save.json"
	w.save_game(path, 0, Vector2i(1, 1))
	eq(World.load_game(path).world.minigame_hi, [12, 340, 56], "điểm cao minigame lưu cùng save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_segment_cross() -> void:
	eq(Minigames.cross(0, 0, 32, 0, 16, -32, 16, 32), Vector2i(16, 0), "cắt")
	eq(Minigames.cross(0, 0, 320, 0, 32, -32, 32, 32), Vector2i(30, 0), "tham số làm tròn theo 1/32 như bản gốc")
	eq(Minigames.cross(0, 0, 320, 0, 32, 10, 32, 32), null, "không cắt")
