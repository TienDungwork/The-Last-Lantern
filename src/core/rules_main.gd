class_name RulesMain
extends RulesClassic
## Luật chơi chính: mất máu theo độ sáng ô người chơi đứng. Không hồi dần; hồi đầy chỉ qua op 3 / op 25 như bản gốc.
## RulesClassic giữ nguyên để test so sánh với bản gốc.

const HP_PER_S := {0: 10, 1: 4, 2: 4}   # sáng >= 3 không mất; Da dày trừ 1/2 mỗi mức
## Áo choàng tu sĩ: mặc tối đa CLOAK_WEAR_MS (chỉ đếm khi không có tu sĩ trong CLOAK_MONK_RANGE ô, để cải trang
## theo kịch bản màn 5/12/13/18 không bị hỏng), hết thì tự cởi và phải chờ CLOAK_REST_MS mới mặc lại.
## Cởi sớm thì thời gian mặc hồi dần, hồi đầy trong CLOAK_REST_MS.
const CLOAK_WEAR_MS := 30_000
const CLOAK_REST_MS := 20_000
const CLOAK_MONK_RANGE := 6

var _acc := 0
var cloak_worn_ms := 0
var cloak_rest_ms := 0

func _drain(dt_ms: int) -> void:
	_tick_cloak(dt_ms)
	var lv := s.light_level(s.player)
	if s.world.equipped == GridState.CLOAK or not HP_PER_S.has(lv):
		_acc = 0
		return
	_acc += dt_ms * (HP_PER_S[lv] - s.world.upgrade_level("thick_skin"))
	var n: int = _acc / 1000
	if n > 0:
		_acc -= n * 1000
		s.hurt(n)

func _tick_cloak(dt_ms: int) -> void:
	cloak_rest_ms = maxi(cloak_rest_ms - dt_ms, 0)
	if s.world.equipped != GridState.CLOAK:
		cloak_worn_ms = maxi(cloak_worn_ms - dt_ms * CLOAK_WEAR_MS / CLOAK_REST_MS, 0)
		return
	if cloak_rest_ms > 0:
		s.world.equipped = -1   # đang phải chờ: mặc lại qua túi đồ thì bị cởi ngay
		return
	if _monk_near():
		return
	cloak_worn_ms += dt_ms
	if cloak_worn_ms >= CLOAK_WEAR_MS:
		s.world.equipped = -1
		cloak_worn_ms = 0
		cloak_rest_ms = CLOAK_REST_MS

func _monk_near() -> bool:
	for i in s.guards.size():
		if s.guards[i] != null:
			var d: Vector2i = (s.guard_tile(i) - s.player).abs()
			if maxi(d.x, d.y) <= CLOAK_MONK_RANGE:
				return true
	return false
