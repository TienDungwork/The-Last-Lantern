extends Node3D
## Nối core (GridState, RulesClassic) với view (LevelBuilder, ActorView, LightingView, CameraRig) và ui.

const KEYS := {
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"interact": [KEY_ENTER, KEY_SPACE, KEY_E, KEY_F],
	"menu": [KEY_ESCAPE], "inventory": [KEY_TAB, KEY_I], "map": [KEY_M],
}
const DIR_ACTION := {"move_right": 1, "move_down": 2, "move_left": 3, "move_up": 4}
const SAVE_PATH := "user://save.json"
# class_4.field_38 (nhạc mỗi màn, tài nguyên 54..60 = track 0..6); -1 = giữ nhạc đang phát (-123 ở bản gốc).
const LEVEL_MUSIC := [6, 5, 4, 6, 2, 2, 0, 6, 0, 5, 5, 0, 6, 4, 2, 2, 6, 5, 0, 0, 0, -1]
const TITLE_MUSIC := 4   # tài nguyên 58
const NEW_GAME_LEVEL := 16   # class_4 case 14: đoạn mở đầu "Năm năm trước...", tự đi rồi dịch chuyển sang màn 0
const PIXEL_SCALE := 1   # kiểu B: atlas ×4 đã đủ 64 px/ô, vẽ cảnh ở đúng độ phân giải cửa sổ
# Frame gốc (class_10): tu sĩ field_473; sinh vật sáng field_487 / tối field_488 / chết field_483;
# boss 1 đứng 410, đi field_395; boss 2 thân 421 + lớp field_408..411; cục lửa field_412; mũi tên field_451.
const CREATURE_LIT := [[281, 282], [277, 278], [275, 276], [279, 280]]
const CREATURE_DARK := [[286, 286, 286, 286, 287, 288], [283, 283, 283, 283, 284, 285], [286, 286, 286, 286, 287, 288], [283, 283, 283, 283, 284, 285]]
const CREATURE_DYING := [289, 290]
const BOSS_WALK := [[408, 409], [408, 409], [408, 409], [408, 409]]
const BOSS2_LAYERS := [[422, 423], [424, 429, 430], [425, 431, 432], [426, 433, 434]]
const FIREBALL := [[427, 428], [427, 428], [427, 428], [427, 428]]
const POINTER := [407, 406, 405, 404]

@export var start_level := 0
@export var show_title := true   # test / snap tắt để vào thẳng màn

var world := World.new()
var state: GridState
var rules: RulesClassic
var skills: Skills
var builder: LevelBuilder
var actor: ActorView
var lighting: LightingView
var rig: CameraRig
var dialog: DialogBox
var hud: Hud
var menu: Menu
var minigame: MinigameView
var _cutscene: ColorRect        # op 13: phủ màn đen + tranh
var music: AudioStreamPlayer
var _beam_view := Node3D.new()    # SPECIAL 0/1/3
var _dog_view := Node3D.new()     # SPECIAL 5/6/9
var _wipe := Wipe.new()           # SPECIAL 7
var _fx_wait := 0.0               # giây còn lại của hiệu ứng đang chặn hàng đợi thoại (xoá màn, nằm/đứng dậy)
var music_track := -1
var _say_queue: Array = []
var _reload_after_dialog := false
var _menu_in_game := false    # menu mở từ trong màn (không phải màn tiêu đề)
var _pending_level := {}       # change_level chờ đóng hết thoại rồi mới chuyển
var _held: Array = []        # phím hướng đang giữ, phím nhấn sau cùng ở cuối (được ưu tiên)
var _step_wait := 0.0        # giây còn lại trước khi được đi ô tiếp theo
var _guard_views: Dictionary = {}     # slot tu sĩ -> ActorView
var _creature_views: Dictionary = {}  # slot sinh vật -> ActorView
var _boss_view: Dictionary = {}       # 0 -> ActorView khi có boss
var _boss2_view: Dictionary = {}
var _fireball_views: Dictionary = {}
var _pointer_views: Dictionary = {}   # slot op 27 -> mũi tên
var _hud_slots: Dictionary = {}       # slot op 27 -> chỉ số nhóm HUD đang nháy

