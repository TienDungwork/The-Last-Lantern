extends "res://tests/lib/test_case.gd"
## Game thật: TELEPORT sang màn khác -> đóng hết thoại -> nạp màn mới, giữ World (túi đồ).

func test_teleport_loads_new_level_keeping_world() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
	tree.root.add_child(game)
	await tree.process_frame
	game.world.inventory.append(99)
	game.state.vm.run(game.state.events[67])   # TELEPORT (13,6) màn 14
	var out: Array = game.state.out.duplicate()
	game.state.out.clear()
	game._handle(out)
	for i in 20:
		if game.state.level.index == 14:
			break
		if game.dialog.visible:
			game.dialog.hide()
			game.dialog.closed.emit()
		await tree.process_frame
	eq(game.state.level.index, 14, "đã sang màn 14")
	eq(game.state.player, Vector2i(13, 6), "đứng đúng chỗ")
	ok(99 in game.state.inventory, "túi đồ theo sang màn mới")
	game.free()

func test_continue_from_save() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
	tree.root.add_child(game)
	await tree.process_frame
	var path := "user://test_continue.json"
	var w := World.new()
	w.inventory = [20] as Array[int]
	w.save_game(path, 3, Vector2i(1, 8))
	ok(game.continue_from_save(path), "có save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	eq([game.state.level.index, game.state.player, game.state.inventory], [3, Vector2i(1, 8), [20] as Array[int]], "đúng màn, chỗ, túi")
	eq(game.continue_from_save("user://khong_co.json"), false, "không có save")
	game.free()
