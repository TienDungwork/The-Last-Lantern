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
const PIXEL_SCALE := 2   # kiểu B: 1 pixel cảnh = 2x2 pixel cửa sổ (1280x720 -> cảnh 640x360)

@export var start_level := 0
@export var show_title := true   # test / snap tắt để vào thẳng màn

var world := World.new()
var state: GridState
var rules: RulesClassic
var builder: LevelBuilder
var actor: ActorView
var lighting: LightingView
var rig: CameraRig
var dialog: DialogBox
var hud: Hud
var menu: Menu
var _cutscene: ColorRect        # op 13: phủ màn đen + tranh
var music: AudioStreamPlayer
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

func _new_game() -> void:
	hud.show()
	world = World.new()
	load_level(0)

func _continue_game() -> void:
	hud.show()
	if not continue_from_save():
		_new_game()

func _on_menu_visibility() -> void:
	if not menu.visible and state != null:
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
	state = world.enter_level(n, spawn)
	rules = RulesClassic.new(state, randi())
	builder.build(state)
	actor.snap_to(state.player)
	for views in [_guard_views, _creature_views, _boss_view, _boss2_view, _fireball_views, _pointer_views]:
		for v in views.values():
			v.queue_free()
		views.clear()
	_hud_slots.clear()
	hud.highlight = -1
	_set_cutscene(-1)
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
	hud.show_state(state, rules.light[state.player.y][state.player.x])

func _process(delta: float) -> void:
	if menu.visible or _reload_after_dialog or dialog.visible or not _pending_level.is_empty():
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
	if _step_wait == 0.0 and not _held.is_empty():
		state.step(DIR_ACTION[_held.back()])   # step() xóa out cũ trước khi ghi
		_step_wait = ActorView.STEP_TIME
	rules.tick(int(delta * 1000.0))
	world.play_ms += int(delta * 1000.0)
	_sync_entities()
	if not state.out.is_empty():
		var out := state.out.duplicate()
		state.out.clear()
		_handle(out)

## Tu sĩ và sinh vật đi liên tục theo ms trong core; view chỉ chép vị trí mỗi khung hình.
func _sync_entities() -> void:
	_sync_list(state.guards, _guard_views, GridState.GUARD_TILE_MS, _sprite_view.bind("ap_00"))
	_sync_list(state.creatures, _creature_views, GridState.CREATURE_TILE_MS, _sprite_view.bind("aq_00"))
	for i in _creature_views:   # đang chết: mờ dần trong 1 s
		var c = state.creatures[i]
		var spr := _creature_views[i].get_child(0) as Sprite3D
		spr.modulate.a = 1.0 - c.timer / 1000.0 if c.state == GridState.C_DYING else 1.0
	var b := state.boss
	_sync_list([] if b.is_empty() else [b], _boss_view, GridState.BOSS_TILE_MS, _sprite_view.bind("ar_00"))
	if not b.is_empty():   # gục: mờ dần trong 5 s
		(_boss_view[0].get_child(0) as Sprite3D).modulate.a = 1.0 - b.timer / 5000.0 if b.dying else 1.0
	var b2 := state.boss2
	_sync_list([] if b2.is_empty() else [b2], _boss2_view, GridState.BOSS2_TILE, _sprite_view.bind("as_00"))
	_sync_list(state.fireballs.map(func(p): return {"pos": p}), _fireball_views, 1, _sprite_view.bind("at_00", true))

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

## Sprite thực thể (tools/crop_sheets.py HEIGHT_BY_SHEET): ap tu sĩ, aq sinh vật, ar boss 1, as boss 2, at lửa.
## glow: tự sáng, không bị bóng tối che.
func _sprite_view(sprite: String, glow := false) -> ActorView:
	var v := ActorView.new()
	var spr := LevelBuilder.sprite(sprite)
	spr.shaded = not glow
	v.add_child(spr)
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
	if p != null and p.has("at"):
		var node := Node3D.new()
		node.rotation.y = {1: 0.0, 2: -PI / 2, 3: PI, 4: PI / 2}.get(p.dir, 0.0)
		var spr := Sprite3D.new()
		spr.texture = load("res://assets/new/aj_01.png")
		spr.pixel_size = 1.0 / LevelBuilder.TEXELS_PER_TILE
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.rotation.x = -PI / 2
		spr.position.y = 0.05
		node.add_child(spr)
		node.position = LevelBuilder.world_pos(p.at)
		builder.get_parent().add_child(node)
		var tw := node.create_tween().set_loops()
		tw.tween_property(spr, "position:x", 0.25, 0.2)
		tw.tween_property(spr, "position:x", -0.25, 0.2)
		_pointer_views[slot] = node
	_hud_slots.erase(slot)
	if p != null and p.has("hud"):
		_hud_slots[slot] = int(p.hud)
	hud.highlight = _hud_slots.values()[0] if not _hud_slots.is_empty() else -1

func _unhandled_input(ev: InputEvent) -> void:
	# DialogBox (sâu hơn trong cây) nhận phím trước và đánh dấu handled khi đang mở.
	if menu.visible or dialog.visible or not _pending_level.is_empty() or _reload_after_dialog:
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
			"say", "pointer", "cutscene", "cutscene_end":   # áp đúng lúc giữa các câu thoại (kịch bản dừng ở mỗi câu)
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
			"todo":
				print("todo op %d %s" % [o.op, str(o.args)])
	_refresh_light()
	if not dialog.visible:
		_next_say()

func _next_say() -> void:
	while not _say_queue.is_empty() and _say_queue[0].get("type", "say") != "say":
		var p: Dictionary = _say_queue.pop_front()
		match p.type:
			"pointer": _set_pointer(p.slot, p.value)
			"cutscene": _set_cutscene(p.frame)
			"cutscene_end": _set_cutscene(-1)
	if _say_queue.is_empty():
		if _reload_after_dialog:
			_reload_after_dialog = false
			world.energy = world.max_energy
			load_level(state.level.index)
		elif not _pending_level.is_empty():
			var p := _pending_level
			_pending_level = {}
			load_level(p.level, p.to)
		return
	var o: Dictionary = _say_queue.pop_front()
	dialog.show_line(o.text_id, o.portrait, menu.lang, o.get("args", []))
