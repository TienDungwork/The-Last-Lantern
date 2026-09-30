class_name ActorView
extends Node3D
## Nhân vật trượt giữa hai ô trong STEP_TIME giây; quay mặt theo hướng.
## Kiểu B: frame gốc nằm phẳng, mỗi hướng một chu kỳ frame, chạy khi đang di chuyển (field_138 / 150 ms).

const STEP_TIME := 0.18
const FACING_Y := {1: -PI / 2, 2: PI, 3: PI / 2, 4: 0.0}   # hướng game -> góc quanh trục Y
const HALE := [[240, 241, 240, 242], [237, 238, 237, 239], [231, 232, 231, 233], [234, 235, 234, 236]]   # field_144
const CLOAKED := [[272, 273, 272, 274], [269, 270, 269, 271], [263, 264, 263, 265], [266, 267, 266, 268]]   # field_473, cũng là tu sĩ
const LANTERN_ITEM := 7
const LANTERN_FRAMES := {2: 260, 1: 261}   # đèn lồng cầm tay vẽ đè khi quay xuống / sang phải
const HELD_LIGHT := [246, 244, 243, 245]   # field_235: đèn loại 1 theo hướng
const HELD_OFFSET := [[2, -2, 0, -2, -5, -1, 2, -4], [0, -4, 1, 0, -3, -4, 0, -6], [2, -2, -1, 1, -5, -2, 0, -3]]   # field_227
const LIE_DOWN := [[166, 200], [164, 0]]                    # field_145/146; 0 = giữ
const GET_UP := [[163, 1500], [164, 1000], [166, 300]]      # field_147/148

var frames: Array = HALE    # [hướng 1..4] -> chu kỳ frame
var frame_ms := 150
var idle := -1              # >= 0: frame khi đứng yên (boss 1), không thì frame đầu chu kỳ
var layers: Array = []      # lớp phụ chồng lên, mỗi lớp một chu kỳ 200 ms (boss 2)
var glow := false           # tự sáng và chạy frame cả khi đứng yên (cục lửa)
var dir := 2
var _tween: Tween
var _sprite: Sprite3D
var _ms := 0.0
var _clock := 0.0
var _last := Vector3.INF
var _seq: Array = []        # [[frame, ms], ...] đang phát (nằm / đứng dậy), rỗng = theo hướng
var _seq_ms := 0.0
var _lantern: Sprite3D
var _held: Sprite3D
var _held_type := -1

func _ready() -> void:
	if get_child_count() == 0 and LevelBuilder.art == "B":
		_sprite = LevelBuilder.frame_sprite(frames[dir - 1][0])
		_sprite.shaded = not glow
		add_child(_sprite)
		for i in layers.size():
			var l := LevelBuilder.frame_sprite(layers[i][0])
			l.set_meta("layer", i)
			_sprite.add_child(l)
			l.rotation = Vector3.ZERO
			l.position.z = 0.0003 * (i + 1)   # hệ toạ độ sprite phẳng: +z là phía camera
	elif get_child_count() == 0 and LevelBuilder.art == "A":
		_build_toon_hale()
	elif get_child_count() == 0:
		var mi := MeshInstance3D.new()
		var m := CapsuleMesh.new()
		m.radius = 0.25
		m.height = 1.4
		mi.mesh = m
		mi.position.y = 0.7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.75, 0.6)
		mi.material_override = mat
		add_child(mi)

func _process(delta: float) -> void:
	if _sprite == null:
		return
	_clock += delta * 1000.0
	var moving := glow or (position != _last and _last != Vector3.INF)
	_last = position
	_ms = _ms + delta * 1000.0 if moving else 0.0
	var f: int
	if not _seq.is_empty():
		_seq_ms += delta * 1000.0
		while _seq.size() > 1 and _seq_ms >= _seq[0][1]:
			_seq_ms -= _seq[0][1]
			_seq.pop_front()
		f = _seq[0][0]
		if _seq.size() == 1 and _seq[0][1] > 0 and _seq_ms >= _seq[0][1]:
			_seq.clear()
	else:
		var cycle: Array = frames[dir - 1]
		f = cycle[int(_ms / frame_ms) % cycle.size()] if moving else (idle if idle >= 0 else cycle[0])
	if _sprite.get_meta("frame") != f:
		LevelBuilder.set_frame(_sprite, f)
	for l in _sprite.get_children():
		if not l.has_meta("layer"):
			continue
		var cyc: Array = layers[l.get_meta("layer")]
		var lf: int = cyc[int(_clock / 200.0) % cyc.size()]
		if l.get_meta("frame") != lf:
			LevelBuilder.set_frame(l, lf)
	_sprite.position = Vector3(-0.5, LevelBuilder.depth(position.z) + LevelBuilder.DEPTH_ROW / 2, -0.5)
	if _lantern:
		_lantern.visible = LANTERN_FRAMES.has(dir) and _seq.is_empty()
		if _lantern.visible and _lantern.get_meta("frame") != LANTERN_FRAMES[dir]:
			LevelBuilder.set_frame(_lantern, LANTERN_FRAMES[dir])
	if _held:
		_place_held()

