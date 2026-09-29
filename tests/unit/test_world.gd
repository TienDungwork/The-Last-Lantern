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
