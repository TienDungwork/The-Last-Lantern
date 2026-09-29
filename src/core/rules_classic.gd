class_name RulesClassic
extends RefCounted
## Luật chế độ Cổ điển: mất năng lượng trong tối theo thời gian thực (class_10.method_97).
## Mọi số ngẫu nhiên đi qua `rng` có seed để test lặp lại được.

const FIRST_WAIT_MS := 2000
const RANDOM_EXTRA_MS := 1000
const REENTER_WAIT_MS := 800

var s: GridState
var light: Array = []
var dark_timer: int = -1    # -1 chưa đếm; -2 vừa ra chỗ sáng; >=0 ms còn lại
var rng := RandomNumberGenerator.new()

func _init(state: GridState, seed_value: int = 0) -> void:
	s = state
	rng.seed = seed_value
	refresh_light()

func refresh_light() -> void:
	s.light = []
	light = s.light_map()

func tick(dt_ms: int) -> void:
	if s.energy <= 0:
		return   # đã chết, chờ game.gd nạp lại màn
	s.tick_timers(dt_ms)
	s.tick_guards(dt_ms)
	s.tick_creatures(dt_ms, rng)
	s.tick_boss(dt_ms, rng)
	s.check_light_sensors()
	light = s.light_map()   # GridState xóa bản đồ khi ô/đèn đổi; tính lại khi cần
	if s.is_lit(s.player) or s.world.equipped == GridState.CLOAK:
		if dark_timer >= 0:
			dark_timer = -2
		return
	if dark_timer == -2:
		dark_timer = REENTER_WAIT_MS
	if dark_timer == -1:
		dark_timer = FIRST_WAIT_MS + rng.randi() % RANDOM_EXTRA_MS
		return
	dark_timer -= dt_ms
	if dark_timer < 0:
		dark_timer = -1
		s.hurt()
