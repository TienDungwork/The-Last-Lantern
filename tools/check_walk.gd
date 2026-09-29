## Kiểm tra giữ phím là đi liên tục. Chạy: & $godot --headless --path . -s res://tools/check_walk.gd
## Giữ "xuống" 1 giây từ (6,4) màn 0: phải đi được nhiều ô (không chỉ 1), và dừng khi thả phím.
extends SceneTree

func _initialize() -> void:
	var game: Node = load("res://game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	Input.action_press("move_down")
	await create_timer(1.0).timeout
	Input.action_release("move_down")
	var y_hold: int = game.state.player.y
	await create_timer(0.5).timeout
	var y_after: int = game.state.player.y
	print("giữ 1 s: y 4 -> %d; sau khi thả: %d" % [y_hold, y_after])
	var ok := y_hold >= 7 and y_after <= y_hold + 1
	print("WALK OK" if ok else "WALK FAIL")
	quit(0 if ok else 1)
