class_name LevelBuilder
extends Node3D
## Dựng lưới 3D từ GridState: một node sàn mỗi ô, một vật mỗi ô vật thể.
## rebuild_tile() dùng khi SET_TILE. lighting.gd tô màu sàn qua `floors`.

const TILE := 1.0
## Thử phong cách hình ảnh (snap.gd: --art A|B|box):
##   "box" khối hộp xám; "A" mô hình 3D ghép khối + toon + viền;
##   "B" nhìn thẳng từ trên xuống như bản gốc: frame gốc trên atlas vẽ lại ×4 (image/img) nằm phẳng, đèn 3D.
static var art := "B"
const B_PITCH := 90.0           # góc nhìn xuống của camera kiểu B
## Kiểu B: 1 ô = 16 px gốc × Portraits.SCALE = 64 pixel màn hình, 1 texel = đúng 1 pixel.
const TEXELS_PER_TILE := 64.0
## Kiểu B: vật hàng dưới đè hàng trên và đè người đứng hàng trên (method_107/108 vẽ lại các ô phía dưới người chơi).
const DEPTH_ROW := 0.002
const FLAT_FRAMES := [31, 36, 130, 135, 159]   # method_107: frame sát đất, không đè người chơi
const DARK_FLOOR_UNDER := [40, 41, 42, 44, 46, 47, 48, 50, 62, 63]   # ô sàn dưới các frame này vẽ frame tối
const FENCE_TILES := [92]

var floors: Dictionary = {}   # Vector2i -> MeshInstance3D
var objects: Dictionary = {}  # Vector2i -> Node3D
var boxes: Dictionary = {}    # Vector2i -> Node3D (hộp đẩy được, nằm ngoài lưới)
var _floor_mesh: MeshInstance3D   # kiểu B: cả sàn một ảnh
var _event_views: Array = []      # kiểu B: frame của sự kiện đang bật
var _event_key := ""

