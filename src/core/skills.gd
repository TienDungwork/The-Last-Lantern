class_name Skills
extends RefCounted
## Chiêu chủ động phím 1..4 (spec hero-select-clara mục 5, 6, 6b): hồi chiêu theo ms game, Tay quen, hiệu ứng.
## Giữ qua các màn (game.gd gán lại `s` khi vào màn mới); hiệu ứng gắn với màn cũ thì bỏ.

const SLOTS := {
	"daniel": ["kindle", "bandage", "fire_wall", "twin_lamp"],
	"clara": ["swallow_light", "call_shadow"],
}
const COOLDOWN_MS := {"kindle": 8000, "bandage": 20000, "fire_wall": 50000, "twin_lamp": 1000,
	"swallow_light": 10000, "call_shadow": 12000}
const QUICK_HANDS := [0, 10, 25]            # % giảm hồi chiêu 1..3 của Daniel
const QUICK_HANDS_SKILLS := ["kindle", "bandage", "fire_wall"]
const BANDAGE_MS := 3000
const BANDAGE_HEAL := [10, 15, 25]
const BANDAGE_MIN_LIGHT := 3
const KINDLE_BOOST_MS := 10000
const TOO_DARK := "Quá tối, không băng bó được"
const NO_LAMP := "Không có đèn tắt nào quanh đây"

var s: GridState:
	set(v):
		s = v
		bandage_ms = 0
		_boosts.clear()
var cd := {}                 # tên chiêu -> ms hồi chiêu còn lại
var bandage_ms := 0          # > 0: đang băng bó, ms còn lại
var _bandage_at := Vector2i.ZERO
var _boosts: Array = []      # Mồi lửa cấp 1: [chỉ số đèn, ms còn lại]

func _init(state: GridState) -> void:
	s = state

func slots() -> Array:
	return SLOTS[s.world.hero]

func cooldown_max(name: String) -> int:
	var ms: int = COOLDOWN_MS[name]
	if name == "kindle" and s.world.upgrade_level("kindle") >= 2:
		ms = 6000
	if name in QUICK_HANDS_SKILLS:
		ms = ms * (100 - QUICK_HANDS[s.world.upgrade_level("quick_hands")]) / 100
	return ms

## Bấm phím chiêu (0-based). Trả câu báo cho HUD, "" nếu không có gì để báo.
func use(slot: int) -> String:
	if slot >= slots().size():
		return ""
	var name: String = slots()[slot]
	if not s.world.unlocked(name) or int(cd.get(name, 0)) > 0 or bandage_ms > 0:
		return ""
	match name:
		"bandage":
			if s.light_level(s.player) < BANDAGE_MIN_LIGHT:
				return TOO_DARK
			bandage_ms = BANDAGE_MS
			_bandage_at = s.player
			return ""   # hồi chiêu tính khi băng xong
		"kindle":
			return "" if _kindle() else NO_LAMP
	return ""   # ponytail: fire_wall, twin_lamp, chiêu của Clara chưa có hiệu ứng

## Trả true khi máu hoặc ánh sáng vừa đổi (game.gd vẽ lại).
func tick(dt_ms: int) -> bool:
	var changed := false
	for n in cd:
		cd[n] = maxi(int(cd[n]) - dt_ms, 0)
	if bandage_ms > 0:
		if s.player != _bandage_at or s.light_level(s.player) < BANDAGE_MIN_LIGHT:
			bandage_ms = 0   # hủy, không tốn hồi chiêu
		else:
			bandage_ms -= dt_ms
			if bandage_ms <= 0:
				bandage_ms = 0
				s.energy = mini(s.energy + BANDAGE_HEAL[s.world.upgrade_level("bandage")], s.max_energy)
				cd["bandage"] = cooldown_max("bandage")
				changed = true
	for b in _boosts:
		b[1] -= dt_ms
		if b[1] <= 0:
			var L: Dictionary = s.lights[b[0]]
			L.radius = int(L.life) >> 1 if int(L.type) == 2 else maxi(int(L.radius) - 1, 0)   # nến: cầm đi thì radius đã tính lại từ life
			s.light = []
			changed = true
	_boosts = _boosts.filter(func(b): return b[1] > 0)
	return changed

## Đèn cầm tay (loại 0..2) đang tắt ở ô đứng hoặc ô kề; nến tàn thì nạp đầy. Đèn cố định không thắp.
func _kindle() -> bool:
	for i in s.level.lights.size():
		var L: Dictionary = s.lights[i]
		var at := Vector2i(int(L.x), int(L.y))
		if int(L.type) not in [0, 1, 2] or int(L.on) == 1 or maxi(absi(at.x - s.player.x), absi(at.y - s.player.y)) > 1:
			continue
		if int(L.type) == 2:
			L.life = int(s.level.lights[i].radius) * 2 + 1
			L.radius = s.level.lights[i].radius
		L.on = 1
		if s.world.upgrade_level("kindle") >= 1:
			L.radius = int(L.radius) + 1
			_boosts.append([i, KINDLE_BOOST_MS])
		s.light = []
		s.out.append({"type": "light_changed", "light": i})
		cd["kindle"] = cooldown_max("kindle")
		return true
	return false
