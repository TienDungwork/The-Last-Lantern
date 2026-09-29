extends Node3D
## Nối core (GridState, RulesClassic) với view (LevelBuilder, ActorView, LightingView, CameraRig) và ui.

const KEYS := {
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"interact": [KEY_ENTER, KEY_SPACE, KEY_E, KEY_F],
	"menu": [KEY_ESCAPE], "inventory": [KEY_TAB, KEY_I], "map": [KEY_M],
}
const DIR_ACTION := {"move_right": 1, "move_down": 2, "move_left": 3, "move_up": 4}

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

func _ready() -> void:
	_setup_input()
	builder = LevelBuilder.new()
	add_child(builder)
	lighting = LightingView.new()
	add_child(lighting)
	lighting.setup_environment()
	actor = ActorView.new()
	add_child(actor)
	rig = CameraRig.new()
	rig.target = actor
	add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	dialog = DialogBox.new()
	ui.add_child(dialog)
	dialog.closed.connect(_next_say)
	load_level(start_level)

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
	if not state.out.is_empty():
		var out := state.out.duplicate()
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
	dialog.show_line(o.text_id, o.portrait, lang)
