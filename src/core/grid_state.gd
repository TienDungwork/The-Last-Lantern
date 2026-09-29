class_name GridState
extends RefCounted
## Trạng thái động của màn đang chơi: vị trí, ô đã đổi, đèn, cờ sự kiện, bàn đạp.
## Túi đồ/năng lượng nằm ở World (giữ qua các màn). Không có gì về đồ họa.
## Mỗi hành động ghi vào `out` (Dictionary) cho view/ui xử lý.

const DIR_VEC := {1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0), 4: Vector2i(0, -1)}
# Cờ sự kiện: 1 repeat, 2 active, 4/8/16/32 = đang đi xuống/trái/lên/phải, 64 by_actor, 128 on_enter
const F_REPEAT := 1
const F_ACTIVE := 2
const F_BY_ACTOR := 64
const F_ON_ENTER := 128
const MOVE_FLAG := {1: 32, 2: 4, 3: 8, 4: 16}   # field_425[dir-1]
# Sự kiện có lệnh đầu là 16 (bàn đạp), 24 (hẹn giờ), 28 (cảm biến sáng) không kích hoạt bằng cách đi vào (method_216).
const SELF_DRIVEN_TYPES := [16, 24, 28]
const OUT_OF_BOUNDS_TILE := 8 + 48   # 0x38, tường
const GUARD_TILE_MS := 400           # method_231: tu sĩ đi 1 ô mất 400 ms
const GUARD_SLOTS := 8
const GUARD_SIGHT := 4               # nửa ô (= 2 ô)
const CLOAK := 20                    # Áo choàng tu sĩ: tu sĩ không nhận ra, tối không mất máu
const CREATURE_SLOTS := 16
const CREATURE_TILE_MS := 200        # method_236: sinh vật đi 1 ô mất 200 ms
const CREATURE_HP_MS := 1000         # ở trong sáng đủ chừng này ms thì chết
const NO_CREATURE_LEVELS := [14, 15] # class_10 dòng 1652: phố và sân trước nhà Benjamin không có sinh vật
enum { C_WAIT = 1, C_MOVING = 2, C_DYING = 3, C_DECIDE = 4 }   # field_481
const BOSS_TILE_MS := 800            # method_196: boss đi 1 ô mất 800 ms
const BOSS_HP := 25600
const BOSS_SIGHT := 10               # nửa ô (= 5 ô)
const BOSS2_TILE := 4096             # method_199 tính bằng pixel<<8: 1 ô = 16 px
const BOSS2_LAMP_DAMAGE := 6400      # 4 đèn là hết máu
const FIREBALL_SLOTS := 3            # field_403

var level: LevelData
var world: World
var tiles: Array = []            # bản sao có thể đổi của level.grid
var lights: Array = []           # bản sao có thể đổi của level.lights
var events: Array = []           # bản sao sâu của level.events (COUNTER sửa số đếm trong đó)
var event_active: Array = []     # bool theo event id
var plate_saved: Dictionary = {} # event id bàn đạp đang mở -> ô cửa gốc
var boxes: Dictionary = {}       # Vector2i -> ô hộp; tách khỏi lưới lúc nạp (field_204..206)
var carried := -1                # chỉ số đèn đang cầm (field_149), -1 = tay không
var bulbs := 0                   # bóng đèn đang có (field_278), riêng từng màn
## Tu sĩ (op 14 bit 0x80, field_465..472): null = ô trống. pos tính bằng 1/GUARD_TILE_MS ô để đi mượt theo ms.
## {pos: Vector2i, to: Vector2i, dir: int}
var guards: Array = []
## Sinh vật bóng tối (field_475..488): null = ô trống. pos tính bằng 1/CREATURE_TILE_MS ô.
## {pos, from, to: Vector2i, dir, state, hp (ms còn chịu sáng), timer, age (ms, cho hoạt ảnh)}
var creatures: Array = []
var clock_ms := 0                # thời gian chơi trong màn (field_187), để sinh sinh vật mỗi giây
## Boss 1 (SPECIAL 2, field_377..396), rỗng = không có. pos tính bằng 1/BOSS_TILE_MS ô.
## {home, tile, next, goal: Vector2i, pos, hp, dying, timer, hit_ago}
var boss: Dictionary = {}
## Boss 2 (SPECIAL 10, field_397..407), rỗng = không có. {pos: Vector2i (BOSS2_TILE/ô), target_y, lane, hp}
var boss2: Dictionary = {}
var fireballs: Array = []        # Vector2i, cục lửa đứng yên (SPECIAL 11)
var pointers: Dictionary = {}    # op 27, slot -> {at, dir} (mũi tên) | {hud} (nháy HUD); mất khi vào màn
var light: Array = []            # độ sáng từng ô; rỗng = cần tính lại (light_map())
var player: Vector2i
var facing: int = 2
var control: bool = true
var out: Array = []
var vm: ScriptVM

