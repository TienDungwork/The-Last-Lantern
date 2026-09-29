extends "res://tests/test_base.gd"
## So GridState/LightField với trace ghi từ game gốc (tools/parity.ps1). Không có trace thì in SKIP.

func _lines(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var out := []
	for line in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n", false):
		out.append(JSON.parse_string(line))
	return out

func test_level00_route_matches_original() -> void:
	var trace := _lines("res://tests/parity/level00_trace.jsonl")
	if trace.is_empty():
		print("SKIP: chưa có level00_trace.jsonl, chạy tools/parity.ps1 -level 0")
		return
	var F: Dictionary = LevelData.read_json("res://tools/parity_fields.json")
	var route: Dictionary = LevelData.read_json("res://tests/parity/level00_route.json")
	var s := GridState.new(LevelData.load_level(0), Vector2i(int(route.spawn[0]), int(route.spawn[1])))
	eq(s.max_energy, int(trace[0][F.max_energy]), "năng lượng tối đa mặc định")
	eq(s.energy, int(trace[0][F.energy]), "năng lượng đầu màn")
	# Thoại mở màn (sự kiện #11 on_action) bản gốc đã chạy trước dòng trace đầu; M2 mới cài on_action.
	var rules := RulesClassic.new(s, 0)
	_compare_light(trace[0], F, rules.light, s, "đầu màn")
	for i in route.steps.size():
		s.step(int(route.steps[i]))
		rules.refresh_light()
		var t: Dictionary = trace[i + 1]
		eq(s.player, Vector2i(int(t[F.x]), int(t[F.y])), "bước %d vị trí" % i)
		eq(s.facing, int(t[F.facing]), "bước %d hướng mặt" % i)
		_compare_light(t, F, rules.light, s, "bước %d" % i)
	eq(s.inventory.has(0), true, "đã nhặt Note 1")

func _compare_light(t: Dictionary, F: Dictionary, light: Array, s: GridState, tag: String) -> void:
	## Bản gốc ghi độ sáng vào chính ô sàn (giá trị < 8) của lưới [y][x].
	var g: Array = t[F.grid]
	var bad := []
	for y in s.level.height:
		for x in s.level.width:
			if s.tiles[y][x] < 8 and int(g[y][x]) != light[y][x]:
				bad.append("(%d,%d) gốc %d, mình %d" % [x, y, int(g[y][x]), light[y][x]])
	ok(bad.is_empty(), "%s: độ sáng lệch %d ô: %s" % [tag, bad.size(), ", ".join(bad.slice(0, 8))])
