extends "res://tests/lib/test_case.gd"

func _dark_rules() -> RulesClassic:
	var s := GridState.new(LevelData.load_level(0))
	for l in s.lights:
		l.on = 0
	return RulesClassic.new(s, 7)

func test_lit_tile_no_damage() -> void:
	var r := RulesClassic.new(GridState.new(LevelData.load_level(0)), 7)
	r.tick(10_000)
	eq(r.s.energy, r.s.max_energy, "ô start sáng, không mất")

func test_dark_damage_after_2_to_3_seconds() -> void:
	var r := _dark_rules()
	r.tick(1)          # bắt đầu đếm
	r.tick(1_998)
	eq(r.s.energy, r.s.max_energy, "chưa tới 2 s")
	r.tick(1_002)      # tổng 3000 ms: bộ đếm tối đa 2999 xuống < 0
	eq(r.s.energy, r.s.max_energy - 1, "mất 1 sau tối đa 3 s")
	r.tick(1)
	r.tick(3_000)
	eq(r.s.energy, r.s.max_energy - 2, "lặp lại")

func test_hurt_and_death_events() -> void:
	var r := _dark_rules()
	r.s.energy = 1
	r.tick(1)
	r.tick(3_000)
	var types := r.s.out.map(func(o): return o.type)
	ok(types.has("hurt"), "báo hurt")
	ok(types.has("death"), "về 0 thì báo death")

func test_back_into_dark_waits_800ms() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var r := RulesClassic.new(s, 7)
	for l in s.lights:
		l.on = 0
	r.refresh_light()
	r.tick(1)          # tối: bắt đầu đếm
	s.lights[1].on = 1
	r.refresh_light()
	r.tick(10)         # sáng: timer -> -2
	s.lights[1].on = 0
	r.refresh_light()
	r.tick(799)
	eq(s.energy, s.max_energy, "chưa tới 800 ms")
	r.tick(2)
	eq(s.energy, s.max_energy - 1, "quay lại tối: 800 ms là mất")
