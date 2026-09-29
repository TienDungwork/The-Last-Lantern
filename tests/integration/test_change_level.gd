extends "res://tests/lib/test_case.gd"
## Game thật: TELEPORT sang màn khác -> đóng hết thoại -> nạp màn mới, giữ World (túi đồ).

func test_teleport_loads_new_level_keeping_world() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
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