func _ready() -> void:
	_setup_input()
	var world: Node = _pixel_viewport() if LevelBuilder.art == "B" else self
	builder = LevelBuilder.new()
	world.add_child(builder)
	lighting = LightingView.new()
	world.add_child(lighting)
	lighting.setup_environment()
	actor = ActorView.new()
	world.add_child(actor)
	if LevelBuilder.art == "B":   # đèn phụ chỉ để nhìn rõ nhân vật; không ảnh hưởng luật sáng/tối của core
		var fill := OmniLight3D.new()
		fill.position.y = 1.0
		fill.omni_range = 2.0
		fill.light_energy = 0.9
		fill.light_color = LightingView.WARM
		fill.light_volumetric_fog_energy = 0.0
		actor.add_child(fill)
	world.add_child(_beam_view)
	world.add_child(_dog_view)
	rig = CameraRig.new()
	rig.target = actor
	world.add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	_cutscene = ColorRect.new()
	_cutscene.color = Color.BLACK
	_cutscene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cutscene.hide()
	ui.add_child(_cutscene)
	ui.add_child(_wipe)
	dialog = DialogBox.new()
	ui.add_child(dialog)
	dialog.closed.connect(_next_say)
	music = AudioStreamPlayer.new()
	music.finished.connect(music.play)   # nhạc lặp (class_0.method_1(x, -1))
	add_child(music)
	menu = Menu.new()
	ui.add_child(menu)
	menu.new_game.connect(_new_game)
	menu.continue_game.connect(_continue_game)
	menu.quit_to_title.connect(_to_title)
	menu.visibility_changed.connect(_on_menu_visibility)
	minigame = MinigameView.new()
	ui.add_child(minigame)
	minigame.closed.connect(_on_minigame_closed)
	if show_title:
		_to_title()
	else:
		load_level(start_level)

## Màn tiêu đề: màn 0 làm nền phía sau (không chạy thoại mở đầu), menu phủ lên.
func _to_title() -> void:
	_menu_in_game = false
	world = World.new()
	load_level(0)
	_say_queue.clear()
	_fx_wait = 0.0
	dialog.hide()
	hud.hide()
	menu.has_save = FileAccess.file_exists(SAVE_PATH)
	menu.open_title()
	play_music(TITLE_MUSIC)

## Track đang phát thì để yên (không phát lại từ đầu); < 0 tắt.
func play_music(track: int) -> void:
	if track == music_track:
		return
	music_track = track
	music.stop()
	if track >= 0:
		music.stream = load("res://assets/music/track_%d.wav" % track)
		music.play()

func _new_game(hero := "daniel") -> void:
	hud.show()
	world = World.new()
	world.hero = hero
	load_level(NEW_GAME_LEVEL)

func _continue_game() -> void:
	hud.show()
	if not continue_from_save():
		_new_game()

func _on_menu_visibility() -> void:
	if not menu.visible and state != null:
		if world.equipped == World.CAMERA:   # method_169: cầm máy ảnh thì buông đèn (phím bắn dành cho flash)
			state.carried = -1
		_refresh_light()
	if not menu.visible and _menu_in_game:   # field_434: đóng menu trong game -> chạy lại sự kiện cờ 128 ở ô đang đứng
		_menu_in_game = false
		var out := state.enter().duplicate()
		state.out.clear()
		_handle(out)

## Kiểu B: vẽ cảnh 3D ở 1/PIXEL_SCALE độ phân giải rồi phóng nguyên lần bằng nearest, pixel sắc và đều.
## UI vẫn vẽ ở độ phân giải đầy đủ. Trả về node chứa cảnh 3D.
func _pixel_viewport() -> Node:
	var layer := CanvasLayer.new()
	layer.layer = -1   # dưới UI
	add_child(layer)
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = PIXEL_SCALE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	box.add_child(vp)
	return vp

