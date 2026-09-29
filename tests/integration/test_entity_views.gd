extends "res://tests/lib/test_case.gd"
## game.tscn headless: view tạo/gỡ theo boss trong core.

func test_boss_view_follows_core() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	game.load_level(3, Vector2i(1, 8))
	while game.dialog.visible:   # thoại màn 0 còn mở thì _process đứng
		game.dialog.hide()
		game.dialog.closed.emit()
		await tree.process_frame
	game.state.vm.run(game.state.events[11])
	await tree.process_frame
	await tree.process_frame
	eq(game._boss_view.size(), 1, "có boss: có hình")
	game.state.boss = {}
	await tree.process_frame
	eq(game._boss_view.size(), 0, "SPECIAL 8: gỡ hình")
	game.free()
