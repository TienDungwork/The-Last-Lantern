## Chụp cảnh một màn ra PNG rồi thoát. Chạy (cần GPU, không --headless):
##   & $godot --path . -s res://tools/snap.gd -- --level 0 --out snap/level_0.png
extends SceneTree

func _initialize() -> void:
	root.unfocusable = true   # không giành focus bàn phím của người đang làm việc
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
	if event >= 0:   # bỏ thoại/hiệu ứng đang chờ để thấy ngay kết quả sự kiện (vd. xoá màn)
		game._say_queue.clear()
		game.dialog.hide()
		game._fx_wait = 0.0
		game.state.vm.run(game.state.events[event])
		var ev: Array = game.state.out.duplicate()
		game.state.out.clear()
		game._handle(ev)
	if "--map" in args:   # --map: trang bản đồ + chú giải, mở mọi ô op 15 và bật mọi điểm op 4 có trong 19 màn
		for n in 19:
			for e in LevelData.load_level(n).events:
				for c in e.commands:
					if int(c.op) == 15:
						game.world.map_revealed.append(Vector2i(int(c.args[0]), int(c.args[1])))
					elif int(c.op) == 4:
						game.world.map_markers[int(c.args[0])] = true
		game.menu.world = game.world
		game.menu.open_map(game.menu._close, true)
	if "--minigame" in args:   # --minigame 0|1|2: mở minigame, bỏ màn chào, bắt đầu chơi
		game._say_queue.clear()
		game.dialog.hide()
		game._open_minigame(int(args[args.find("--minigame") + 1]))
		var mg = game.minigame.game
		mg.tick(0, 0)
		mg.press("left")
		mg.press("left")
		if mg is Minigames.Darts:
			mg.press("fire")
	if "--hero" in args:   # --hero clara
		game.world.hero = args[args.find("--hero") + 1]
		game.load_level(level, game.state.player)
		game._say_queue.clear()
		game.dialog.hide()
		game.skills = Skills.new(game.state)
		for i in 60:   # vài giây trong tối để thấy thanh virus
			game.rules.tick(50)
	if "--cd" in args:   # --cd: giả lập đã hạ Boss 1, chiêu 1 đang hồi, chiêu 2 đang băng
		game.world.bosses_down = 1
		game.skills.cd["kindle"] = 5200
		game.skills.bandage_ms = 1500
		game.hud.toast(Skills.TOO_DARK)
	if "--inv" in args:   # --inv: trang Túi đồ với vài món
		for id in [21, 21, 21, 6, 33, 7, 3, 0, 22]:
			game.world.add_item(id)
		game.menu.world = game.world
		game.menu.open_inventory(game.menu._close)
	if "--skills" in args:   # --skills: trang Kỹ năng với 7 điểm, đã mua vài cấp, 1 cấp chưa lưu
		for i in 7:
			game.world.add_item(21)
		game.world.upgrades = {"max_hp": 2, "thick_skin": 1} if game.world.hero == "daniel" else {"max_hp": 2, "hood": 1}
		game.menu.world = game.world
		game.menu.open_skills(game.menu._close)
		game.world.buy(game.world.UPGRADES[game.world.hero].keys()[0])
		game.menu.open_skills(game.menu._close)
	for i in frames:
		await process_frame
	var path := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", out)
	quit()