func _setup_input() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func load_level(n: int, spawn: Vector2i = Vector2i(-1, -1)) -> void:
	LevelData.hero = world.hero
	state = world.enter_level(n, spawn)
	rules = (RulesClara if world.hero == "clara" else RulesMain).new(state, randi())
	if skills == null or skills.s.world != world:
		skills = Skills.new(state)
	else:
		skills.s = state
	builder.build(state)
	actor.snap_to(state.player)
	for views in [_guard_views, _creature_views, _boss_view, _boss2_view, _fireball_views, _pointer_views]:
		for v in views.values():
			v.queue_free()
		views.clear()
	_hud_slots.clear()
	hud.highlight = -1
	_set_cutscene(-1)
	_fx_wait = 0.0
	_wipe.hide()
	if LEVEL_MUSIC[n] >= 0:
		play_music(LEVEL_MUSIC[n])
	if n == ScriptVM.AUTOSAVE_LEVEL:
		world.save_game(SAVE_PATH, n, state.player)
	var out := state.enter().duplicate()
	state.out.clear()
	_handle(out)

## "Chơi tiếp": nạp save rồi vào đúng màn, đúng chỗ. Không có save thì trả false.
func continue_from_save(path: String = SAVE_PATH) -> bool:
	var r := World.load_game(path)
	if r.is_empty():
		return false
	world = r.world
	load_level(r.level, r.at)
	return true

func _refresh_light() -> void:
	rules.refresh_light()
	lighting.sync(state, rules.light, builder)
	builder.sync_events(state)
	var held: Dictionary = state.lights[state.carried] if state.carried >= 0 else {}
	actor.dress(world.equipped, int(held.get("type", -1)), int(held.get("on", 0)) == 1)
	hud.show_state(state, rules.light[state.player.y][state.player.x])

func _process(delta: float) -> void:
	if skills:
		hud.show_skills(skills)
	hud.show_virus(rules.virus if rules is RulesClara else -1, rules is RulesClara and rules.monster)
	if _fx_wait > 0.0:
		_fx_wait -= delta
		if _fx_wait <= 0.0:
			_wipe.hide()   # method_187: kín màn là tắt ngay, kịch bản chạy tiếp
			_next_say()
		return
	if menu.visible or minigame.visible or _reload_after_dialog or dialog.visible or not _pending_level.is_empty():
		return
	# Giữ phím là đi liên tục, mỗi ô đúng một nhịp ActorView.STEP_TIME (kể cả khi đâm tường,
	# để sự kiện "repeat" không chạy mỗi khung hình).
	_step_wait = maxf(_step_wait - delta, 0.0)
	for action in DIR_ACTION:
		if Input.is_action_just_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif not Input.is_action_pressed(action):
			_held.erase(action)
	if _step_wait == 0.0 and not state.forced.is_empty():
		state.forced_step()
		_step_wait = ActorView.STEP_TIME
	elif _step_wait == 0.0 and not _held.is_empty():
		state.step(DIR_ACTION[_held.back()])   # step() xóa out cũ trước khi ghi
		_step_wait = ActorView.STEP_TIME
	rules.tick(int(delta * 1000.0))
	if skills.tick(int(delta * 1000.0)):
		_refresh_light()
	world.play_ms += int(delta * 1000.0)
	_sync_entities()
	if not state.out.is_empty():
		var out := state.out.duplicate()
		state.out.clear()
		_handle(out)

