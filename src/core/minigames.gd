class_name Minigames
extends RefCounted
## 3 minigame ẩn (op 12 hoặc gõ mã số): 0 Semua Darts (class_10.method_242..246), 1 Lantern Worm (method_247..260),
## 2 King Bong (method_261..271). Toạ độ theo màn gốc 240x320, số thực cố định <<8 như bản gốc.
## Phím: tick(ms, held) với held = UP|DOWN|LEFT|RIGHT đang giữ; press(k) với k = "up"/"down"/"left"/"right"/"fire"/"restart".

const W := 240
const H := 320
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8
const TITLES := ["SEMUA Darts", "LANTERN WORM", "KING BONG"]

static func create(id: int, level: int, hi: int) -> Game:
	var g: Game = [Darts, Worm, Bong][id].new()
	g.level_id = level
	g.hi = hi
	g.rng = Lcg.new(Time.get_ticks_usec())
	return g

## method_159: LCG 48 bit của java.util.Random (không xáo seed).
class Lcg:
	var seed := 0
	func _init(s: int) -> void:
		seed = s & 0xFFFFFFFFFFFF
	func next() -> int:
		seed = (seed * 25214903917 + 11) & 0xFFFFFFFFFFFF
		var r := seed >> 16
		return r - 0x100000000 if r >= 0x80000000 else r
	func u(n: int) -> int:   # (method_159() >>> 1) % n
		return ((next() & 0xFFFFFFFF) >> 1) % n
	func s(n: int) -> int:   # method_159() % n, có dấu
		return next() % n

class Game:
	var score := 0
	var hi := 0
	var level_id := -1       # field_186: màn đang chơi lúc vào minigame
	var paused := false
	var rng: Lcg
	var clock := 0           # field_187
	var texts: Array = []    # method_272: chữ bay lên {s, x, y (<<8), ms, vy}
	func tick(_dt: int, _held: int) -> void:
		pass
	func press(_k: String) -> void:
		pass
	func _float(s: String, x: int, y: int, ms: int, vy: int) -> void:
		if texts.size() < 16:
			texts.append({"s": s, "x": x, "y": y << 8, "ms": ms, "vy": vy})
	func _tick_texts(dt: int) -> void:   # method_273
		for t in texts.duplicate():
			t.ms -= dt
			if t.ms <= 0:
				texts.erase(t)
			else:
				t.y -= dt * t.vy >> 8
	func _periods(dt: int, period: int) -> int:   # số lần mốc chu kỳ bị vượt trong khung này
		return clock / period - (clock - dt) / period

## Ném 5 phi tiêu vào bia tròn giữa màn; tâm ngắm tự rung. 10 - khoảng cách/6 điểm (< 3 = 0),
## trúng con vật bay ngang = 20. Phi tiêu thứ 6 xoá lượt, về 0 điểm.
class Darts extends Game:
	var aim := Vector2i(-15360, 0)     # field_499/500, lệch tâm bia
	var bird := Vector2i(-25600, 0)    # field_508/509
	var thrown: Array = []             # field_506/507, px lệch tâm
	func tick(dt: int, held: int) -> void:   # method_242
		clock += dt
		_tick_texts(dt)
		if bird.x < -15360:
			for i in _periods(dt, 2000):
				if rng.u(100) < 10:
					bird = Vector2i(W + 60 << 8, rng.u(H - 40) + 20 << 8)
		else:
			bird.x -= dt * 10
		for i in _periods(dt, 80):
			var r := absi(rng.s(4)) + 8
			aim.x += rng.s(r) << 8
			aim.y += rng.s(r) << 8
		var v := dt * 6
		if held & LEFT: aim.x -= v
		if held & RIGHT: aim.x += v
		if held & UP: aim.y -= v
		if held & DOWN: aim.y += v
		aim = aim.clamp(Vector2i(-15360, -15360), Vector2i(15360, 15360))
	func press(k: String) -> void:   # method_246 + method_243
		if k != "fire":
			return
		if thrown.size() == 5:
			thrown.clear()
			score = 0
			return
		var p := Vector2i(aim.x >> 8, aim.y >> 8)
		thrown.append(p)
		var pts := 10 - Minigames.isqrt(p.x * p.x + p.y * p.y) / 6
		var at := p + Vector2i(W / 2, H / 2)
		if (Vector2i(bird.x >> 8, bird.y >> 8) - at).length_squared() < 25:
			pts = 20
			bird.x = -25600
		if pts > 2:
			score += pts
			hi = maxi(hi, score)
		_float(str(pts if pts >= 3 else 0), at.x, at.y, 1500, 1792)

