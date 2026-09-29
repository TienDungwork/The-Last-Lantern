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
	light = LightField.compute(s)

func is_lit(p: Vector2i) -> bool:
	# ponytail: bản gốc (method_132) lấy sáng từ ô cạnh khi đứng trên vật thể; M2 thêm khi có hộp/cửa.
	return s.in_bounds(p) and light[p.y][p.x] > 0

func tick(dt_ms: int) -> void:
	if is_lit(s.player):
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
		s.energy -= 1
		s.out.append({"type": "hurt", "energy": s.energy})
		if s.energy <= 0:
			s.out.append({"type": "death"})
