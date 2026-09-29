## Chụp cảnh một màn ra PNG rồi thoát. Chạy (cần GPU, không --headless):
##   & $godot --path . -s res://tools/snap.gd -- --level 0 --out snap/level_0.png
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := 0
	var out := "snap/level.png"
	var steps: Array = []   # --steps 3,4 : đi trái rồi lên trước khi chụp
	var event := -1
	var frames := 20
	var at := Vector2i(-1, -1)
	for i in args.size():
		if args[i] == "--level":
			level = int(args[i + 1])
		if args[i] == "--out":
			out = args[i + 1]
		if args[i] == "--art":
			LevelBuilder.art = args[i + 1]
		if args[i] == "--steps":
			steps = Array(args[i + 1].split(",")).map(func(v): return int(v))
		if args[i] == "--event":   # chạy sự kiện N (vd. thả tu sĩ) trước khi chụp
			event = int(args[i + 1])
		if args[i] == "--frames":
			frames = int(args[i + 1])
		if args[i] == "--at":   # đặt người chơi ở ô x,y
			var p := args[i + 1].split(",")
			at = Vector2i(int(p[0]), int(p[1]))
	var game: Node = load("res://src/game.tscn").instantiate()
	game.show_title = "--title" in args   # --title: chụp màn tiêu đề
	game.start_level = level
	root.add_child(game)
	for i in 10:
		await process_frame
	if at.x >= 0:
		game.load_level(level, at)
	for d in steps:
		var ev: Array = game.state.step(d).duplicate()
		game.state.out.clear()
		game._handle(ev)
		for i in 15:
			await process_frame
	if event >= 0:
		game.state.vm.run(game.state.events[event])
	for i in frames:
		await process_frame
	var path := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", out)
	quit()
