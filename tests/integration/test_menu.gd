extends "res://tests/lib/test_case.gd"
## Menu: màn tiêu đề lúc mở game, trò chơi mới, túi đồ trang bị, Esc tạm dừng.

func _esc() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "menu"
	ev.pressed = true
	return ev

func test_title_new_game_inventory_pause() -> void:
	var game: Node = load("res://src/game.tscn").instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	ok(game.menu.visible and not game.hud.visible, "mở game: màn tiêu đề, ẩn HUD")
	eq(game._say_queue.size() + int(game.dialog.visible), 0, "nền tiêu đề không chạy thoại")
	eq([game.music_track, game.music.stream != null], [game.TITLE_MUSIC, true], "nhạc tiêu đề")
	game.menu._start(game.menu.new_game)
	ok(not game.menu.visible and game.hud.visible, "trò chơi mới: vào màn")
	eq(game.state.level.index, 16, "màn mở đầu 16")
	ok(game._cutscene.visible, "cảnh cắt Năm năm trước")
	eq(game.music_track, game.LEVEL_MUSIC[16], "nhạc màn 16")

	game.world.inventory.append(20)
	game.menu.world = game.world
	game.menu.open_inventory(game.menu._close)
	game.menu._toggle_equip(20, game.menu._close)
	eq(game.world.equipped, 20, "chọn món: trang bị")
	game.menu._toggle_equip(20, game.menu._close)
	eq(game.world.equipped, -1, "chọn lại: cất")
	game.world.inventory.append(Menu.MAP_ITEM)
	game.world.map_markers = {0: true}
	game.menu._toggle_equip(Menu.MAP_ITEM, game.menu._close)
	var maps: Array = game.menu._page.find_children("*", "TextureRect", true, false)
	eq(maps.size(), 2, "chọn bản đồ: mở trang bản đồ (nền + 1 điểm đánh dấu)")
	game.menu.open_map(game.menu._close, true)
	eq(game.menu._page.find_children("*", "TextureRect", true, false).size(), 2 + Menu.MAP_LEGEND.size(), "chú giải")
	game.world.equipped = -1
	game.world.add_item(29)
	game.world.add_item(0)
	game.menu.open_inventory(game.menu._close)
	ok(game.menu._page.find_children("*", "Label", true, false).any(func(l): return l.text == "1/6"), "số mảnh chìa")
	game.menu._toggle_equip(0, game.menu._close)
	ok(game.menu._page.find_children("*", "Label", true, false).any(
		func(l): return l.text == LevelData.text(228, game.menu.lang)), "chọn ghi chú: đọc")
	game.world.add_item(9)
	game.world.add_item(17)
	game.menu._toggle_equip(9, game.menu._close)
	eq(game.menu._combine, 9, "chọn xà phòng: chờ ghép")
	game.menu._toggle_equip(17, game.menu._close)
	eq([game.world.equipped, game.menu._combine], [18, -1], "ghép ra huy hiệu sáng")
	game.world.equipped = -1
	game.menu._close()

	game.dialog.hide()
	game._say_queue.clear()
	game._unhandled_input(_esc())
	ok(game.menu.visible, "Esc: tạm dừng")
	game.menu._unhandled_input(_esc())
	ok(not game.menu.visible, "Esc lần nữa: tiếp tục")

	# Sự kiện cờ 128 (lặp) ở ô đang đứng chạy lại khi đóng menu trong game (field_434).
	var s: GridState = game.state
	s.player = Vector2i(8, 5)   # ra khỏi ô mở đầu (10,5), nơi cờ 128 sẽ chiếu lại cảnh cắt
	game.dialog.hide()
	game._say_queue.clear()
	s.events.append({"id": s.event_active.size(), "x": s.player.x, "y": s.player.y, "w": 1, "h": 1,
		"flags": GridState.F_ACTIVE | GridState.F_ON_ENTER | GridState.F_REPEAT, "commands": [{"op": 25, "args": []}]})
	s.event_active.append(true)
	s.energy = 1
	game._unhandled_input(_esc())
	eq(s.energy, 1, "menu đang mở: chưa chạy")
	game.menu._unhandled_input(_esc())
	eq(s.energy, s.max_energy, "đóng menu: chạy lại sự kiện cờ 128")
	game.free()
