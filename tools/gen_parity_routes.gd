extends SceneTree
## Sinh tuyến đi dạo cho test so sánh bản gốc (M2 C7): tests/parity/fixtures/levelNN_walk_route.json.
##   & $godot --headless --path . -s res://tools/gen_parity_routes.gd
## Rồi ghi trace từ game gốc: .\tools\record_parity.ps1 levelNN_walk
## Mỗi bước chỉ nhận khi mô phỏng của mình không đổi màn, không chết, không dịch chuyển, không có tu sĩ/boss và ô đến
## đang sáng: game gốc chạy thời gian thực (mất năng lượng trong tối, tu sĩ/boss di chuyển), tuyến phải tránh những thứ đó.

const STEPS := 30
const MAX_DARK := 6  # bước ở ô tối (~0,85 s mỗi bước ở bản gốc): 4 nấc năng lượng chịu được khoảng 10 s
const SKIP := [16]   # màn mở đầu: khóa điều khiển, tự đi
const OK_OUT := ["moved", "bumped", "say", "box_moved", "tile_changed", "light_changed", "music", "pointer",
	"map_reveal", "cutscene", "cutscene_end", "autosave"]

func _initialize() -> void:
	var spawns := _spawns()
	for n in 19:
		var path := "res://tests/parity/fixtures/level%02d_walk_route.json" % n
		if n in SKIP or not spawns.has(n) or FileAccess.file_exists(path):   # không ghi đè tuyến đã có trace
			continue
		var route := _route(n, spawns[n])
		if route.is_empty():
			print("màn %02d: bỏ qua" % n)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(route))
		print("màn %02d: %d bước từ %s" % [n, route.steps.size(), spawns[n]])
	quit()

## Điểm vào hợp lệ của mỗi màn = đích op 6 đầu tiên từ màn khác (điểm xuất phát mặc định nhiều màn nằm trong tường).
func _spawns() -> Dictionary:
	var r := {}
	for m in 19:
		for e in LevelData.load_level(m).events:
			if int(e.flags) & GridState.F_BY_ACTOR:
				continue
			for c in e.commands:
				var n := int(c.args[2]) if int(c.op) == 6 else -1
				if n >= 0 and n != m and n < 19 and not r.has(n):
					var s := GridState.new(LevelData.load_level(n))
					var p := Vector2i(int(c.args[0]), int(c.args[1]))
					if s.in_bounds(p) and not s.is_solid(p):
						r[n] = p
	return r

func _sim(n: int, spawn: Vector2i, steps: Array) -> Dictionary:
	var s := World.new().enter_level(n, spawn)
	var intro := s.enter().duplicate()
	var outs := []
	for d in steps:
		outs.append(s.step(d).duplicate())
	return {"s": s, "intro": intro, "outs": outs}

func _clean(s: GridState, out: Array) -> bool:
	## Hẹn giờ (op 24) đang bật: bản gốc đếm giờ thật (màn 12 thả tu sĩ sau 9 s), test so từng bước không đếm.
	return out.all(func(o): return o.type in OK_OUT) and s.control and s.forced.is_empty() \
		and s.guards.all(func(g): return g == null) and s.boss.is_empty() and s.boss2.is_empty() \
		and not range(s.events.size()).any(func(i): return s.event_active[i] and int(s.events[i].commands[0].op) == 24)

func _says(out: Array) -> int:
	return out.filter(func(o): return o.type == "say").size()

func _route(n: int, spawn: Vector2i) -> Dictionary:
	var first := _sim(n, spawn, [])
	if not _clean(first.s, first.intro):
		print("  màn %02d vào màn: %s control=%s forced=%s guards=%s boss=%s" % [n, first.intro.map(func(o): return o.type),
			first.s.control, first.s.forced, first.s.guards, first.s.boss.keys()])
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	seed(n)   # order.shuffle() dùng bộ ngẫu nhiên toàn cục
	var steps := []
	var dark := 0 if first.s.is_lit(spawn) else 1
	var last := 1 + rng.randi() % 4
	for i in STEPS:
		var order := [last, 1, 2, 3, 4]   # ưu tiên đi tiếp hướng cũ cho tuyến dài, không lắc tại chỗ
		order.shuffle()
		if rng.randf() < 0.7:
			order.push_front(last)
		var picked := -1
		for d in order:
			var r := _sim(n, spawn, steps + [d])
			var out: Array = r.outs.back()
			var lit: bool = r.s.is_lit(r.s.player)
			if _clean(r.s, out) and out.any(func(o): return o.type == "moved") and (lit or dark < MAX_DARK):
				picked = d
				dark += 0 if lit else 1
				break
		if picked < 0:
			break
		steps.append(picked)
		last = picked
	if steps.size() < 5:
		return {}
	var r := _sim(n, spawn, steps)
	var dismiss := {}
	for i in steps.size():
		var k := _says(r.outs[i])
		if k > 0:
			dismiss[str(i)] = k
	return {"level": n, "spawn": [spawn.x, spawn.y], "intro_dismiss": _says(r.intro), "steps": steps, "dismiss_after": dismiss}
