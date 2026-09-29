extends "res://tests/lib/test_case.gd"
## game.tscn headless: view tạo/gỡ theo boss trong core.

func test_pointers_follow_dialog() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
	tree.root.add_child(game)
	await tree.process_frame
	skip_fx(game)
	while game.dialog.visible:
		game.dialog.hide()
		game.dialog.closed.emit()
		await tree.process_frame
	game.state.vm.run(game.state.events[19])
	var out: Array = game.state.out.duplicate()
	game.state.out.clear()
	game._handle(out)
	eq([game.hud.highlight, game._pointer_views.size()], [0, 0], "câu 17: nháy nhóm bóng đèn")
	game.dialog.hide()
	game.dialog.closed.emit()
	eq([game.hud.highlight, game._pointer_views.size()], [-1, 0], "câu 18: tắt nháy, chưa có mũi tên")
	game.dialog.hide()
	game.dialog.closed.emit()
	eq(game._pointer_views.keys(), [6], "hết thoại: mũi tên slot 6")
	game.free()

func test_cutscene_overlay_during_lines() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
	game.start_level = 2
	tree.root.add_child(game)
	await tree.process_frame
	while game.dialog.visible:
		game.dialog.hide()
		game.dialog.closed.emit()
	game.state.vm.run(game.state.events[18])   # màn 2: tranh 184 (khúc xương) + câu 56
	var out: Array = game.state.out.duplicate()
	game.state.out.clear()
	game._handle(out)
	ok(game._cutscene.visible and game.dialog.visible, "đang cảnh cắt: màn đen + thoại")
	eq(game._cutscene.get_child(0).texture, Portraits.texture(184), "đúng tranh")
	game.dialog.hide()
	game.dialog.closed.emit()
	ok(not game._cutscene.visible, "hết thoại: gỡ màn đen")
	game.state.sun_beam = {"n": 2, "at": Vector2i(4, 1)}
	game._sync_entities()
	eq(game._beam_view.get_child_count(), 2, "hai tia nắng")
	game.free()

func test_door_wipe_then_change_level() -> void:
	# Màn 15: event#9 hiện con chó; event#1 SPECIAL 7 rồi sang màn 8, chỉ đổi màn khi xoá màn xong.
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
	game.start_level = 15
	tree.root.add_child(game)
	await tree.process_frame
	game._say_queue.clear()
	game.dialog.hide()
	game.state.vm.run(game.state.events[9])
	game._sync_entities()
	eq(game._dog_view.get_child_count(), 5, "con chó: 4 mảnh + hẹn giờ nháy")
	game.state.vm.run(game.state.events[1])
	var out: Array = game.state.out.duplicate()
	game.state.out.clear()
	game._handle(out)
	ok(game._wipe.visible and game.state.level.index == 15, "đang xoá màn, chưa đổi màn")
	game._process(Wipe.TIME + 0.01)
	eq([game._wipe.visible, game.state.level.index], [false, 8], "xoá xong: tắt lớp phủ, sang màn 8")
	game.builder.build(GridState.new(LevelData.load_level(14)))
	eq(game.builder.find_children("*", "Timer", true, false).size(), 1, "màn 14: biển PUB có đèn chớp")
	game.free()

func test_boss_view_follows_core() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = false
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
