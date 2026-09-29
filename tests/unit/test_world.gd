extends "res://tests/lib/test_case.gd"

func test_inventory_and_energy_survive_level_change() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	s.inventory.append(3)
	s.energy = 2
	var s14 := w.enter_level(14)
	eq(s14.inventory, [3] as Array[int], "túi đồ giữ qua màn")
	eq(s14.energy, 2, "năng lượng giữ qua màn")

func test_persist_flag_survives_reentry() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	s.vm.run({"commands": [{"op": 9, "args": [13, 2, 0 | 0x80, 82]}, {"op": 21, "args": [7, 0 | 0x80]}]})
	eq(s.tiles[2][13], 82, "áp ngay cho màn hiện tại")
	var again := w.enter_level(0)
	eq(again.tiles[2][13], 82, "vào lại vẫn còn ô đã đổi")
	eq(again.event_active[7], false, "vào lại sự kiện vẫn tắt")

func test_non_persist_lost_on_reentry() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	s.vm.run({"commands": [{"op": 9, "args": [13, 2, 0, 82]}]})
	eq(w.enter_level(0).tiles[2][13], int(LevelData.load_level(0).grid[2][13]), "không persist: nạp lại từ .dat")

func test_other_level_change_applies_on_entry() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	s.vm.run({"commands": [{"op": 21, "args": [3, 14 | 0x80]}]})
	eq(w.enter_level(14).event_active[3], false, "tắt sự kiện màn 14 từ màn 0")

func test_enable_then_disable_cancels() -> void:
	var w := World.new()
	w.log_change(World.ENABLE, 5, 2)
	w.log_change(World.DISABLE, 5, 2)
	eq(w.log.size(), 0, "bật rồi tắt = bỏ cả hai (method_205)")
	w.log_change(World.SET_TILE, 5, 0, 1, 1, 9)
	w.log_change(World.SET_TILE, 5, 0, 1, 1, 10)
	eq(w.log.size(), 1, "đổi cùng ô: ghi đè")
	eq(w.log[0].value, 10, "giá trị mới nhất")

func test_save_load_roundtrip() -> void:
	var w := World.new()
	w.inventory = [3, 20] as Array[int]
	w.equipped = 20
	w.energy = 2
	w.max_energy = 5
	w.creatures_killed = 7
	w.play_ms = 123456
	w.map_markers = {4: true, 12: true}
	w.map_revealed = [Vector2i(35, 29)]
	w.log_change(World.SET_TILE, 3, 0, 3, 5, 0)
	var path := "user://test_save.json"
	w.save_game(path, 14, Vector2i(20, 15))
	var r := World.load_game(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	eq([r.level, r.at], [14, Vector2i(20, 15)], "màn và vị trí")
	var w2: World = r.world
	eq([w2.inventory, w2.equipped, w2.energy, w2.max_energy, w2.creatures_killed, w2.play_ms],
		[[3, 20] as Array[int], 20, 2, 5, 7, 123456], "chỉ số")
	eq([w2.map_markers, w2.map_revealed], [{4: true, 12: true}, [Vector2i(35, 29)]], "bản đồ")
	eq(w2.enter_level(3).tiles[5][3], 0, "sổ thay đổi áp lại được")
	eq(World.load_game("user://khong_co.json"), {}, "không có file: rỗng")

func test_cycle_equipped() -> void:
	var w := World.new()
	w.inventory = [3, 20] as Array[int]
	w.cycle_equipped()
	eq(w.equipped, 3, "tay không -> món đầu")
	w.cycle_equipped()
	eq(w.equipped, 20, "món sau")
	w.cycle_equipped()
	eq(w.equipped, -1, "hết vòng: bỏ trang bị")

func test_taking_equipped_item_unequips() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	s.inventory.append(20)
	w.equipped = 20
	s.vm.run({"commands": [{"op": 19, "args": [20]}]})
	eq(w.equipped, -1, "op 19 lấy mất áo đang mặc")

func test_autosave_points() -> void:
	# method_112: vào màn 14, TELEPORT khi đang ở màn 14 (lưu chỗ đứng trước khi đi), SPECIAL 18.
	var w := World.new()
	var s := w.enter_level(14, Vector2i(20, 15))
	s.vm.run({"commands": [{"op": 6, "args": [1, 1, 3]}]})
	eq(s.out.filter(func(o): return o.type == "autosave").map(func(o): return o.at), [Vector2i(20, 15)], "rời phố")
	var bar := w.enter_level(0)
	bar.vm.run({"commands": [{"op": 6, "args": [1, 1, 14]}]})
	eq(bar.out.filter(func(o): return o.type == "autosave").size(), 0, "rời màn khác: không lưu")
	bar.vm.run({"commands": [{"op": 30, "args": [18]}]})
	eq(bar.out.filter(func(o): return o.type == "autosave").size(), 1, "SPECIAL 18")
