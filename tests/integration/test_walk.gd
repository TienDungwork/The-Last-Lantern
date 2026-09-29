extends "res://tests/lib/test_case.gd"
## Chạy cả game.tscn (headless) và giả lập giữ phím.

func test_hold_key_walks_continuously() -> void:
	# Giữ "xuống" 1 giây từ (6,4) màn 0: đi được nhiều ô, thả phím thì dừng.
	var game: Node = load("res://src/game.tscn").instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	Input.action_press("move_down")
	await tree.create_timer(1.0).timeout
	Input.action_release("move_down")
	var y_hold: int = game.state.player.y
	await tree.create_timer(0.5).timeout
	ok(y_hold >= 7, "giữ 1 s phải đi ≥ 3 ô, mới tới y=%d" % y_hold)
	ok(game.state.player.y <= y_hold + 1, "thả phím thì dừng (y %d -> %d)" % [y_hold, game.state.player.y])
	game.free()
