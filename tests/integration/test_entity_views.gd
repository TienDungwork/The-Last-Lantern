extends "res://tests/lib/test_case.gd"
## game.tscn headless: view tạo/gỡ theo boss trong core.

func test_pointers_follow_dialog() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	while game.dialog.visible:
		game.dialog.hide()
		game.dialog.closed.emit()
		await tree.process_frame
	game.state.vm.run(game.state.events[19])
	var out: Array = game.state.out.duplicate()
	game.state.out.clear()
	game._handle(out)
	eq([game.hud.highlight, game._pointer_views.size()], [true, 0], "câu 17: HUD nháy")
	game.dialog.hide()
	game.dialog.closed.emit()
	eq([game.hud.highlight, game._pointer_views.size()], [false, 0], "câu 18: tắt nháy, chưa có mũi tên")
	game.dialog.hide()
	game.dialog.closed.emit()
	eq(game._pointer_views.keys(), [6], "hết thoại: mũi tên slot 6")
	game.free()

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
	game.state.player = Vector2i(14, 8)   # xa về bên phải để boss 2 không giết ngay
	game.state.spawn_boss2(Vector2i(1, 8))
	game.state.add_fireball(Vector2i(10, 8))
	await tree.process_frame
	eq([game._boss2_view.size(), game._fireball_views.size()], [1, 1], "boss 2 và lửa có hình")
	game.state.boss2 = {}
	game.state.fireballs.clear()
	await tree.process_frame
	eq([game._boss2_view.size(), game._fireball_views.size()], [0, 0], "SPECIAL 12: gỡ hình")
	game.free()
