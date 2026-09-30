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
	w.steps = 42
	w.minigames = [0, 2]
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
	eq([w2.steps, w2.minigames], [42, [0, 2]], "số bước, minigame đã tìm")
	eq([w2.map_markers, w2.map_revealed], [{4: true, 12: true}, [Vector2i(35, 29)]], "bản đồ")
	eq(w2.enter_level(3).tiles[5][3], 0, "sổ thay đổi áp lại được")
	eq(World.load_game("user://khong_co.json"), {}, "không có file: rỗng")

func test_map_flood_fill() -> void:
	# citymap hàng 1: "...#############......" -> cột 3..15 là đường liền nhau
	var w := World.new()
	eq(w.map_cells()[1][3], 1, "chưa mở: đường chưa tới")
	w.map_revealed = [Vector2i(3, 1)]
	var m := w.map_cells()
	eq([m[1][3], m[1][15], m[1][0]], [2, 2, 0], "loang hết đoạn đường liền, không lan ra ô không phải đường")
	var s := w.enter_level(14)
	s.vm.run({"commands": [{"op": 15, "args": [3, 1]}]})
	eq(w.map_revealed.size(), 1, "op 15 trùng điểm không ghi thêm")

func test_stacked_items() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	for i in 5:
		w.add_item(29)
	eq([w.inventory, w.grave_keys], [[29] as Array[int], 5], "mảnh chìa cộng dồn một ô")
	s.vm.run({"commands": [{"op": 10, "args": [29]}]})
	ok(s.out.any(func(o): return o.get("text_id") == 233), "mảnh thứ 6: câu 233")
	w.add_item(6)
	w.add_item(6)
	w.remove_item(6)
	eq([w.inventory.has(6), w.coins], [true, 1], "tiêu một đồng xu còn một")
	w.remove_item(6)
	eq(w.inventory.has(6), false, "hết xu thì mất khỏi túi")
	w.inventory.assign([0])
	w.add_item(9)
	eq(w.inventory, [9, 0] as Array[int], "món mới chèn trước ghi chú")

func test_combine_items() -> void:
	var w := World.new()
	w.add_item(9)
	w.add_item(17)
	ok(w.can_combine(9), "xà phòng ghép được khi có huy hiệu bẩn")
	ok(w.combine(9, 17), "xà phòng + huy hiệu bẩn")
	eq([w.inventory.has(18), w.inventory.has(17), w.inventory.has(9), w.equipped], [true, false, true, 18],
		"ra huy hiệu sáng, mất huy hiệu bẩn, giữ xà phòng, cầm kết quả")
	ok(not w.combine(9, 3), "không có công thức")
	w.add_item(1)
	w.add_item(16)
	ok(w.combine(16, 1), "dây thừng + nam châm")
	eq([w.inventory.has(31), w.inventory.has(1), w.inventory.has(16)], [true, true, true], "không mất món nào")
	ok(not w.can_combine(1), "đã có dây gắn nam châm: không ghép lại")

func test_camera_flash() -> void:
	var w := World.new()
	var s := w.enter_level(0)
	w.add_item(World.CAMERA)
	w.add_item(World.BATTERY)
	w.add_item(World.BATTERY)
	ok(w.combine(World.CAMERA, World.BATTERY), "máy ảnh + pin")
	eq([w.flash, w.battery, w.equipped, w.inventory.has(World.BATTERY)], [true, 2, World.CAMERA, false], "lắp pin")
	s.player = Vector2i(10, 10)
	s.action()
	var L: Dictionary = s.lights[s.flash_light]
	eq([int(L.on), Vector2i(int(L.x), int(L.y)), w.battery], [1, s.player, 1], "flash sáng ở chỗ đứng, tốn 1 pin")
	ok(s.is_lit(s.player), "chỗ đứng sáng")
	eq(s.step(1).size(), 0, "đang flash không đi được")
	s.tick_flash(GridState.FLASH_MS)
	eq([int(L.on), s.flash_ms], [0, 0], "hết 1,5 s thì tắt")
	s.action()
	s.tick_flash(GridState.FLASH_MS)
	s.action()
	eq([w.battery, int(L.on)], [0, 0], "hết pin: không chụp được")

func test_bonus_codes() -> void:
	var w := World.new()
	for c in "7825530":
		w.type_digit(int(c))
	eq(w.inventory.has(GridState.CLOAK), false, "gõ lệch: chưa nhận")
	for c in "7825537":
		w.type_digit(int(c))
	ok(w.inventory.has(GridState.CLOAK), "mã áo choàng")
	for c in "6833467":
		w.type_digit(int(c))
	eq([w.battery, w.infinite_battery], [99, true], "mã pin vô hạn")

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