## Tu sĩ và sinh vật đi liên tục theo ms trong core; view chỉ chép vị trí mỗi khung hình.
func _sync_entities() -> void:
	_sync_list(state.guards, _guard_views, GridState.GUARD_TILE_MS, _frame_view.bind(ActorView.CLOAKED, 200))
	_sync_list(state.creatures, _creature_views, GridState.CREATURE_TILE_MS, _frame_view.bind(CREATURE_LIT, 200))
	for i in _creature_views:   # method_235: sáng/tối đổi chu kỳ; đang chết: frame chết + mờ dần trong 1 s
		var c = state.creatures[i]
		var v: ActorView = _creature_views[i]
		var lit := state.is_lit(Vector2i(roundi(v.position.x), roundi(v.position.z)))
		v.frames = [CREATURE_DYING, CREATURE_DYING, CREATURE_DYING, CREATURE_DYING] if c.state == GridState.C_DYING \
			else CREATURE_LIT if lit else CREATURE_DARK
		v.frame_ms = 200 if lit else 300
		var spr := v.get_child(0) as Sprite3D
		if spr:
			spr.modulate.a = 1.0 - c.timer / 1000.0 if c.state == GridState.C_DYING else 1.0
	var b := state.boss
	_sync_list([] if b.is_empty() else [b], _boss_view, GridState.BOSS_TILE_MS, _frame_view.bind(BOSS_WALK, 200, 410))
	if not b.is_empty():   # gục: mờ dần trong 5 s
		# ponytail: bản gốc cho boss rã thành 10 mảnh rơi (field_392); ở đây chỉ mờ dần
		var spr := _boss_view[0].get_child(0) as Sprite3D
		if spr:
			spr.modulate.a = 1.0 - b.timer / 5000.0 if b.dying else 1.0
	var b2 := state.boss2
	_sync_list([] if b2.is_empty() else [b2], _boss2_view, GridState.BOSS2_TILE, _frame_view.bind([[421], [421], [421], [421]], 200, 421, false, BOSS2_LAYERS))
	_sync_list(state.fireballs.map(func(p): return {"pos": p}), _fireball_views, 1, _frame_view.bind(FIREBALL, 200, -1, true))
	if _beam_view.get_meta("beam", {}) != state.sun_beam:
		_show_sun_beam(state.sun_beam)
	if _dog_view.get_meta("dog", {}) != state.dog:
		_show_dog(state.dog)

## method_186: tư thế 0 = frame 148/145/146 + đầu 147 (nháy sang 149 mỗi 500 ms, ngủ 150 ms và rung), tư thế 1 = 150/151/152.
func _show_dog(d: Dictionary) -> void:
	_dog_view.set_meta("dog", d.duplicate())
	for c in _dog_view.get_children():
		c.queue_free()
	if not d.visible:
		return
	_dog_view.position = LevelBuilder.world_pos(d.at, LevelBuilder.depth(d.at.y)) - Vector3(0.5, 0, 0.5)
	var parts: Array = [150, 151, 152] if d.pose == 1 else [148, 145, 146, 147]
	for i in parts.size():   # vẽ theo thứ tự: mảnh sau nhích lên trên mảnh trước
		var spr := LevelBuilder.frame_sprite(parts[i])
		spr.position.y = 0.0003 * i
		_dog_view.add_child(spr)
	if d.pose == 0:
		var t := Timer.new()
		t.timeout.connect(_dog_blink.bind(_dog_view.get_child(-1), d.sleep))
		_dog_view.add_child(t)
		t.start(0.15 if d.sleep else 0.5)

func _dog_blink(head: Sprite3D, sleep: bool) -> void:
	LevelBuilder.set_frame(head, 149 if head.get_meta("frame") == 147 else 147)
	var j := Vector2(randi_range(-2, 2), randi_range(-2, 2)) if sleep else Vector2.ZERO
	head.position = Vector3(j.x / 16.0, head.position.y, j.y / 16.0)

