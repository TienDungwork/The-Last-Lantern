## Chụp cảnh một màn ra PNG rồi thoát. Chạy (cần GPU, không --headless):
##   & $godot --path . -s res://tools/snap.gd -- --level 0 --out snap/level_0.png
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := 0
	var out := "snap/level.png"
	var steps: Array = []   # --steps 3,4 : đi trái rồi lên trước khi chụp
	for i in args.size():
		if args[i] == "--level":
			level = int(args[i + 1])
		if args[i] == "--out":
			out = args[i + 1]
		if args[i] == "--steps":
			steps = Array(args[i + 1].split(",")).map(func(v): return int(v))
	var game: Node = load("res://src/game.tscn").instantiate()
	game.start_level = level
	root.add_child(game)
	for i in 10:
		await process_frame
	for d in steps:
		game._handle(game.state.step(d))
		for i in 15:
			await process_frame
	for i in 20:
		await process_frame
	var path := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", out)
	quit()
