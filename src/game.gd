extends Node3D
## Nối core (GridState, RulesClassic) với view (LevelBuilder, ActorView, LightingView, CameraRig) và ui.

const KEYS := {
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"interact": [KEY_ENTER, KEY_SPACE, KEY_E, KEY_F],
	"menu": [KEY_ESCAPE], "inventory": [KEY_TAB, KEY_I], "map": [KEY_M],
}
const DIR_ACTION := {"move_right": 1, "move_down": 2, "move_left": 3, "move_up": 4}
const PIXEL_SCALE := 2   # kiểu B: 1 pixel cảnh = 2x2 pixel cửa sổ (1280x720 -> cảnh 640x360)

@export var start_level := 0
@export var lang := "vi"

var world := World.new()
var state: GridState
var rules: RulesClassic
var builder: LevelBuilder
var actor: ActorView
var lighting: LightingView
var rig: CameraRig
var dialog: DialogBox
var hud: Hud
var _say_queue: Array = []
var _reload_after_dialog := false
var _pending_level := {}       # change_level chờ đóng hết thoại rồi mới chuyển
var _held: Array = []        # phím hướng đang giữ, phím nhấn sau cùng ở cuối (được ưu tiên)
var _step_wait := 0.0        # giây còn lại trước khi được đi ô tiếp theo
var _guard_views: Dictionary = {}     # slot tu sĩ -> ActorView
var _creature_views: Dictionary = {}  # slot sinh vật -> ActorView

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
	rig = CameraRig.new()
	rig.target = actor
	world.add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	dialog = DialogBox.new()
	ui.add_child(dialog)
	dialog.closed.connect(_next_say)
	load_level(start_level)

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
	for views in [_guard_views, _creature_views]:
		for v in views.values():
			v.queue_free()
		views.clear()
	var out := state.enter().duplicate()
	state.out.clear()
	_handle(out)

func _refresh_light() -> void:
	rules.refresh_light()
	lighting.sync(state, rules.light, builder)
	hud.show_state(state, rules.light[state.player.y][state.player.x])

func _process(delta: float) -> void:
	if _reload_after_dialog or dialog.visible or not _pending_level.is_empty():
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
	_sync_entities()
	if not state.out.is_empty():
		var out := state.out.duplicate()
		state.out.clear()
		_handle(out)

## Tu sĩ và sinh vật đi liên tục theo ms trong core; view chỉ chép vị trí mỗi khung hình.
func _sync_entities() -> void:
	_sync_list(state.guards, _guard_views, GridState.GUARD_TILE_MS, _guard_view)
	_sync_list(state.creatures, _creature_views, GridState.CREATURE_TILE_MS, _creature_view)
	for i in _creature_views:   # đang chết: mờ dần trong 1 s
		var c = state.creatures[i]
		var spr := _creature_views[i].get_child(0) as Sprite3D
		spr.modulate.a = 1.0 - c.timer / 1000.0 if c.state == GridState.C_DYING else 1.0

func _sync_list(list: Array, views: Dictionary, unit: int, make: Callable) -> void:
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
		view.face(e.dir)

func _guard_view() -> ActorView:
	var v := ActorView.new()
	if LevelBuilder.art == "B":
		var spr := LevelBuilder.sprite("ak_00")
		spr.modulate = Color(1.0, 0.35, 0.3)   # ponytail: chưa có sprite tu sĩ áo đỏ, tô đỏ tạm ông lão ak_00
		v.add_child(spr)
	return v

func _creature_view() -> ActorView:
	var v := ActorView.new()
	var spr := LevelBuilder.sprite("ae_01")   # ponytail: chưa có sprite sinh vật, dùng vệt bóng mờ phóng to
	spr.modulate = Color(0.05, 0.0, 0.08)
	spr.scale *= 3.0
	v.add_child(spr)
	return v

func _unhandled_input(ev: InputEvent) -> void:
	# DialogBox (sâu hơn trong cây) nhận phím trước và đánh dấu handled khi đang mở.
	if ev.is_action_pressed("interact") and not dialog.visible and _pending_level.is_empty() and not _reload_after_dialog:
		var out := state.action().duplicate()
		state.out.clear()
		_handle(out)

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
			"say":
				_say_queue.append(o)
			"box_moved":
				builder.move_box(o.from, o.to)
			"tile_changed":
				builder.rebuild_tile(state, o.at)
			"change_level":
				_pending_level = o
			"death":
				_say_queue.append({"text_id": 162, "portrait": -1})
				_reload_after_dialog = true
			"todo":
				print("todo op %d %s" % [o.op, str(o.args)])
	_refresh_light()
	if not dialog.visible:
		_next_say()

func _next_say() -> void:
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
	dialog.show_line(o.text_id, o.portrait, lang, o.get("args", []))
