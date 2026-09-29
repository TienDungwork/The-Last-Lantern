extends "res://tests/lib/test_case.gd"
## So GridState/LightField với trace ghi từ game gốc (tools/record_parity.ps1 <tuyến>). Không có trace thì in SKIP.

func _lines(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var out := []
	for line in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n", false):
		out.append(JSON.parse_string(line))
	return out

func _replay(name: String) -> GridState:
	## Đi lại tuyến, so vị trí/hướng/sáng/ô vật thể từng bước. Trả state cuối (null nếu chưa có trace).
	var trace := _lines("res://tests/parity/fixtures/%s_trace.jsonl" % name)
	if trace.is_empty():
		print("SKIP: chưa có %s_trace.jsonl, chạy tools/record_parity.ps1 %s" % [name, name])
		return null
	var F: Dictionary = LevelData.read_json("res://tests/parity/fixtures/fields.json")
	var route: Dictionary = LevelData.read_json("res://tests/parity/fixtures/%s_route.json" % name)
	var s := GridState.new(LevelData.load_level(int(route.level)), Vector2i(int(route.spawn[0]), int(route.spawn[1])))
	eq(s.max_energy, int(trace[0][F.max_energy]), "năng lượng tối đa mặc định")
	eq(s.energy, int(trace[0][F.energy]), "năng lượng đầu màn")
	# Sự kiện on-enter bản gốc đã chạy trước dòng trace đầu; chúng không đổi vị trí/sáng ở các tuyến này.
	var rules := RulesClassic.new(s, 0)
	_compare(trace[0], F, rules.light, s, "đầu màn")
	for i in route.steps.size():
		s.step(int(route.steps[i]))
		rules.refresh_light()
		var t: Dictionary = trace[i + 1]
		eq(s.player, Vector2i(int(t[F.x]), int(t[F.y])), "bước %d vị trí" % i)
		eq(s.facing, int(t[F.facing]), "bước %d hướng mặt" % i)
		_compare(t, F, rules.light, s, "bước %d" % i)
	return s

func test_level00_route_matches_original() -> void:
	var s := _replay("level00")
	if s:
		eq(s.inventory.has(0), true, "đã nhặt Note 1")

func test_level00_box_push_pull_plate() -> void:
	# Đẩy hộp lên bàn đạp (cửa mở), đi ra, quay lại kéo hộp khỏi bàn đạp (cửa đóng).
	_replay("level00_box")

func _compare(t: Dictionary, F: Dictionary, light: Array, s: GridState, tag: String) -> void:
	## Bản gốc ghi độ sáng vào chính ô sàn (giá trị < 8) của lưới [y][x]; ô vật thể giữ mã ô (>= 8).
	var g: Array = t[F.grid]
	var bad := []
	for y in s.level.height:
		for x in s.level.width:
			var orig := int(g[y][x])
			if (orig >= 8) != (s.tiles[y][x] >= 8):
				bad.append("(%d,%d) ô gốc %d, mình %d" % [x, y, orig, s.tiles[y][x]])
			elif s.tiles[y][x] < 8 and orig != light[y][x]:
				bad.append("(%d,%d) sáng gốc %d, mình %d" % [x, y, orig, light[y][x]])
	ok(bad.is_empty(), "%s: lệch %d ô: %s" % [tag, bad.size(), ", ".join(bad.slice(0, 8))])
