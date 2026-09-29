class_name LevelBuilder
extends Node3D
## Dựng lưới 3D từ GridState: một node sàn mỗi ô, một vật mỗi ô vật thể.
## rebuild_tile() dùng khi SET_TILE. lighting.gd tô màu sàn qua `floors`.

const TILE := 1.0
## Thử phong cách hình ảnh (snap.gd: --art A|B|box):
##   "box" khối hộp xám; "A" mô hình 3D ghép khối + toon + viền; "B" HD-2D: sprite pixel (image/new) + texture pixel.
static var art := "B"
const B_PITCH := 70.0           # góc nhìn xuống của camera kiểu B
## Kiểu B: 1 ô = 32 pixel trên cảnh render thấp (game.gd), 1 texel sprite = đúng 1 pixel đó.
const TEXELS_PER_TILE := 32.0

const ART_FENCE := "aa_14"      # vật chắn đường không chắn sáng, xếp thành hàng
const ART_BOX := "aa_09"
const ART_DIM := ["ak_03", "ad_09", "ad_10"]
const ART_PROPS := ["aa_19", "aa_20", "ai_02", "ak_05", "ao_01", "an_01", "al_01", "aa_10", "ad_02", "aa_08"]
const FENCE_TILES := [92]

var floors: Dictionary = {}   # Vector2i -> MeshInstance3D
var objects: Dictionary = {}  # Vector2i -> Node3D
var boxes: Dictionary = {}    # Vector2i -> Node3D (hộp đẩy được, nằm ngoài lưới)

static func world_pos(p: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(p.x * TILE, y, p.y * TILE)

## Sprite đứng trên gốc (chân ảnh ở origin), cỡ gốc 1 texel = 1 pixel, chịu ánh sáng đèn, có bóng tròn dưới chân.
static func sprite(name: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load("res://assets/new/%s.png" % name)
	s.pixel_size = 1.0 / TEXELS_PER_TILE
	s.offset.y = s.texture.get_height() / 2.0
	# Đứng thẳng quay về camera (camera không xoay ngang), kéo cao bù góc nhìn: lên màn hình đúng 1 texel = 1 pixel.
	# Không ngả theo camera: ngả thì đầu cắm vào tường phía sau.
	s.scale.y = 1.0 / cos(deg_to_rad(B_PITCH))
	var width := s.texture.get_width() * s.pixel_size
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(width, width * 0.5)
	shadow.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/new/ae_01.png")
	mat.albedo_color = Color(0, 0, 0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.position.y = 0.01
	s.add_child(shadow)
	return s

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

## Texture lát theo toạ độ thế giới, mật độ TEXELS_PER_TILE texel mỗi đơn vị.
static func _pixel_tex(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex: Texture2D = load(path)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var sx := TEXELS_PER_TILE / tex.get_width()
	m.uv1_scale = Vector3(sx, TEXELS_PER_TILE / tex.get_height(), sx)
	return m

func build(s: GridState) -> void:
	for c in get_children():
		c.queue_free()
	floors.clear()
	objects.clear()
	boxes.clear()
	for y in s.level.height:
		for x in s.level.width:
			_place(s, Vector2i(x, y))
	for p in s.boxes:
		boxes[p] = _block(p, s.boxes[p])

func move_box(from: Vector2i, to: Vector2i) -> void:
	var mi: Node3D = boxes[from]
	boxes.erase(from)
	boxes[to] = mi
	var y := mi.position.y
	create_tween().tween_property(mi, "position", world_pos(to, y), ActorView.STEP_TIME)

func rebuild_tile(s: GridState, p: Vector2i) -> void:
	for d in [floors, objects]:
		if d.has(p):
			d[p].queue_free()
			d.erase(p)
	_place(s, p)

func _place(s: GridState, p: Vector2i) -> void:
	var t: int = s.tiles[p.y][p.x]
	if t >= 8:
		objects[p] = _block(p, t)
	var mi := MeshInstance3D.new()
	var m := PlaneMesh.new()
	m.size = Vector2(TILE, TILE)
	mi.mesh = m
	var mat: StandardMaterial3D
	match art:
		"B":
			mat = StandardMaterial3D.new()
			mat.albedo_texture = load("res://assets/new/tex_floor.png")
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		"A": mat = toon(Color(0.08, 0.08, 0.1))
		_: mat = StandardMaterial3D.new()
	mat.next_pass = null
	mi.position = world_pos(p)
	floors[p] = mi
	mi.material_override = mat
	add_child(mi)

func _block(p: Vector2i, t: int) -> Node3D:
	var props := LevelData.tile_props(t)
	var wall := int(props.blocks_light) == 1 and int(props.movable) == 0
	if art == "B" and not wall:
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
	if wall and art == "B":
		mat = _pixel_tex("res://assets/new/tex_wall.png")
	elif art == "A":
		mat = toon(Color(0.36, 0.34, 0.3))
	var m := BoxMesh.new()
	m.size = Vector3(TILE, h, TILE)
	mi.mesh = m
	mi.position = world_pos(p, h / 2.0)
	mi.material_override = mat
	add_child(mi)
	return mi

func _block_b(p: Vector2i, t: int, props: Dictionary) -> Node3D:
	var name: String = ART_PROPS[t % ART_PROPS.size()]
	if int(props.movable) == 1:
		name = ART_BOX
	elif t in FENCE_TILES:
		name = ART_FENCE
	elif int(props.dim_light) == 1:
		name = ART_DIM[t % ART_DIM.size()]
	var s := sprite(name)
	s.position = world_pos(p)
	add_child(s)
	return s

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