## SPECIAL 0/1/3: tia nắng chéo từ trên ô gốc xuống sàn 3 ô phía dưới (bức tượng), 1 hoặc 2 tia.
func _show_sun_beam(b: Dictionary) -> void:
	_beam_view.set_meta("beam", b)
	for c in _beam_view.get_children():
		c.queue_free()
	for k in b.get("n", 0):
		var from := LevelBuilder.world_pos(b.at, 2.5) + Vector3(-0.1 * k, 0, -0.5)
		var to := LevelBuilder.world_pos(b.at + Vector2i(0, 3), 0.1)
		var ray := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, from.distance_to(to))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.3)
		box.material = mat
		ray.mesh = box
		_beam_view.add_child(ray)
		ray.look_at_from_position((from + to) / 2, to)

func _sync_list(list: Array, views: Dictionary, unit: int, make: Callable) -> void:
	for i in views.keys():
		if i >= list.size():
			views[i].queue_free()
			views.erase(i)
	for i in list.size():
		var e = list[i]
		if e == null:
			if views.has(i):
				views[i].queue_free()
				views.erase(i)
			continue
		if not views.has(i):
			views[i] = make.call()
			builder.get_parent().add_child(views[i])
		var view: ActorView = views[i]
		view.position = Vector3(e.pos.x, 0, e.pos.y) / float(unit) * LevelBuilder.TILE
		view.face(e.get("dir", 0))

## Hình thực thể bằng frame gốc: frames[hướng] đổi mỗi ms khi đang đi, idle >= 0 là frame đứng yên.
## glow: cục lửa, tự sáng (không bị bóng tối che) và cháy liên tục cả khi đứng yên.
func _frame_view(frames: Array, ms: int, idle := -1, glow := false, layers: Array = []) -> ActorView:
	var v := ActorView.new()
	v.frames = frames
	v.frame_ms = ms
	v.idle = idle
	v.layers = layers
	v.glow = glow
	return v

## Op 13: màn đen, tranh minh hoạ ở giữa phía trên; hộp thoại vẫn nằm dưới. frame < 0: gỡ.
func _set_cutscene(frame: int) -> void:
	for c in _cutscene.get_children():
		c.queue_free()
	_cutscene.visible = frame >= 0
	if frame >= 0:
		var pic := Hud.icon(frame, 3)
		_cutscene.add_child(pic)
		pic.size = pic.custom_minimum_size
		pic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 80)

## Op 27: mũi tên nằm trên sàn chỉ hướng dir, nhún qua lại; {hud} thì HUD nhấp nháy.
func _set_pointer(slot: int, p) -> void:
	if _pointer_views.has(slot):
		_pointer_views[slot].queue_free()
		_pointer_views.erase(slot)
	if p != null and p.has("at"):   # method_219: frame field_451 tại góc ô lùi 8 px, nhún 0..10 px ngược hướng chỉ, 1 s/chu kỳ
		var node := Node3D.new()
		node.position = LevelBuilder.world_pos(p.at, 0.1) - Vector3(1.0, 0, 1.0)
		var spr := LevelBuilder.frame_sprite(POINTER[int(p.dir) - 1])
		spr.shaded = false
		node.add_child(spr)
		builder.get_parent().add_child(node)
		var back: Vector3 = {1: Vector3(-1, 0, 0), 2: Vector3(0, 0, -1), 3: Vector3(1, 0, 0), 4: Vector3(0, 0, 1)}[int(p.dir)] * 10.0 / 16.0
		var tw := node.create_tween().set_loops()
		tw.tween_property(spr, "position", back, 0.5)
		tw.tween_property(spr, "position", Vector3.ZERO, 0.5)
		_pointer_views[slot] = node
	_hud_slots.erase(slot)
	if p != null and p.has("hud"):
		_hud_slots[slot] = int(p.hud)
	hud.highlight = _hud_slots.values()[0] if not _hud_slots.is_empty() else -1