## Giun đào đất (kiểu Boulder Dash). Ăn hết đom đóm (GEM) là qua màn; đâm rêu, đá, thân mình, bọ = chết.
## Màn sinh từ seed = số màn nên luôn giống nhau. Ở màn 15 đầu giun là chó và ăn được bọ.
class Worm extends Game:
	enum { DIRT, EMPTY, GEM, CRATE, MOSS, BODY_R, BODY_L, BODY_D, BODY_U, HEAD, BUG, BUG_ANGRY, ROCK }
	const GW := 32   # 240 / 7 - 2
	const GH := 39   # 320 / 7 - 6
	var grid := PackedByteArray()   # field_511, chỉ số y * GW + x
	var level := 0          # field_516
	var slow := 0           # field_515: +3 ms/nhịp mỗi lần ăn hộp
	var period := 350       # field_514
	var intro_ms := 0       # field_517: hiện "LEVEL n"
	var grow := 0           # field_518: đủ 10 ô đất thì dài thêm 1
	var ticks := 0          # field_519
	var head := Vector2i()
	var tail := Vector2i()
	var dir := 3            # field_526: 1 phải, 2 xuống, 3 trái, 4 lên
	var turned := false     # field_527: mỗi nhịp chỉ rẽ một lần
	var dead := false       # field_528
	var cleared := false    # field_529
	var need_new := true    # field_530
	var started := false    # field_531
	var shrinking := false  # field_532: ăn hộp -> đứng yên, đuôi co về sát đầu
	var bugs: Array = []    # field_535/536/537: {pos (x < 0 = chết), dir}

	func _init() -> void:
		grid.resize(GW * GH)

	func cell(x: int, y: int) -> int:
		return grid[y * GW + x]
	func put(x: int, y: int, v: int) -> void:
		grid[y * GW + x] = v
	func _inside(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < GW and y < GH

	func tick(dt: int, _held: int) -> void:   # method_247
		clock += dt
		_tick_texts(dt)
		intro_ms -= dt
		if dead or cleared:
			return
		if need_new:
			need_new = false
			started = false
			turned = false
			generate()
			texts.clear()
			intro_ms = 3000
			return
		if not started or paused:
			return
		for i in _periods(dt, period):
			if shrinking:
				if _move_tail():
					shrinking = false
			else:
				_move_head()
				if dead:
					return
				_fall()
				_move_bugs()
				_spread_moss()
				hi = maxi(hi, score)
				if not grid.has(GEM):
					cleared = true
			ticks += 1

	func press(k: String) -> void:   # method_260
		if dead:
			dead = false
			need_new = true
			score = 0
			level = 0
			slow = 0
		elif cleared:
			cleared = false
			need_new = true
			level += 1
		elif intro_ms > 0:
			intro_ms = 0
		else:
			started = true
			if k == "fire":
				paused = not paused
			if not turned:
				var want: int = {"up": 4, "down": 2, "left": 3, "right": 1}.get(k, 0)
				if want and (want + 1) % 4 + 1 != dir:   # không quay đầu 180°
					dir = want
				turned = true

	func generate() -> void:   # method_255
		grid.fill(DIRT)
		rng.seed = level
		period = maxi(350 - level * 10 + slow, 200)
		for i in rng.u(20):
			var x := rng.u(GW)
			var y := rng.u(GH)
			var w := rng.u(5) + 2
			var h := rng.u(5) + 2
			for dy in h:
				for dx in w:
					if x + dx < GW and y + dy < GH:
						put(x + dx, y + dy, EMPTY)
		for i in rng.u(10):
			var x := rng.u(GW)
			put(x, rng.u(GH), ROCK)
		for i in rng.u((level >> 2) + 3):
			var x := rng.u(GW)
			put(x, rng.u(GH), CRATE)
		for i in rng.u(6) + 1:
			var x := rng.u(GW)
			put(x, rng.u(GH), GEM)
		for i in rng.u((level >> 1) + 2):
			var x := rng.u(GW)
			var y := rng.u(GH)
			if cell(x, y) != GEM:
				put(x, y, MOSS)
		bugs.clear()
		for i in rng.u(level + 1):
			var b := {"pos": Vector2i(-1, -1), "dir": 1}
			for t in 32:
				var x := rng.u(GW)
				var y := rng.u(GH)
				if cell(x, y) == EMPTY:
					put(x, y, BUG)
					b = {"pos": Vector2i(x, y), "dir": rng.u(4) + 1}
					break
			bugs.append(b)
		for t in 256:
			var x := rng.u(GW - 2)
			var y := rng.u(GH - 1) + 1
			var k := 0
			while k < 3 and cell(x, y) != BUG and cell(x, y) != GEM:
				x += 1
				k += 1
			if k >= 3 or t >= 63:
				head = Vector2i(x - 2, y)
				tail = Vector2i(x - 1, y)
				dir = 3
				put(head.x, head.y, HEAD)
				put(tail.x, tail.y, BODY_L)
				break
		grow = 0
		rng.seed = score

	func _die() -> void:   # method_252
		dead = true
		_float("SLURTS!", (head.x + 1) * 7 + 3, (head.y + 3) * 7, 1500, 512)

	func _move_head() -> void:   # method_253
		var p := head
		var body: int
		match dir:
			3:
				body = BODY_L
				p.x -= 1
			1:
				body = BODY_R
				p.x += 1
			4:
				body = BODY_U
				p.y -= 1
			_:
				body = BODY_D
				p.y += 1
		if not _inside(p.x, p.y):
			_die()
			return
		var fx := (p.x + 1) * 7 + 3
		var fy := (p.y + 3) * 7
		match cell(p.x, p.y):
			GEM:
				score += 60
				_float("60", fx, fy, 1500, 512)
			CRATE:
				score += 30
				_float("30", fx, fy, 1500, 512)
				shrinking = true
				grow = 0
				slow += 3
			MOSS, BODY_R, BODY_L, BODY_D, BODY_U, ROCK:
				_die()
				return
			BUG, BUG_ANGRY:
				if level_id != 15:
					_die()
					return
				_kill_bug(p)
				score += 41
				grow += 1
				_float("40", fx, fy, 1500, 512)
			DIRT:
				score += 1
				grow += 1
		put(head.x, head.y, body)
		put(p.x, p.y, HEAD)
		head = p
		if grow >= 10:
			grow -= 10
		else:
			_move_tail()
		turned = false

	func _move_tail() -> bool:   # method_254: true = đuôi đã sát đầu, không co nữa
		var n := tail
		match cell(tail.x, tail.y):
			BODY_L: n.x -= 1
			BODY_R: n.x += 1
			BODY_U: n.y -= 1
			BODY_D: n.y += 1
		if n == head:
			return true
		put(tail.x, tail.y, EMPTY)
		tail = n
		return false

	func _kill_bug(p: Vector2i) -> void:
		for b in bugs:
			if b.pos == p:
				b.pos = Vector2i(-1, -1)
				return

	func _move_bugs() -> void:   # method_248/249: bọ ăn hộp thì nổi giận (đi xuyên rêu), ăn đom đóm = người chơi mất điểm
		for b in bugs:
			var old: Vector2i = b.pos
			if old.x < 0:
				continue
			for k in 8:
				var t := old + ({3: Vector2i.LEFT, 1: Vector2i.RIGHT, 2: Vector2i.UP, 4: Vector2i.DOWN}[b.dir] as Vector2i)
				var c := cell(t.x, t.y) if _inside(t.x, t.y) else -1
				var me := cell(old.x, old.y)
				if c in [EMPTY, GEM, CRATE] or (me == BUG_ANGRY and c == MOSS):
					if c == CRATE:
						me = BUG_ANGRY
						score -= 30
						_float("-30", (t.x + 1) * 7 + 3, (t.y + 3) * 7, 1500, 512)
					elif c == GEM:
						score -= 60
						_float("-60", (t.x + 1) * 7 + 3, (t.y + 3) * 7, 1500, 512)
					put(old.x, old.y, EMPTY)
					put(t.x, t.y, me)
					b.pos = t
					break
				b.dir = rng.u(4) + 1

	func _fall() -> void:   # method_251: đom đóm, hộp, đá rơi vào ô trống; đá rơi trúng bọ thì bọ chết
		for y in range(GH - 2, -1, -1):
			for x in range(GW - 1, -1, -1):
				var c := cell(x, y)
				if c != GEM and c != CRATE and c != ROCK:
					continue
				var below := cell(x, y + 1)
				var crush := c == ROCK and (below == BUG or below == BUG_ANGRY)
				if below == EMPTY or crush:
					if crush:
						_kill_bug(Vector2i(x, y + 1))
					put(x, y + 1, c)
					put(x, y, EMPTY)

	func _spread_moss() -> void:   # method_250: rêu lan sang ô trống, biến đá thành hộp
		for y in GH:
			for x in GW:
				if cell(x, y) != MOSS or rng.u(100) > 10:
					continue
				var n := Vector2i(x, y)
				while n == Vector2i(x, y):
					if rng.u(2) == 0:
						n.x += rng.s(2)
					else:
						n.y += rng.s(2)
				if _inside(n.x, n.y):
					match cell(n.x, n.y):
						ROCK: put(n.x, n.y, CRATE)
						EMPTY: put(n.x, n.y, MOSS)

## Pong nhiều bóng: vợt trái = người chơi, vợt phải = máy (ở màn 8 máy khôn hơn). Đỡ +1, bóng qua máy +10,
## để lọt -10; lọt quả cuối = thua. Bóng mới thỉnh thoảng hiện ra đứng yên, chạy khi hết bóng đang bay.
class Bong extends Game:
	const BOTTOM := H - 40   # field_540
	const TOP := 7680        # 30 << 8
	const PAD_MIN := 9728
	const PAD_MAX := BOTTOM - 8 << 8
	var me_y := 0            # field_543
	var ai_y := 0            # field_544
	var ai_off := 0          # field_555
	var bx := PackedInt64Array()   # field_545..548
	var by := PackedInt64Array()
	var bvx := PackedInt64Array()
	var bvy := PackedInt64Array()
	var active: Array = []   # field_550
	var start := true        # field_551
	var running := false     # field_552
	var over := false        # field_553

	func _init() -> void:
		for a in [bx, by, bvx, bvy]:
			a.resize(16)
		active.resize(16)
		active.fill(false)

	func moving(i: int) -> bool:
		return bvx[i] != 0 or bvy[i] != 0

	func tick(dt: int, held: int) -> void:   # method_261
		clock += dt
		if start:
			start = false
			me_y = ((BOTTOM - 30 >> 1) + 30) << 8
			ai_y = me_y
			active.fill(false)
			active[0] = true
			by[0] = me_y
			bx[0] = W >> 1 << 8
			_kick(0)
			score = 0
		if running and not paused:
			me_y = clampi(me_y + (-1 if held & UP else 1 if held & DOWN else 0) * dt * 13, PAD_MIN, PAD_MAX)
			_move_ai(dt)
			_move_balls(dt)
			for i in _periods(dt, 2000):   # method_263
				if rng.u(101) <= 20:
					var free := active.find(false)
					if free < 0:
						break
					_spawn(free)
			_check()
			hi = maxi(hi, score)

	func press(k: String) -> void:   # method_271
		if over:
			over = false
			start = true
			return
		running = true
		if k == "fire":
			paused = not paused
		elif k == "restart":
			start = true
			running = false

	func _spawn(i: int) -> void:   # method_262
		active[i] = true
		bx[i] = rng.u(W - 80) + 40 << 8
		by[i] = rng.u(BOTTOM - 30) + 30 << 8
		bvx[i] = 0
		bvy[i] = 0

	func _kick(i: int) -> void:   # method_264
		var vx := 0
		var vy := 0
		while absi(vx) < 8:
			vx = rng.s(14)
			vy = rng.s(14)
		bvx[i] = vx << 8
		bvy[i] = vy << 8

	func _check() -> void:   # method_265
		for i in 16:
			if active[i] and moving(i) and bx[i] > W << 8:
				active[i] = false
				score += 10
		var lost := false
		for i in 16:
			if active[i] and bx[i] < -2048 and bvx[i] < 0:
				active[i] = false
				lost = true
				score -= 10
		var flying := 0
		var still := 0
		for i in 16:
			if not moving(i):
				still += 1
			elif active[i]:
				flying += 1
		if lost and flying == 0:
			running = false
			over = true
		elif flying == 0:
			if still == 0:
				for i in 4:
					_spawn(i)
			for i in 16:
				_kick(i)

	func _move_ai(dt: int) -> void:   # method_267
		if level_id == 8:
			var aim := ai_y + (ai_off << 8)
			var r := -1   # bóng bay về phía máy gần nhất
			var l := -1   # bóng bay ra xa gần nhất
			for i in 16:
				if active[i] and moving(i):
					var d := _dist2(i, aim)
					if bvx[i] < 0:
						if l < 0 or _dist2(l, aim) > d:
							l = i
					elif r < 0 or _dist2(r, aim) > d:
						r = i
			if r < 0:
				r = l
			if r < 0:
				return
			var sgn := 1 if aim < by[r] else -1 if aim > by[r] else 0
			ai_y += sgn * dt * 15
			aim = ai_y + (ai_off << 8)
			if sgn == 1 and by[r] < aim or sgn == -1 and by[r] > aim:
				aim = by[r]
			ai_y = aim - (ai_off << 8)
		else:
			var t := -1
			for i in 16:
				if active[i] and moving(i) and (t < 0 or bx[i] > bx[t]):
					t = i
			if t < 0:
				return
			var sgn := 1 if ai_y < by[t] else -1 if ai_y > by[t] else 0
			ai_y += sgn * dt * 13
			if sgn == 1 and by[t] < ai_y or sgn == -1 and by[t] > ai_y:
				ai_y = by[t]
		ai_y = clampi(ai_y, PAD_MIN, PAD_MAX)

	func _dist2(i: int, aim: int) -> int:
		var dx := W - 4 - (bx[i] >> 8)
		var dy := aim - by[i] >> 8
		return dx * dx + dy * dy

	func _move_balls(dt: int) -> void:   # method_268: nảy tường, nảy vợt (lệch theo chỗ chạm, nhanh dần), chạm nhau thì đổi hướng ngẫu nhiên
		for i in 16:
			if not active[i]:
				continue
			var x := bx[i]
			var y := by[i]
			var vx := bvx[i]
			var vy := bvy[i]
			var nx := x + (vx * dt >> 8)
			var ny := y + (vy * dt >> 8)
			var hit := true
			var n := 0
			while hit and n < 8:
				hit = false
				if vy < 0 and ny <= TOP:
					var p = Minigames.cross(0, TOP, W << 8, TOP, x, y, nx, ny)
					if p != null:
						x = p.x
						y = p.y + 1
						ny = y - (ny - y)
					vy = -vy
					hit = true
				if not hit and vy > 0 and ny >= BOTTOM << 8:
					var p = Minigames.cross(0, BOTTOM << 8, W << 8, BOTTOM << 8, x, y, nx, ny)
					if p != null:
						x = p.x
						y = p.y - 1
						ny = y - (ny - y)
					vy = -vy
					hit = true
				if not hit and vx < 0 and nx <= 1024:
					var p = Minigames.cross(1024, me_y - 3072, 1024, me_y + 3328, x, y, nx, ny)
					if p != null:
						x = p.x + 1
						y = p.y
						nx = x - (nx - x)
						vx = -vx + 128
						vy += y - me_y
						hit = true
						score += 1
				if not hit and vx > 0 and nx >= W - 4 << 8:
					var p = Minigames.cross(W - 4 << 8, ai_y - 3072, W - 4 << 8, ai_y + 3328, x, y, nx, ny)
					if p != null:
						x = p.x - 1
						y = p.y
						nx = x - (nx - x)
						vx = -vx - 128
						vy += y - ai_y
						hit = true
						if level_id == 8:
							ai_off = rng.s(8)
				if not hit:
					for j in 16:
						if active[j] and j != i:
							var dx := (bx[j] >> 8) - (x >> 8)
							var dy := (by[j] >> 8) - (y >> 8)
							if dx * dx + dy * dy < 16:
								_kick(j)
								_kick(i)
								vx = bvx[i]
								vy = bvy[i]
								nx = x + (vx * dt >> 8)
								ny = y + (vy * dt >> 8)
								hit = true
				if hit:
					n += 1
			bx[i] = nx
			by[i] = ny
			bvx[i] = vx
			bvy[i] = vy

## method_126: căn bậc hai nguyên.
static func isqrt(v: int) -> int:
	return int(sqrt(float(v)))

## method_127: giao điểm đoạn (x0,y0)-(x1,y1) với đoạn (x2,y2)-(x3,y3), tham số theo 1/32. Không cắt -> null.
static func cross(x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, x3: int, y3: int):
	var d := x0 * (y3 - y2) + x1 * (y2 - y3) + x3 * (y1 - y0) + x2 * (y0 - y1)
	if d == 0:
		return null
	var t := (x0 * (y3 - y2) + x2 * (y0 - y3) + x3 * (y2 - y0) << 5) / d
	var u := -(x0 * (y2 - y1) + x1 * (y0 - y2) + x2 * (y1 - y0) << 5) / d
	if t < 0 or t > 32 or u < 0 or u > 32:
		return null
	return Vector2i(x0 + (t * (x1 - x0) >> 5), y0 + (t * (y1 - y0) >> 5))
