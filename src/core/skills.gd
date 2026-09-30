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
const SWALLOW_MS := [8000, 12000, 12000]   # Nuốt sáng: cấp 1 kéo dài, cấp 2 xa hơn
const SWALLOW_REACH := [3, 3, 5]
const FIRE_MS := 8000                      # Bức tường lửa: vệt 3 ô vuông góc hướng ném, xa tối đa FIRE_REACH ô
const FIRE_REACH := 4
const FIRE_RADIUS := 7                     # ô lửa sáng mức 6
const NO_ROOM := "Không có chỗ để ném"
const NO_TWIN := "Chưa có đèn nào để đổi"
const TOO_DARK := "Quá tối, không băng bó được"
const NO_LAMP := "Không có đèn tắt nào quanh đây"
const NO_LIGHT := "Không có nguồn sáng nào đủ gần"

var s: GridState:
	set(v):
		s = v
		bandage_ms = 0
		_boosts.clear()
		_swallowed.clear()
		_fire.clear()
		_fire_ms = 0
var cd := {}                 # tên chiêu -> ms hồi chiêu còn lại
var bandage_ms := 0          # > 0: đang băng bó, ms còn lại
var _bandage_at := Vector2i.ZERO
var _boosts: Array = []      # Mồi lửa cấp 1: [chỉ số đèn, ms còn lại]
var _swallowed: Array = []   # Nuốt sáng: [chỉ số đèn, ms còn lại], hết giờ bật lại
var _fire: Array = []        # Bức tường lửa: chỉ số 3 đèn lửa thêm vào cuối s.lights, dùng lại trong màn
var _fire_ms := 0
var fx_at := Vector2i(-1, -1)   # ô chiêu vừa dùng tác động (đèn vừa thắp/nuốt, chỗ lửa rơi) cho FxView

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
		"swallow_light":
			return "" if _swallow() else NO_LIGHT
		"fire_wall":
			return "" if _fire_wall() else NO_ROOM
		"twin_lamp":
			if s.carried < 0 and s.carried_back < 0:
				return NO_TWIN
			var hand := s.carried
			s.carried = s.carried_back
			s.carried_back = hand
			cd["twin_lamp"] = cooldown_max("twin_lamp")
			return ""
	return ""   # ponytail: call_shadow chưa có hiệu ứng

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
	for w in _swallowed:
		w[1] -= dt_ms
		if w[1] <= 0:
			s.lights[w[0]].on = 1
			s.light = []
			s.out.append({"type": "light_changed", "light": w[0]})
			changed = true
	_swallowed = _swallowed.filter(func(w): return w[1] > 0)
	if _fire_ms > 0:
		_fire_ms -= dt_ms
		var lit := _fire.filter(func(i): return int(s.lights[i].on) == 1).size()
		if _fire_ms <= 0 or lit < s.fire_tiles.size():   # hết giờ, hoặc Boss 2 dập một ô (đã ăn 6400): tắt cả vệt
			_fire_ms = 0
			_set_fire([])
			changed = true
	return changed

## Ném chai dầu theo hướng đang nhìn, rơi ở ô trống xa nhất trong FIRE_REACH ô; lửa cháy ở ô đó và hai ô hai bên.
func _fire_wall() -> bool:
	var d: Vector2i = GridState.DIR_VEC[s.facing]
	var c := s.player
	for i in FIRE_REACH:
		if s.is_blocked(c + d):
			break
		c += d
	if c == s.player:
		return false
	fx_at = c
	var side := Vector2i(d.y, d.x)
	if _fire.is_empty():
		for k in 3:
			_fire.append(s.lights.size())
			s.lights.append({"x": 0, "y": 0, "type": GridState.FIRE_LIGHT, "on": 0, "radius": FIRE_RADIUS, "dir": 0, "life": 0})
	_set_fire([c - side, c, c + side].filter(func(p): return not s.is_blocked(p)))
	_fire_ms = FIRE_MS
	cd["fire_wall"] = cooldown_max("fire_wall")
	return true

func _set_fire(tiles: Array) -> void:
	s.fire_tiles = tiles
	for k in _fire.size():
		var L: Dictionary = s.lights[_fire[k]]
		L.on = 1 if k < tiles.size() else 0
		if k < tiles.size():
			L.x = tiles[k].x
			L.y = tiles[k].y
		s.out.append({"type": "light_changed", "light": _fire[k]})
	s.light = []

## Tắt nguồn sáng đang bật gần nhất trong tầm (cả đèn tường), hết giờ bật lại. Không tính đèn flash.
func _swallow() -> bool:
	var reach: int = SWALLOW_REACH[s.world.upgrade_level("swallow_light")]
	var best := -1
	var best_d := reach + 1
	for i in s.level.lights.size():
		var L: Dictionary = s.lights[i]
		var d := maxi(absi(int(L.x) - s.player.x), absi(int(L.y) - s.player.y))
		if int(L.on) == 1 and d < best_d:
			best = i
			best_d = d
	if best < 0:
		return false
	s.lights[best].on = 0
	fx_at = Vector2i(int(s.lights[best].x), int(s.lights[best].y))
	s.light = []
	s.out.append({"type": "light_changed", "light": best})
	_swallowed.append([best, SWALLOW_MS[s.world.upgrade_level("swallow_light")]])
	cd["swallow_light"] = cooldown_max("swallow_light")
	return true

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
		fx_at = at
		if s.world.upgrade_level("kindle") >= 1:
			L.radius = int(L.radius) + 1
			_boosts.append([i, KINDLE_BOOST_MS])
		s.light = []
		s.out.append({"type": "light_changed", "light": i})
		cd["kindle"] = cooldown_max("kindle")
		return true
	return false