## Kiểu B: trang phục theo món đang cầm (áo choàng = hình tu sĩ, đèn lồng) và đèn đang xách (loại, bật/tắt; -1 = không).
func dress(equipped: int, held_type: int, held_on: bool) -> void:
	if _sprite == null:
		return
	frames = CLOAKED if equipped == GridState.CLOAK else HALE
	if equipped == LANTERN_ITEM and _lantern == null:
		_lantern = LevelBuilder.frame_sprite(LANTERN_FRAMES[2])
		_lantern.rotation = Vector3.ZERO
		_lantern.position.z = 0.0003
		_sprite.add_child(_lantern)
	elif equipped != LANTERN_ITEM and _lantern:
		_lantern.queue_free()
		_lantern = null
	if held_type < 0 or held_type > 2:
		if _held:
			_held.queue_free()
			_held = null
		_held_type = -1
		return
	if _held == null:
		_held = LevelBuilder.frame_sprite(248)
		_held.rotation = Vector3.ZERO
		_sprite.add_child(_held)
	_held_type = held_type
	_held.set_meta("on", held_on)
	_place_held()

## method_106: đèn xách lệch theo hướng; quay xuống thì vẽ đè lên người, còn lại vẽ dưới.
func _place_held() -> void:
	var f := 248
	if _held_type == 2:
		f = 251 if _held.get_meta("on") else 250
	elif _held_type == 1:
		f = HELD_LIGHT[dir - 1]
	if _held.get_meta("frame") != f:
		LevelBuilder.set_frame(_held, f)
	var o: Array = HELD_OFFSET[_held_type]
	_held.position = Vector3(o[(dir - 1) * 2], -o[(dir - 1) * 2 + 1], 0.0003 if dir == 2 else -0.0003) / Vector3(16, 16, 1)
	_held.visible = _seq.is_empty()

## Hale tạm cho kiểu A, ghép khối (thay bằng GLB ở M3).
func _build_toon_hale() -> void:
	var body := Node3D.new()
	add_child(body)
	var coat := CylinderMesh.new()
	coat.top_radius = 0.16
	coat.bottom_radius = 0.28
	coat.height = 0.95
	LevelBuilder.part(body, coat, Color(0.22, 0.18, 0.15), Vector3(0, 0.58, 0))
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	LevelBuilder.part(body, head, Color(0.85, 0.66, 0.52), Vector3(0, 1.2, 0))
	var hair := SphereMesh.new()
	hair.radius = 0.16
	hair.height = 0.26
	LevelBuilder.part(body, hair, Color(0.15, 0.1, 0.08), Vector3(0, 1.27, -0.03))
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.08
	scarf.outer_radius = 0.17
	LevelBuilder.part(body, scarf, Color(0.5, 0.12, 0.1), Vector3(0, 1.05, 0))
	var bag := BoxMesh.new()
	bag.size = Vector3(0.12, 0.22, 0.2)
	LevelBuilder.part(body, bag, Color(0.4, 0.26, 0.14), Vector3(0.27, 0.6, 0.05))
	for x in [-0.1, 0.1]:
		var boot := BoxMesh.new()
		boot.size = Vector3(0.12, 0.12, 0.2)
		LevelBuilder.part(body, boot, Color(0.1, 0.07, 0.05), Vector3(x, 0.06, 0.03))

func snap_to(p: Vector2i) -> void:
	if _tween:
		_tween.kill()
	position = LevelBuilder.world_pos(p)
	_last = position

func move_to(p: Vector2i) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", LevelBuilder.world_pos(p), STEP_TIME)
	_tween.finished.connect(set_anim.bind("idle"), CONNECT_ONE_SHOT)
	set_anim("walk")

func face(d: int) -> void:
	if d in FACING_Y:
		dir = d
	if _sprite == null:
		rotation.y = FACING_Y.get(d, 0.0)

## SPECIAL 15/16 (method_105, field_145..148): nằm xuống 0.2 s rồi nằm yên; đứng dậy 1.5 + 1.0 + 0.3 s.
## Trả về số giây kịch bản phải chờ.
func lie(lying: bool) -> float:
	if _sprite == null:
		return 0.0
	_seq = (LIE_DOWN if lying else GET_UP).duplicate(true)
	_seq_ms = 0.0
	return 1.7 if lying else 2.8

func set_anim(anim: String) -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(anim):
		ap.play(anim)
