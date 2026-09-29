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
	game.menu._start(game.menu.new_game)
	ok(not game.menu.visible and game.hud.visible, "trò chơi mới: vào màn")
	eq(game.state.level.index, 0, "màn 0")

	game.world.inventory.append(20)
	game.menu.world = game.world
	game.menu.open_inventory(game.menu._close)
	game.menu._toggle_equip(20, game.menu._close)
	eq(game.world.equipped, 20, "chọn món: trang bị")
	game.menu._toggle_equip(20, game.menu._close)
	eq(game.world.equipped, -1, "chọn lại: cất")
	game.menu._close()

	game.dialog.hide()
	game._say_queue.clear()
	game._unhandled_input(_esc())
	ok(game.menu.visible, "Esc: tạm dừng")
	game.menu._unhandled_input(_esc())
	ok(not game.menu.visible, "Esc lần nữa: tiếp tục")

	# Sự kiện cờ 128 (lặp) ở ô đang đứng chạy lại khi đóng menu trong game (field_434).
	var s: GridState = game.state
	s.events.append({"id": s.event_active.size(), "x": s.player.x, "y": s.player.y, "w": 1, "h": 1,
		"flags": GridState.F_ACTIVE | GridState.F_ON_ENTER | GridState.F_REPEAT, "commands": [{"op": 25, "args": []}]})
	s.event_active.append(true)
	s.energy = 1
	game._unhandled_input(_esc())
	eq(s.energy, 1, "menu đang mở: chưa chạy")
	game.menu._unhandled_input(_esc())
	eq(s.energy, s.max_energy, "đóng menu: chạy lại sự kiện cờ 128")
	game.free()
