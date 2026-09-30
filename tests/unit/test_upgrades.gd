extends "res://tests/lib/test_case.gd"
## Nâng cấp: điểm = muffin/vòng tay đã nhặt trừ phần đã tiêu; mỗi bảng tổng 18; boss mở khóa.

func _with_muffins(hero: String, n: int) -> World:
	var w := World.new()
	w.hero = hero
	for i in n:
		w.add_item(21)
	return w

func test_every_upgrade_has_menu_text() -> void:
	for hero in World.UPGRADES:
		for n in World.UPGRADES[hero]:
			ok(Menu.UPGRADE_TEXT.has(n), "trang Kỹ năng có tên cho %s" % n)

func test_skill_page_discards_unsaved_points() -> void:
	var m := Menu.new()
	m.world = _with_muffins("daniel", 2)
	var hp: int = m.world.max_energy
	m.open_skills(func(): pass)
	m.world.buy("max_hp")   # nút +
	m._close()
	eq(m.world.upgrade_level("max_hp"), 0, "đóng khi chưa Lưu: bỏ điểm vừa cộng")
	eq(m.world.max_energy, hp, "máu tối đa trả lại")
	m.open_skills(func(): pass)
	m.world.buy("max_hp")
	m._skill_snap = []      # nút Lưu
	m._close()
	eq(m.world.upgrade_level("max_hp"), 1, "đã Lưu: giữ")
	m.free()

func test_each_table_costs_18() -> void:
	for hero in World.UPGRADES:
		var total := 0
		for u in World.UPGRADES[hero].values():
			total += int(u[0]) * int(u[1])
		eq(total, 18, "%s: tổng giá = 18 muffin" % hero)

func test_points_and_prices() -> void:
	var w := _with_muffins("daniel", 3)
	eq(w.upgrade_points(), 3, "3 muffin = 3 điểm")
	ok(w.buy("kindle"), "chủ động giá 2")
	eq(w.upgrade_points(), 1, "còn 1")
	ok(not w.buy("bandage"), "thiếu điểm thì từ chối")
	ok(w.buy("thick_skin"), "bị động giá 1")
	eq(w.upgrade_points(), 0, "hết điểm")

func test_max_level_and_unknown() -> void:
	var w := _with_muffins("daniel", 18)
	ok(w.buy("lamp_keeper") and w.buy("lamp_keeper"), "mua đủ 2 cấp")
	ok(not w.buy("lamp_keeper"), "vượt cấp tối đa thì từ chối")
	ok(not w.buy("swallow_light"), "nâng cấp của nhân vật kia thì từ chối")

func test_max_hp_raises_and_heals() -> void:
	var w := _with_muffins("clara", 2)
	w.energy = 60
	w.buy("max_hp")
	eq([w.max_energy, w.energy], [110, 70], "cấp 1: tối đa 110, hồi 10")
	w.buy("max_hp")
	eq([w.max_energy, w.energy], [125, 85], "cấp 2: tối đa 125, hồi 15")

func test_boss_unlocks() -> void:
	var w := _with_muffins("clara", 18)
	ok(not w.unlocked("call_shadow") and not w.buy("call_shadow"), "Gọi bóng khóa tới Boss 1")
	var s := w.enter_level(3)
	s.vm.run({"commands": [{"op": 30, "args": [8]}]})
	eq(w.bosses_down, 1, "SPECIAL 8 (Boss 1 chết) mở mốc 1")
	ok(w.unlocked("call_shadow") and w.buy("call_shadow"), "hạ Boss 1 thì mua được")
	ok(not w.unlocked("one_of_them"), "Một trong số họ chờ Boss 2")
	w.enter_level(14).vm.run({"commands": [{"op": 30, "args": [12]}]})
	ok(w.unlocked("one_of_them"), "SPECIAL 12 (Boss 2 chết) mở mốc 2")
	w.hero = "daniel"
	ok(w.unlocked("kindle") and w.unlocked("fire_wall") and w.unlocked("twin_lamp"), "Daniel: đủ 4 chiêu sau Boss 2")

func test_save_roundtrip_and_sanitize() -> void:
	var path := "user://test_upgrades_save.json"
	var w := _with_muffins("clara", 5)
	w.bosses_down = 1
	w.buy("call_shadow")
	w.save_game(path, 0, Vector2i(1, 1))
	var w2: World = World.load_game(path).world
	eq([w2.hero, w2.bosses_down, w2.upgrade_level("call_shadow"), w2.upgrade_points()], ["clara", 1, 1, 3], "lưu/nạp")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d.upgrades = {"call_shadow": 99, "kindle": 1}
	d.hero = "x"
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(d))
	var w3: World = World.load_game(path).world
	eq([w3.hero, w3.upgrades], ["daniel", {"kindle": 1}], "save sửa tay: hero lạ -> Daniel, bỏ nâng cấp không thuộc bảng")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
