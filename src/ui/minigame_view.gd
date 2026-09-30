class_name MinigameView
extends Control
## Vẽ một minigame (Minigames.Game) trên khung 240x320 gốc, phóng to giữa màn. Esc: về game, R: chơi lại (Bong).

signal closed(id: int, hi: int)

const DIRS := {"move_up": "up", "move_down": "down", "move_left": "left", "move_right": "right"}
const HELD := {"move_up": Minigames.UP, "move_down": Minigames.DOWN, "move_left": Minigames.LEFT, "move_right": Minigames.RIGHT}
const WORM_COLORS := {0: Color8(184, 134, 11), 1: Color8(144, 111, 7), 2: Color8(144, 111, 7), 12: Color8(139, 69, 19)}

var game: Minigames.Game
var id := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func open(which: int, level: int, hi: int) -> void:
	id = which
	game = Minigames.create(which, level, hi)
	show()

func _process(delta: float) -> void:
	if not visible:
		return
	var held := 0
	for a in HELD:
		if Input.is_action_pressed(a):
			held |= HELD[a]
	game.tick(mini(int(delta * 1000.0), 100), held)
	queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	get_viewport().set_input_as_handled()
	if ev.is_action_pressed("menu"):
		hide()
		closed.emit(id, game.hi)
	elif ev.is_action_pressed("interact"):
		game.press("fire")
	elif ev.physical_keycode == KEY_R:
		game.press("restart")
	else:
		for a in DIRS:
			if ev.is_action_pressed(a):
				game.press(DIRS[a])
				return
		game.press("")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var k := minf(size.x / Minigames.W, size.y / Minigames.H)
	draw_set_transform((size - Vector2(Minigames.W, Minigames.H) * k) / 2, 0, Vector2(k, k))
	draw_rect(Rect2(0, 0, Minigames.W, Minigames.H), Color.BLACK)
	var g := game
	if g is Minigames.Darts:
		_draw_darts(g)
	elif g is Minigames.Worm:
		_draw_worm(g)
	else:
		_draw_bong(g)
	for t in g.texts:
		_text_center(t.s, Vector2(t.x, t.y >> 8), Color8(170, 95, 80))
	var sc := "SC=%d HI=%d" % [g.score, g.hi]
	_text_center(Minigames.TITLES[id], Vector2(Minigames.W / 2, 8), Color8(184, 134, 11) if id == 1 else Color.WHITE)
	_text_center(sc, Vector2(Minigames.W / 2, Minigames.H - 8 if id != 2 else Minigames.Bong.BOTTOM + 17), Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 16), "Esc: thoát   Enter: bắn / tạm dừng   R: chơi lại",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

func _draw_darts(d: Minigames.Darts) -> void:   # method_243/245
	var c := Vector2(Minigames.W / 2, Minigames.H / 2)
	draw_rect(Rect2(0, 0, Minigames.W, Minigames.H), Color8(80, 49, 48))
	for i in 8:
		draw_circle(c, (96 - i * 12) / 2.0, Color.BLACK if i % 2 == 0 else Color8(192, 192, 192))
	for p in d.thrown:
		draw_circle(c + Vector2(p), 3, Color8(255, 140, 0))
	for i in 5:
		draw_circle(Vector2(5, Minigames.H / 2 - 17 + i * 8), 3, Color8(255, 140, 0) if i < 5 - d.thrown.size() else Color8(32, 32, 32))
	var a := c + Vector2(d.aim.x >> 8, d.aim.y >> 8)
	for arm in [Rect2(-1, -9, 3, 7), Rect2(-1, 2, 3, 7), Rect2(-9, -1, 7, 3), Rect2(2, -1, 7, 3)]:
		draw_rect(Rect2(a + arm.position, arm.size), Color8(16, 32, 80))
	for arm in [Rect2(0, -8, 1, 5), Rect2(0, 3, 1, 5), Rect2(-8, 0, 5, 1), Rect2(3, 0, 5, 1)]:
		draw_rect(Rect2(a + arm.position, arm.size), Color8(80, 96, 170))
	_frame(310, Vector2(d.bird.x >> 8, d.bird.y >> 8) - Portraits.frame(310).anchor)