var inventory: Array[int]:
	get: return world.inventory
var energy: int:
	get: return world.energy
	set(v): world.energy = v
var max_energy: int:
	get: return world.max_energy
	set(v): world.max_energy = v

func _init(L: LevelData, spawn: Vector2i = Vector2i(-1, -1), w: World = null) -> void:
	level = L
	world = w if w else World.new()
	for row in L.grid:
		tiles.append(PackedInt32Array(row))
	for y in L.height:
		for x in L.width:
			var t: int = tiles[y][x]
			if t >= 8 and int(LevelData.tile_props(t).movable) == 1:
				boxes[Vector2i(x, y)] = t
				tiles[y][x] = 0
	for l in L.lights:
		var d: Dictionary = l.duplicate()
		d.life = int(l.radius) * 2 + 1   # field_228[6]: nến mất 1 mỗi bước, bán kính = life >> 1
		lights.append(d)
	events = L.events.duplicate(true)
	for e in events:
		event_active.append(bool(int(e.flags) & F_ACTIVE))
	player = spawn if spawn.x >= 0 else L.start
	vm = ScriptVM.new(self)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < level.width and p.y < level.height

func tile_at(p: Vector2i) -> int:
	return tiles[p.y][p.x] if in_bounds(p) else OUT_OF_BOUNDS_TILE

func set_tile(p: Vector2i, t: int) -> void:
	tiles[p.y][p.x] = t
	light = []
	out.append({"type": "tile_changed", "at": p, "tile": t})

