class_name RulesClara
extends RulesMain
## Clara (spec hero-select-clara mục 6): an toàn ở vùng mờ. Sáng >= ngưỡng đau thì bỏng; tối hẳn không mất máu nhưng
## thanh virus tăng, đầy thì hóa quái tới khi về 0. Không bị bỏng liên tục REGEN_WAIT_MS ở vùng mờ thì hồi máu.
## Áo choàng chặn bỏng (không chặn virus); giới hạn 30 s như Daniel tới khi hạ Boss 2 (Một trong số họ).

const BURN_PER_S := 7              # Mũ trùm trừ 1 mỗi cấp
const VIRUS_MAX := 100
const VIRUS_UP_PER_S := 20
const VIRUS_DOWN_PER_S := [20, 25, 30]   # theo cấp Tỉnh nhanh
const REGEN_PER_S := [2, 3, 4]           # theo cấp Hồi phục
const REGEN_WAIT_MS := 2000
const MONASTERY := 13

var virus_ms := 0      # virus * 1000
var monster := false   # Hóa quái: khóa chiêu chủ động
var _calm_ms := 0
var _regen_acc := 0

var virus: int:
	get: return virus_ms / 1000

## Ngưỡng đau giảm theo số mảnh chìa khóa (virus tiến triển); ở tu viện luôn 3.
func pain_threshold() -> int:
	var k := s.world.grave_keys
	if k >= 6 or s.level.index == MONASTERY:
		return 3
	return 4 if k >= 3 else 5

func _drain(dt_ms: int) -> void:
	if s.world.bosses_down < 2:
		_tick_cloak(dt_ms)
	var lv := s.light_level(s.player)
	if lv == 0:
		virus_ms = mini(virus_ms + dt_ms * VIRUS_UP_PER_S, VIRUS_MAX * 1000)
	else:
		virus_ms = maxi(virus_ms - dt_ms * VIRUS_DOWN_PER_S[s.world.upgrade_level("fast_wake")], 0)
	if virus_ms >= VIRUS_MAX * 1000:
		monster = true
	elif virus_ms == 0:
		monster = false
	var bright := lv >= pain_threshold()
	if bright and s.world.equipped != GridState.CLOAK:
		_calm_ms = 0
		_regen_acc = 0
		_acc += dt_ms * (BURN_PER_S - s.world.upgrade_level("hood"))
		var n: int = _acc / 1000
		if n > 0:
			_acc -= n * 1000
			s.hurt(n)
		return
	_acc = 0
	_calm_ms += dt_ms
	if lv == 0 or bright or _calm_ms < REGEN_WAIT_MS or s.energy >= s.max_energy:
		_regen_acc = 0
		return
	_regen_acc += dt_ms * REGEN_PER_S[s.world.upgrade_level("regen")]
	var h: int = _regen_acc / 1000
	if h > 0:
		_regen_acc -= h * 1000
		s.energy = mini(s.energy + h, s.max_energy)
		s.out.append({"type": "healed", "energy": s.energy})