func _draw_worm(w: Minigames.Worm) -> void:   # method_256/258
	draw_rect(Rect2(0, 0, Minigames.W, Minigames.H), Color8(139, 69, 19))
	for y in Minigames.Worm.GH:
		for x in Minigames.Worm.GW:
			var r := Rect2((x + 1) * 7, (y + 3) * 7, 7, 7)
			var c := w.cell(x, y)
			match c:
				Minigames.Worm.DIRT, Minigames.Worm.EMPTY, Minigames.Worm.ROCK:
					draw_rect(r, WORM_COLORS[c])
					if c == Minigames.Worm.ROCK:
						draw_rect(r.grow(-1), Color8(110, 55, 15))
				Minigames.Worm.GEM:
					draw_rect(r, WORM_COLORS[c])
					_frame(310, r.position)
				Minigames.Worm.CRATE:
					draw_rect(r, Color.BLACK)
					draw_rect(r.grow(-1), Color8(240, 248, 255))
					draw_line(r.position + Vector2(1, 1), r.end - Vector2(1, 1), Color8(128, 128, 128))
				Minigames.Worm.MOSS:
					draw_rect(r, Color8(0, 64, 0))
					draw_rect(r.grow(-2), Color8(68, 91, 32))
				Minigames.Worm.HEAD:
					if w.level_id == 15:
						draw_rect(r, Color.BLACK)
						_frame(147 if w.ticks % 2 else 149, r.position)
					else:
						draw_rect(r, Color8(112, 16, 8))
						draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, 3)), Color.BLACK)
						draw_rect(Rect2(r.position + Vector2(5, 1), Vector2(1, 3)), Color.BLACK)
						draw_rect(Rect2(r.position + Vector2(2, 5), Vector2(3, 1)), Color.BLACK)
				Minigames.Worm.BUG, Minigames.Worm.BUG_ANGRY:
					draw_rect(r, Color.BLACK)
					draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(5, 5)), Color8(64, 32, 144) if c == Minigames.Worm.BUG else Color8(208, 32, 144))
				_:
					draw_rect(r, Color.BLACK)
	if w.intro_ms > 0:
		_text_center("LEVEL %d" % (w.level + 1), Vector2(Minigames.W / 2, Minigames.H / 2), Color8(184, 134, 11))
	if w.paused:
		_text_center("PAUSED", Vector2(Minigames.W / 2, Minigames.H / 2), Color8(184, 134, 11))
	if w.dead:
		_text_center("Bấm phím để chơi lại", Vector2(Minigames.W / 2, Minigames.H / 2 + 14), Color.WHITE)

func _draw_bong(b: Minigames.Bong) -> void:   # method_269/270
	draw_rect(Rect2(0, 22, Minigames.W, 8), Color.WHITE)
	draw_rect(Rect2(0, Minigames.Bong.BOTTOM, Minigames.W, 8), Color.WHITE)
	draw_rect(Rect2(0, (b.me_y >> 8) - 10, 4, 21), Color.WHITE)
	draw_rect(Rect2(Minigames.W - 4, (b.ai_y >> 8) - 10, 4, 21), Color.WHITE)
	var ball := 147 if b.level_id == 15 else 310
	var half: Vector2 = Portraits.frame(ball).rect.size / 2
	for i in 16:
		if b.active[i]:
			_frame(ball, Vector2(b.bx[i] >> 8, b.by[i] >> 8) - half)
	_frame(234, Vector2(1, Minigames.Bong.BOTTOM + 9))
	var rival := 142 if b.level_id == 8 else 279
	_frame(rival, Vector2(Minigames.W - Portraits.frame(rival).rect.size.x - 1, Minigames.Bong.BOTTOM + 9))
	if b.over:
		_text_center("GAME OVER", Vector2(Minigames.W / 2, Minigames.H / 2), Color.WHITE)
	elif b.paused:
		_text_center("PAUSED", Vector2(Minigames.W / 2, Minigames.H / 2), Color.WHITE)
	elif not b.running:
		_text_center("Bấm phím để bắt đầu", Vector2(Minigames.W / 2, Minigames.H / 2), Color.WHITE)

func _frame(f: int, top_left: Vector2) -> void:
	draw_texture_rect(Portraits.texture(f), Rect2(top_left, Portraits.frame(f).rect.size), false)

## method_275/276: chữ giữa điểm, viền đen.
func _text_center(s: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := 10
	var p := at - Vector2(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, -fs / 2.0)
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color.BLACK)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
