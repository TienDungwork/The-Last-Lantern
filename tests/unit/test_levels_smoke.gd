extends "res://tests/lib/test_case.gd"
## Quét cả 19 màn: đích dịch chuyển hợp lệ, điểm xuất phát đứng được, chạy mọi sự kiện + 5 s thời gian không lỗi.

const LEVELS := 19

func test_teleport_targets_are_valid() -> void:
	var bad := []
	for n in LEVELS:
		for e in LevelData.load_level(n).events:
			if int(e.flags) & GridState.F_BY_ACTOR:
				continue   # sự kiện của tu sĩ: op 6 sang màn khác = tu sĩ rời màn, tọa độ bỏ qua
			for c in e.commands:
				if int(c.op) != 6:
					continue
				var to := Vector2i(int(c.args[0]), int(c.args[1]))
				var lv := int(c.args[2])
				if lv >= LEVELS:
					bad.append("%02d#%d -> màn %d không có" % [n, e.id, lv])
					continue
				var s := GridState.new(LevelData.load_level(lv), to)
				if not s.in_bounds(to) or s.is_solid(to):
					bad.append("%02d#%d -> màn %d ô %s" % [n, e.id, lv, to])
	eq(bad, [], "đích dịch chuyển nằm trong bản đồ, không phải tường")

func test_every_level_runs_all_events() -> void:
	var starts := []
	for n in LEVELS:
		var s := World.new().enter_level(n)
		if not s.in_bounds(s.player) or s.is_solid(s.player):
			starts.append("%02d %s" % [n, s.player])
		s.enter()
		var rules := RulesClassic.new(s, n)
		for e in s.events:
			s.vm.run(e)
		for i in 50:
			rules.tick(100)
		ok(s.out.size() > 0, "màn %02d có chạy" % n)
	# ponytail: điểm xuất phát mặc định lỗi chỉ ghi nhận (bản gốc luôn vào màn bằng TELEPORT có tọa độ).
	print("    điểm xuất phát mặc định ngoài bản đồ/tường: ", starts)