func _unhandled_input(ev: InputEvent) -> void:
	# DialogBox (sâu hơn trong cây) nhận phím trước và đánh dấu handled khi đang mở.
	if menu.visible or minigame.visible or dialog.visible or not _pending_level.is_empty() or _reload_after_dialog or _fx_wait > 0.0:
		return
	menu.world = world
	if ev.is_action_pressed("interact"):
		var out := state.action().duplicate()
		state.out.clear()
		_handle(out)
	elif ev.is_action_pressed("menu"):
		_menu_in_game = true
		menu.open_pause()
	elif ev.is_action_pressed("inventory"):
		_menu_in_game = true
		menu.open_inventory(menu._close)
	elif ev.is_action_pressed("map") and world.inventory.has(Menu.MAP_ITEM):
		_menu_in_game = true
		menu.open_map(menu._close)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode >= KEY_1 and ev.physical_keycode <= KEY_4:   # chiêu 1..4; số vẫn tính vào mã thưởng bên dưới
			var msg := "Đang hóa quái, không dùng được chiêu" if rules is RulesClara and rules.monster \
				else skills.use(ev.physical_keycode - KEY_1)
			if msg != "":
				hud.toast(msg)
			_refresh_light()
		var d := _digit(ev.physical_keycode)
		if d >= 0:
			for k in world.type_digit(d):
				if k >= World.MINIGAME_CODE:
					_open_minigame(k - World.MINIGAME_CODE)
			_refresh_light()

func _open_minigame(id: int) -> void:
	_held.clear()
	minigame.open(id, state.level.index, world.minigame_hi[id])

func _on_minigame_closed(id: int, hi: int) -> void:
	world.minigame_hi[id] = maxi(world.minigame_hi[id], hi)
	_next_say()

## Phím số hàng trên hoặc bàn phím số -> 0..9, không phải số -> -1.
static func _digit(k: int) -> int:
	if k >= KEY_0 and k <= KEY_9:
		return k - KEY_0
	if k >= KEY_KP_0 and k <= KEY_KP_9:
		return k - KEY_KP_0
	return -1

func _handle(out: Array) -> void:
	for o in out:
		match o.type:
			"moved":
				actor.face(o.dir)
				actor.move_to(o.to)
			"bumped":
				actor.face(o.dir)
			"teleported":
				actor.snap_to(o.to)
			"say", "pointer", "cutscene", "cutscene_end", "game_end", "wipe", "pose", "minigame":   # áp đúng lúc giữa các câu thoại (kịch bản dừng ở mỗi câu)
				_say_queue.append(o)
			"box_moved":
				builder.move_box(o.from, o.to)
			"tile_changed":
				builder.rebuild_tile(state, o.at)
			"change_level":
				_pending_level = o
			"autosave":
				world.save_game(SAVE_PATH, state.level.index, o.at)
			"music":
				play_music(o.track)
			"death":
				_say_queue.append({"text_id": 162, "portrait": -1})
				_reload_after_dialog = true
	_refresh_light()
	if not dialog.visible and _fx_wait <= 0.0:
		_next_say()

func _next_say() -> void:
	while not _say_queue.is_empty() and _say_queue[0].get("type", "say") != "say":
		var p: Dictionary = _say_queue.pop_front()
		match p.type:
			"pointer": _set_pointer(p.slot, p.value)
			"cutscene": _set_cutscene(p.frame)
			"cutscene_end": _set_cutscene(-1)
			"wipe":
				_wipe.start()
				_fx_wait = Wipe.TIME
				return
			"pose":
				_fx_wait = actor.lie(p.lying)
				if _fx_wait > 0.0:
					return
			"game_end":
				_to_title()
				return
			"minigame":
				_open_minigame(p.id)
				return
	if _say_queue.is_empty():
		if _reload_after_dialog:   # class_4 case 11: chết = nạp lại bản tự lưu gần nhất (method_114)
			_reload_after_dialog = false
			if not continue_from_save():
				_new_game(world.hero)
		elif not _pending_level.is_empty():
			var p := _pending_level
			_pending_level = {}
			load_level(p.level, p.to)
		return
	var o: Dictionary = _say_queue.pop_front()
	dialog.show_line(o.text_id, o.portrait, menu.lang, o.get("args", []))