static func world_pos(p: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(p.x * TILE, y, p.y * TILE)

## Độ cao vẽ của thứ nằm ở hàng z (toạ độ thế giới): hàng dưới cao hơn, camera từ trên nhìn thấy đè lên.
static func depth(z: float) -> float:
	return 0.02 + (z + 1.0) * DEPTH_ROW

## Frame gốc nằm phẳng trên sàn; origin = góc trên trái ô như method_55, trục y của ảnh = hướng bắc (-z).
static func frame_sprite(frame: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = TILE / TEXELS_PER_TILE
	s.centered = false
	s.rotation.x = -PI / 2
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS   # viền mềm của ảnh vẽ lại vẫn trộn nền
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_frame(s, frame)
	return s

static func set_frame(s: Sprite3D, frame: int) -> void:
	var f := Portraits.frame(frame)
	s.texture = Portraits.texture(frame)
	s.offset = Vector2(-f.anchor.x, f.anchor.y - f.rect.size.y) * Portraits.SCALE
	s.set_meta("frame", frame)

## Frame phẳng vẽ tại góc trên trái ô p (+ lệch dx, dy px gốc), ở độ cao hàng.
func _put_frame(frame: int, p: Vector2i, dx := 0, dy := 0) -> Sprite3D:
	var s := frame_sprite(frame)
	s.position = Vector3(p.x - 0.5 + dx / 16.0, depth(p.y), p.y - 0.5 + dy / 16.0)
	add_child(s)
	return s

## SPECIAL 13 (method_190): cây chết ở tối đa 3 ô; SPECIAL 14 (method_193/191/192): biển PUB, chữ B chớp tắt.
func _decor(s: GridState) -> void:
	var trees := 0
	for e in s.events:
		if not e.has("x") or e.commands.is_empty() or int(e.commands[0].op) != 30:
			continue
		var at := Vector2i(int(e.x), int(e.y))
		match int(e.commands[0].args[0]):
			13 when trees < 3:
				trees += 1
				if art == "B":
					_put_frame(129, at)
				else:
					var t := frame_sprite(129)
					t.position = world_pos(at) - Vector3(0.5, -0.02, 0.5)
					add_child(t)
			14:
				var pub := _put_frame(119, at)
				pub.shaded = false
				var b := frame_sprite(120)
				b.shaded = false
				b.rotation = Vector3.ZERO
				b.position.z = 0.0005   # trong hệ toạ độ biển (đã nằm phẳng): nhích về phía camera
				pub.add_child(b)
				var timer := Timer.new()
				timer.timeout.connect(_flicker.bind(b, timer))
				pub.add_child(timer)
				b.hide()
				timer.start(5.0)

## method_191: sáng 100-150 ms, tắt 100-150 ms, 1/4 số lần tắt 5-8 s.
static func _flicker(b: Sprite3D, timer: Timer) -> void:
	b.visible = not b.visible
	var ms := 100 + randi() % 50
	if not b.visible and randi() % 4 == 0:
		ms = 5000 + randi() % 3000
	timer.start(ms / 1000.0)

## Vật liệu kiểu A: ánh sáng phân bậc (toon) + viền sẫm bằng mặt lật phóng to.
static func toon(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 1.0
	var outline := StandardMaterial3D.new()
	outline.albedo_color = Color(0.03, 0.02, 0.02)
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.02
	m.next_pass = outline
	return m

static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = toon(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

func build(s: GridState) -> void:
	for c in get_children():
		c.queue_free()
	floors.clear()
	objects.clear()
	boxes.clear()
	_event_views.clear()
	_event_key = ""
	if art == "B":
		_bake_floor(s)
	for y in s.level.height:
		for x in s.level.width:
			_place(s, Vector2i(x, y))
	for p in s.boxes:
		boxes[p] = _block(p, s.boxes[p])
	_decor(s)
	sync_events(s)

func move_box(from: Vector2i, to: Vector2i) -> void:
	var mi: Node3D = boxes[from]
	boxes.erase(from)
	boxes[to] = mi
	var y := mi.position.y
	create_tween().tween_property(mi, "position", world_pos(to, y), ActorView.STEP_TIME)
	if art == "B":
		(mi.get_child(0) as Node3D).position.y = depth(to.y)

func rebuild_tile(s: GridState, p: Vector2i) -> void:
	for d in [floors, objects]:
		if d.has(p):
			d[p].queue_free()
			d.erase(p)
	if art == "B":
		_bake_floor(s)   # ô sàn dưới vật có thể đổi sang frame tối/sáng
	_place(s, p)

## Kiểu B: ghép sàn cả màn thành một ảnh như df2_render_maps.py (frame 32x32 neo giữa, vẽ từ dưới phải lên trên trái).
func _bake_floor(s: GridState) -> void:
	var k := Portraits.SCALE
	var w := s.level.width
	var h := s.level.height
	var img := Image.create(w * 16 * k, h * 16 * k, false, Image.FORMAT_RGBA8)
	var ff: Array = LevelData.floor_frames()[s.level.tileset]
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var f := Portraits.frame(ff[0] if (s.tiles[y][x] - 8) in DARK_FLOOR_UNDER else ff[7])
			img.blend_rect(Portraits.image(f.png), Rect2i(f.rect.position * k, f.rect.size * k),
				Vector2i(x * 16 - int(f.anchor.x), y * 16 - int(f.anchor.y)) * k)
	if _floor_mesh == null or not is_instance_valid(_floor_mesh) or _floor_mesh.is_queued_for_deletion():
		_floor_mesh = MeshInstance3D.new()
		var m := PlaneMesh.new()
		m.size = Vector2(w, h) * TILE
		_floor_mesh.mesh = m
		_floor_mesh.position = Vector3((w - 1) / 2.0, 0, (h - 1) / 2.0) * TILE
		var mat := StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_floor_mesh.material_override = mat
		add_child(_floor_mesh)
	(_floor_mesh.material_override as StandardMaterial3D).albedo_texture = ImageTexture.create_from_image(img)

func _place(s: GridState, p: Vector2i) -> void:
	var t: int = s.tiles[p.y][p.x]
	if t >= 8:
		objects[p] = _block(p, t)
	if art == "B":
		return
	var mi := MeshInstance3D.new()
	var m := PlaneMesh.new()
	m.size = Vector2(TILE, TILE)
	mi.mesh = m
	var mat: StandardMaterial3D = toon(Color(0.08, 0.08, 0.1)) if art == "A" else StandardMaterial3D.new()
	mat.next_pass = null
	mi.position = world_pos(p)
	floors[p] = mi
	mi.material_override = mat
	add_child(mi)

func _block(p: Vector2i, t: int) -> Node3D:
	var props := LevelData.tile_props(t)
	var wall := int(props.blocks_light) == 1 and int(props.movable) == 0
	if art == "B":
		return _block_b(p, t, props)
	if art == "A" and not wall:
		return _block_a(p, t, props)
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var h := 1.0 if int(props.blocks_light) == 1 else 0.5
	if int(props.movable) == 1:
		h = 0.8
		mat.albedo_color = Color(0.45, 0.3, 0.15)
	elif int(props.blocks_light) == 1:
		mat.albedo_color = Color(0.35, 0.33, 0.3)
	else:
		mat.albedo_color = Color(0.5, 0.45, 0.4)
	if art == "A":
		mat = toon(Color(0.36, 0.34, 0.3))
	var m := BoxMesh.new()
	m.size = Vector3(TILE, h, TILE)
	mi.mesh = m
	mi.position = world_pos(p, h / 2.0)
	mi.material_override = mat
	add_child(mi)
	return mi

## Kiểu B: frame gốc (giá trị ô - 8) nằm phẳng; ô chắn sáng thêm hộp vô hình chỉ để đổ bóng đèn.
## ponytail: luôn vẽ frame "sáng"; bản gốc ẩn vật ở ô tối và đổi vài frame mép tường (method_134, 190-194).
func _block_b(p: Vector2i, t: int, props: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = world_pos(p)
	add_child(n)
	var f := t - 8
	var s := frame_sprite(f)
	s.position = Vector3(-0.5, 0.005 if f in FLAT_FRAMES else depth(p.y), -0.5)
	n.add_child(s)
	if int(props.blocks_light) == 1:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(TILE, 1.0, TILE)
		mi.mesh = m
		mi.position.y = 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		n.add_child(mi)
	return n

## Kiểu B: frame của sự kiện đang bật (vật phẩm, công tắc, đồ trang trí), như df2_render_maps.event_sprite.
## Gọi sau mỗi lượt xử lý; chỉ dựng lại khi danh sách đổi.
func sync_events(s: GridState) -> void:
	if art != "B":
		return
	var list := []
	for e in s.events:
		if e.has("x") and not e.commands.is_empty() and s.event_active[int(e.id)]:
			var sp := _event_frame(s, e.commands[0])
			if sp[0] >= 0:
				list.append([Vector2i(int(e.x), int(e.y))] + sp)
	var key := str(list)
	if key == _event_key:
		return
	_event_key = key
	for v in _event_views:
		v.queue_free()
	_event_views.clear()
	for it in list:
		_event_views.append(_put_frame(it[1], it[0], it[2], it[3]))

## [frame, dx, dy] của lệnh đầu sự kiện; frame -1 = không vẽ.
static func _event_frame(s: GridState, c: Dictionary) -> Array:
	var a: Array = c.args
	var s8 := func(v): return int(v) - 256 if int(v) > 127 else int(v)
	match int(c.op):
		26, 29:
			var f := (int(a[0]) << 8) | int(a[1])
			return [-1 if f == 0xFFFF else f, s8.call(a[2]) if int(c.op) == 29 else 0, s8.call(a[3]) if int(c.op) == 29 else 0]
		10:
			var i: int = s8.call(a[0])
			return [int(LevelData.item(i).frame) if i >= 0 else -1, 0, 0]
		23:
			var id := int(a[0]) & 127
			var on := id < s.lights.size() and int(s.lights[id].on) == 1
			return [(57 if on else 58) if int(a[0]) & 128 else (54 if on else 55), 0, 0]
		17:
			return [64, 0, 0]
	return [-1, 0, 0]

func _block_a(p: Vector2i, t: int, props: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = world_pos(p)
	add_child(n)
	var wood := Color(0.4, 0.26, 0.14)
	var iron := Color(0.2, 0.2, 0.22)
	if int(props.movable) == 1:
		var b := BoxMesh.new()
		b.size = Vector3(0.75, 0.75, 0.75)
		part(n, b, wood, Vector3(0, 0.375, 0))
	elif t in FENCE_TILES:
		for x in [-0.35, 0.0, 0.35]:
			var c := CylinderMesh.new()
			c.top_radius = 0.03
			c.bottom_radius = 0.04
			c.height = 0.8
			part(n, c, iron, Vector3(x, 0.4, 0))
		var rail := BoxMesh.new()
		rail.size = Vector3(1.0, 0.06, 0.06)
		part(n, rail, iron, Vector3(0, 0.6, 0))
	elif int(props.dim_light) == 1:
		var c := CylinderMesh.new()
		c.top_radius = 0.18
		c.bottom_radius = 0.28
		c.height = 0.7
		part(n, c, iron, Vector3(0, 0.35, 0))
		var s := SphereMesh.new()
		s.radius = 0.08
		s.height = 0.16
		part(n, s, Color(1.0, 0.6, 0.2), Vector3(0, 0.45, 0.25))
	else:
		match t % 3:
			0:
				var c := CylinderMesh.new()
				c.top_radius = 0.28
				c.bottom_radius = 0.28
				c.height = 0.7
				part(n, c, wood, Vector3(0, 0.35, 0))
			1:
				var b := BoxMesh.new()
				b.size = Vector3(0.6, 0.8, 0.15)
				part(n, b, Color(0.45, 0.45, 0.42), Vector3(0, 0.4, 0))
			_:
				var b := BoxMesh.new()
				b.size = Vector3(0.8, 0.5, 0.6)
				part(n, b, wood, Vector3(0, 0.25, 0))
	return n