func is_solid(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t >= 8 and int(LevelData.tile_props(t).solid) == 1

func is_blocked(p: Vector2i) -> bool:
	## method_93: ngoài bản đồ, có hộp, ô boss đang đứng / sắp tới, hoặc ô solid. Người chơi không tính.
	if not boss.is_empty() and (p == boss.tile or p == boss.next):
		return true
	return not in_bounds(p) or boxes.has(p) or is_solid(p)

func hurt() -> void:
	energy -= 1
	out.append({"type": "hurt", "energy": energy})
	if energy <= 0:
		out.append({"type": "death"})

func run_special(code: int) -> void:
	## method_202: chạy mọi sự kiện mở đầu bằng SPECIAL `code` (kể cả đang tắt).
	for e in events:
		if int(e.commands[0].op) == 30 and int(e.commands[0].args[0]) == code:
			vm.run(e)

func light_map() -> Array:
	if light.is_empty():
		light = LightField.compute(self)
	return light

func light_level(p: Vector2i) -> int:
	## method_132: độ sáng một ô. Ô vật thể: vài loại tường mượn ô bên phải/dưới/chéo, còn lại lấy ô sàn sáng nhất quanh nó.
	if not in_bounds(p):
		return 0
	var t := tile_at(p)
	if t < 8:
		return light_map()[p.y][p.x]
	match t - 8:
		40, 46:
			return light_level(p + Vector2i(1, 1))
		41, 42, 47, 48:
			return light_level(p + Vector2i(1, 0))
		43, 44, 45, 49, 50, 51:
			return light_level(p + Vector2i(0, 1))
	var best := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if in_bounds(q) and tile_at(q) < 8:
				best = maxi(best, light_map()[q.y][q.x])
	return best

func is_lit(p: Vector2i) -> bool:
	return light_level(p) > 0   # method_133

func events_at(p: Vector2i, moving_dir: int, on_enter_only: bool = false, actor: int = -1) -> Array:
	## method_216. moving_dir 0 = không lọc hướng (đi vào ô, vào màn). actor >= 0: chỉ sự kiện cờ 64 (của tu sĩ),
	## actor = -1: chỉ sự kiện không có cờ 64 (của người chơi).
	var r := []
	for e in events:
		if not event_active[int(e.id)] or int(e.commands[0].op) in SELF_DRIVEN_TYPES:
			continue
		var flags := int(e.flags)
		if (on_enter_only and not (flags & F_ON_ENTER)) or bool(flags & F_BY_ACTOR) != (actor >= 0):
			continue
		if int(e.commands[0].op) == 10 and not is_lit(Vector2i(int(e.x), int(e.y))):
			continue   # vật phẩm chỉ nhặt được khi ô sáng
		if p.x < int(e.x) or p.y < int(e.y) or p.x >= int(e.x) + int(e.w) or p.y >= int(e.y) + int(e.h):
			continue
		if moving_dir > 0 and not (flags & MOVE_FLAG[moving_dir]):
			continue
		r.append(e)
	return r

func enter() -> Array:
	## Vào màn: chạy sự kiện cờ 128 tại ô đang đứng (class_10 dòng 2407), cập nhật bàn đạp.
	out.clear()
	for e in events_at(player, 0, true):
		vm.run(e)
	update_plates()
	check_light_sensors()
	return out

func step(dir: int) -> Array:
	## Một lượt đi. Bị chắn: chạy sự kiện ô đích có lọc hướng. Đi được: chạy sự kiện ô mới, không lọc hướng.
	out.clear()
	if not control:
		return out
	if carried >= 0 and dir != facing and int(lights[carried].type) == 1:
		# Cầm đèn pin: đổi hướng chỉ xoay đèn, không bước.
		facing = dir
		lights[carried].dir = dir
		light = []
		out.append({"type": "bumped", "dir": dir})
		check_light_sensors()
		return out
	facing = dir
	var d: Vector2i = DIR_VEC[dir]
	var target: Vector2i = player + d
	if boxes.has(target):
		# method_92: đẩy hộp; phía sau hộp bị chặn thì thành kéo (lùi một ô, hộp vào chỗ cũ).
		var box_from := target
		var box_to := target + d
		if is_blocked(box_to):
			box_to = player
			target = player - d
			if is_blocked(target):
				return out
		else:
			var k := creature_at(box_to)
			if k >= 0:
				creatures[k] = null   # hộp đè sinh vật
		boxes[box_to] = boxes[box_from]
		boxes.erase(box_from)
		light = []
		out.append({"type": "box_moved", "from": box_from, "to": box_to})
	if is_solid(target):
		out.append({"type": "bumped", "dir": dir})
		_press_switch(target)
		for e in events_at(target, dir):
			vm.run(e)
	else:
		player = target
		world.steps += 1   # field_139
		out.append({"type": "moved", "to": player, "dir": dir})
		if carried >= 0:
			_carry_light(dir)
		for e in events_at(target, 0):
			vm.run(e)
	update_plates()
	check_light_sensors()
	return out

func action() -> Array:
	## method_149/143, phím bắn: đang cầm đèn thì đặt xuống; tay không thì nhặt đèn (loại 0/1/2) ở ô đang đứng và bật nó.
	out.clear()
	if carried >= 0:
		carried = -1
		return out
	for i in lights.size():   # bản gốc không dừng ở đèn đầu: cầm đèn cuối cùng khớp
		var L: Dictionary = lights[i]
		if int(L.x) == player.x and int(L.y) == player.y and int(L.type) in [0, 1, 2]:
			carried = i
			if int(L.on) == 0 and (int(L.type) != 2 or int(L.life) != 0):
				L.on = 1
				light = []
	check_light_sensors()
	return out

func _press_switch(p: Vector2i) -> void:
	## method_92: công tắc tường khung 63 (ngang) / 52 (dọc) bật-tắt đèn loại 5 ở ô trái-phải / dưới-trên,
	## rồi thành khung 62 / 53 (đã gạt, không gạt lại được).
	var t := tile_at(p) - 8
	var side: Vector2i
	match t:
		63: side = Vector2i(1, 0)
		52: side = Vector2i(0, 1)
		_: return
	set_tile(p, t + 8 + (-1 if t == 63 else 1))
	for q in [p + side, p - side]:
		var i := _light_index(q, 5)
		if i >= 0:
			lights[i].on = 1 - int(lights[i].on)
			out.append({"type": "light_changed", "light": i})
			return

func toggle_bulb(i: int) -> void:
	## Op 23 (method_209): hốc đèn sáng thì lấy bóng, tối thì lắp bóng nếu còn.
	var L: Dictionary = lights[i]
	if int(L.on) == 1:
		bulbs += 1
		L.on = 0
	elif bulbs > 0:
		bulbs -= 1
		L.on = 1
	else:
		return
	light = []
	out.append({"type": "light_changed", "light": i})

func spawn_guard(at: Vector2i, dir: int, dist: int) -> void:
	## method_232: lấy ô trống đầu tiên, đi thẳng `dist` ô theo `dir`.
	var g := {"pos": at * GUARD_TILE_MS, "to": at + DIR_VEC.get(dir, Vector2i.ZERO) * dist, "dir": dir}
	var i := guards.find(null)
	if i >= 0:
		guards[i] = g
	elif guards.size() < GUARD_SLOTS:
		guards.append(g)

func guard_tile(i: int) -> Vector2i:
	return guards[i].pos / GUARD_TILE_MS

func tick_guards(ms: int) -> void:
	## method_231: thấy người chơi (không mặc áo choàng) là bị bắt; đi tới đích thì chạy sự kiện cờ 64 ở đó.
	var seen := false
	for i in guards.size():
		var g = guards[i]
		if g == null:
			continue
		if world.equipped != CLOAK and sees(player * 2, guard_tile(i) * 2, GUARD_SIGHT):
			seen = true
		var goal: Vector2i = g.to * GUARD_TILE_MS
		if g.pos == goal:
			continue
		var d := Vector2i(signi(goal.x - g.pos.x), 0)
		if d.x == 0:
			d.y = signi(goal.y - g.pos.y)
		g.dir = {Vector2i(1, 0): 1, Vector2i(0, 1): 2, Vector2i(-1, 0): 3, Vector2i(0, -1): 4}[d]
		var left := absi((goal - g.pos).x + (goal - g.pos).y)
		if ms < left:
			g.pos += d * ms
		else:
			g.pos = goal
			for e in events_at(g.to, 0, false, i):
				vm.run(e, i)
	if seen and energy > 0:
		energy = 0
		out.append({"type": "say", "text_id": 169, "portrait": -1})
		out.append({"type": "death"})

func spawn_creature(at: Vector2i, dir: int, dist: int) -> void:
	## method_233: có quãng đường thì đi tới đó, không thì đứng "nghĩ" (C_DECIDE).
	var c := {"pos": at * CREATURE_TILE_MS, "from": at, "to": at, "dir": dir, "state": C_DECIDE,
		"hp": CREATURE_HP_MS, "timer": 0, "age": 0}
	if dist > 0:
		c.state = C_MOVING
		c.to = at + DIR_VEC.get(dir, Vector2i.ZERO) * dist
	var i := creatures.find(null)
	if i >= 0:
		creatures[i] = c
	elif creatures.size() < CREATURE_SLOTS:
		creatures.append(c)

func creature_at(p: Vector2i) -> int:
	## method_238: sinh vật đang ở / đang đi tới ô p.
	for i in creatures.size():
		var c = creatures[i]
		if c != null and (c.to == p or c.from == p):
			return i
	return -1

func tick_creatures(ms: int, rng: RandomNumberGenerator) -> void:
	## method_236. Bị chiếu thì chạy về ô kề tối nhất; trong sáng đủ CREATURE_HP_MS thì chết.
	## Đứng yên thì mỗi lần nghĩ: 10% biến mất, 63% chờ 1,5–3 s, còn lại đi sang ô kề tối nhất.
	if level.index in NO_CREATURE_LEVELS:
		return
	for i in creatures.size():
		var c = creatures[i]
		if c == null:
			continue
		var lvl := light_level(c.pos / CREATURE_TILE_MS)
		if c.state != C_DYING:
			if lvl == 0:
				c.hp = CREATURE_HP_MS
			else:
				c.hp -= ms
				if c.hp <= 0:
					c.state = C_DYING
					c.timer = 0
					world.creatures_killed += 1
		if c.state in [C_WAIT, C_DECIDE] and lvl > 0:
			_flee(c, rng)
		if c.state == C_DECIDE:
			if rng.randi() % 100 < 10:
				creatures[i] = null
				continue
			elif rng.randi() % 100 < 70:
				c.state = C_WAIT
				c.timer = rng.randi() % 1500 + 1500
			else:
				_flee(c, rng)
		c.age += ms
		match c.state:
			C_WAIT:
				c.timer -= ms
				if c.timer <= 0:
					c.state = C_DECIDE
			C_MOVING:
				var d := Vector2i(signi(c.to.x - c.from.x), 0)
				if d.x == 0:
					d.y = signi(c.to.y - c.from.y)
				c.dir = {Vector2i(1, 0): 1, Vector2i(0, 1): 2, Vector2i(-1, 0): 3, Vector2i(0, -1): 4}.get(d, c.dir)
				var goal: Vector2i = c.to * CREATURE_TILE_MS
				var left := absi((goal - c.pos).x + (goal - c.pos).y)
				if ms < left:
					c.pos += d * ms
				else:
					c.pos = goal
					c.state = C_DECIDE
			C_DYING:
				c.timer += ms
				if c.timer >= 1000:
					creatures[i] = null
	clock_ms += ms
	if clock_ms / 1000 != (clock_ms - ms) / 1000:
		rng.randi()   # bản gốc: "% 40 < 40", luôn đúng nhưng vẫn rút một số
		var p := Vector2i(rng.randi() % level.width, rng.randi() % level.height)
		if not is_lit(p) and tile_at(p) < 8 and not boxes.has(p):
			spawn_creature(p, rng.randi() % 4 + 1, 0)

func _flee(c: Dictionary, rng: RandomNumberGenerator) -> void:
	## method_237: sang ô kề không bị chặn, không có sinh vật khác, tối nhất; thử 4 hướng từ một hướng ngẫu nhiên.
	var p: Vector2i = c.pos / CREATURE_TILE_MS
	var r := rng.randi()
	var best := 10
	var pick := Vector2i.ZERO
	for k in 4:
		var d: Vector2i = DIR_VEC[(r + k) % 4 + 1]
		if not is_blocked(p + d) and creature_at(p + d) < 0 and light_level(p + d) < best:
			best = light_level(p + d)
			pick = d
	if best < 10:
		c.state = C_MOVING
		c.from = p
		c.to = p + pick

func spawn_boss(at: Vector2i) -> void:
	boss = {"home": at, "tile": at, "next": at, "goal": at, "pos": at * BOSS_TILE_MS, "hp": BOSS_HP,
		"dying": false, "timer": 0, "hit_ago": 1 << 30}

func tick_boss(ms: int, rng: RandomNumberGenerator) -> void:
	## method_196. Chạm người chơi: -1 năng lượng, tối đa mỗi 2 s. Đứng ô sáng >= 4 mất 4 máu/ms (hồi lại khi tối);
	## hết máu thì gục, 5 s sau chạy SPECIAL 8. Tới ô mới: thấy người chơi trong 5 ô thì đuổi, không thì về chỗ cũ.
	## Mỗi bước đi về đích (không vào ô sáng >= 5); không đi được thì bước ngẫu nhiên sang ô sáng < 4.
	if boss.is_empty():
		return
	var b := boss
	if b.dying:
		b.timer += ms
		if b.timer >= 5000:
			run_special(8)
		return
	b.hit_ago += ms
	var gap: Vector2i = (b.pos - player * BOSS_TILE_MS).abs()
	if gap.x < BOSS_TILE_MS / 2 and gap.y < BOSS_TILE_MS / 2 and b.hit_ago > 2000:
		b.hit_ago = 0
		hurt()
	if light_level(b.tile) >= 4:
		b.hp -= ms * 4
		if b.hp <= 0:
			b.dying = true
			b.timer = 0
			return
	else:
		b.hp = mini(b.hp + ms * 4, BOSS_HP)
	if b.tile == b.next:
		var n: Vector2i = b.tile
		var axis := rng.randi() % 2
		for k in 2:
			var diff: int = b.goal[axis] - n[axis]
			if n == b.tile and diff != 0:
				var q := n
				q[axis] += signi(diff)
				if not is_blocked(q):
					n = q
			axis = 1 - axis
		if light_level(n) >= 5:
			n = b.tile
		if n == b.tile:
			var r := Vector2i.ZERO
			r[rng.randi() % 2] = 1 if rng.randi() % 2 else -1
			if not is_blocked(n + r) and light_level(n + r) < 4:
				n += r
		b.next = n
	var goal_pos: Vector2i = b.next * BOSS_TILE_MS
	var left := absi((goal_pos - b.pos).x + (goal_pos - b.pos).y)
	if ms < left:
		b.pos += (goal_pos - b.pos).sign() * ms
	else:
		b.pos = goal_pos
		b.tile = b.next
		b.goal = player if sees(b.tile * 2, player * 2, BOSS_SIGHT) else b.home

func spawn_boss2(at: Vector2i) -> void:
	boss2 = {"pos": at * BOSS2_TILE, "target_y": at.y * BOSS2_TILE, "lane": at.y, "hp": BOSS_HP}

func add_fireball(at: Vector2i) -> void:
	if fireballs.size() < FIREBALL_SLOTS:   # method_200: hết chỗ thì bỏ
		fireballs.append(at)

func tick_boss2(ms: int, rng: RandomNumberGenerator) -> void:
	## method_199. Người chơi ở cột ngay trước mặt boss hoặc sau nó (mọi hàng), hoặc đứng trên lửa: chết.
	## Đèn mang được (loại 0/1/2) đang sáng ở ô ngay trước mặt: boss -6400 máu, đèn tắt, có thể đổi làn ±1.
	## Hết máu thì chạy SPECIAL 12. Đang ở đúng làn đích thì trôi sang phải, không thì trượt dọc về làn đích.
	if boss2.is_empty():
		return
	var b := boss2
	var front := Vector2i(b.pos.x / BOSS2_TILE + 1, b.pos.y / BOSS2_TILE)
	if player.x <= front.x or player in fireballs:
		if energy > 0:
			energy = 0
			out.append({"type": "death"})
		return
	for i in lights.size():
		var L: Dictionary = lights[i]
		if int(L.on) == 0 or int(L.radius) <= 0 or int(L.type) in [4, 5, 6]:
			continue
		if int(L.x) != front.x or int(L.y) != front.y:
			continue
		b.hp -= BOSS2_LAMP_DAMAGE
		L.on = 0
		light = []
		out.append({"type": "light_changed", "light": i})
		if b.pos.y == b.target_y:
			if front.y == b.lane:
				match rng.randi() % 3:
					0: b.target_y = (b.lane - 1) * BOSS2_TILE
					2: b.target_y = (b.lane + 1) * BOSS2_TILE
			elif rng.randi() % 2 == 0:
				b.target_y = b.lane * BOSS2_TILE
	var v := ms * 5 / 3
	if b.hp <= 0:
		run_special(12)
	elif b.pos.y == b.target_y:
		b.pos.x += v
	else:
		b.pos.y = mini(b.pos.y + v, b.target_y) if b.pos.y < b.target_y else maxi(b.pos.y - v, b.target_y)

func sees(a: Vector2i, b: Vector2i, r: int) -> bool:
	## method_153, nửa ô: a trong ô vuông bán kính r quanh b và đường từ b tới a không qua ô chắn sáng (kể cả hộp).
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	if dx > r or dy > r:
		return false
	var sx := signi(a.x - b.x)
	var sy := signi(a.y - b.y)
	for i in maxi(dx, dy):
		var p: Vector2i
		if dx > dy:
			p = Vector2i(b.x + i * sx, b.y + ((i * ((dy << 6) / dx)) >> 6) * sy)
		elif dx < dy:
			p = Vector2i(b.x + ((i * ((dx << 6) / dy)) >> 6) * sx, b.y + i * sy)
		else:
			p = b + Vector2i(i * sx, i * sy)
		var q := p / 2
		for t in [tile_at(q), boxes.get(q, 0)]:
			if t >= 8 and int(LevelData.tile_props(t).blocks_light) == 1:
				return false
	return true

func _light_index(p: Vector2i, type: int) -> int:
	## method_142: đèn đầu tiên đúng loại ở ô p.
	for i in lights.size():
		if int(lights[i].x) == p.x and int(lights[i].y) == p.y and int(lights[i].type) == type:
			return i
	return -1

func _carry_light(dir: int) -> void:
	var L: Dictionary = lights[carried]
	L.x = player.x
	L.y = player.y
	if int(L.dir) != 0:
		L.dir = dir
	if int(L.type) == 2 and int(L.life) > 0:
		L.life = int(L.life) - 1
		L.radius = int(L.life) >> 1
		if int(L.radius) == 0:
			L.on = 0
	light = []

func update_plates() -> void:
	## method_215: bàn đạp (sự kiện lệnh đầu 16) mở ô cửa (x,y) khi vùng của nó có vật thể, người chơi
	## hoặc nguồn sáng; khi trống (và cửa không bị chặn) thì trả ô cửa về như cũ.
	for e in events:
		var id := int(e.id)
		if not event_active[id] or int(e.commands[0].op) != 16:
			continue
		var rect := Rect2i(int(e.x), int(e.y), int(e.w), int(e.h))
		var door := Vector2i(int(e.commands[0].args[0]), int(e.commands[0].args[1]))
		var pressed := rect.has_point(player)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var q := Vector2i(x, y)
				if in_bounds(q) and (tile_at(q) >= 8 or boxes.has(q)):
					pressed = true
		for L in lights:
			if rect.has_point(Vector2i(int(L.x), int(L.y))):
				pressed = true
			if int(L.x) == door.x and int(L.y) == door.y:
				pressed = true   # đèn chặn cửa: không đóng được
		if boxes.has(door):
			pressed = true
		if pressed and not plate_saved.has(id):
			plate_saved[id] = tile_at(door)
			set_tile(door, 0)
			vm.run(e)   # method_207: chạy lệnh sau op 16 (nếu có)
		elif not pressed and plate_saved.has(id):
			set_tile(door, plate_saved[id])
			plate_saved.erase(id)

func check_light_sensors() -> void:
	## method_214: sự kiện lệnh đầu 28 chạy (rồi tắt hẳn) khi ô (x,y) của nó sáng >= ngưỡng; ngưỡng 0 = khi ô tối hẳn.
	for e in events:
		var id := int(e.id)
		if not event_active[id] or int(e.commands[0].op) != 28:
			continue
		var need := int(e.commands[0].args[0])
		var lvl := light_level(Vector2i(int(e.x), int(e.y)))
		if (need != 0 or lvl == 0) and need <= lvl:
			event_active[id] = false
			vm.run(e)

func tick_timers(ms: int) -> void:
	## method_213: sự kiện lệnh đầu 24 đếm lùi số ms 32 bit trong 4 byte đối số, về <= 0 thì chạy.
	for e in events:
		if not event_active[int(e.id)] or int(e.commands[0].op) != 24:
			continue
		var a: Array = e.commands[0].args
		var left := (int(a[0]) << 24) | (int(a[1]) << 16) | (int(a[2]) << 8) | int(a[3])
		if left <= 0:
			continue
		left = maxi(left - ms, 0)
		a[0] = (left >> 24) & 0xFF
		a[1] = (left >> 16) & 0xFF
		a[2] = (left >> 8) & 0xFF
		a[3] = left & 0xFF
		if left == 0:
			vm.run(e)
