class_name LevelBuilder
extends Node3D
## Dựng lưới 3D từ GridState: một node sàn mỗi ô sàn, một khối mỗi ô vật thể.
## rebuild_tile() dùng khi SET_TILE. lighting.gd tô màu sàn qua `floors`.

const TILE := 1.0
var floors: Dictionary = {}   # Vector2i -> MeshInstance3D
var objects: Dictionary = {}  # Vector2i -> MeshInstance3D

static func world_pos(p: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(p.x * TILE, y, p.y * TILE)

func build(s: GridState) -> void:
	for c in get_children():
		c.queue_free()
	floors.clear()
	objects.clear()
	for y in s.level.height:
		for x in s.level.width:
			_place(s, Vector2i(x, y))

func rebuild_tile(s: GridState, p: Vector2i) -> void:
	for d in [floors, objects]:
		if d.has(p):
			d[p].queue_free()
			d.erase(p)
	_place(s, p)

func _place(s: GridState, p: Vector2i) -> void:
	var t: int = s.tiles[p.y][p.x]
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if t < 8:
		var m := PlaneMesh.new()
		m.size = Vector2(TILE, TILE)
		mi.mesh = m
		mat.albedo_color = Color(0.08, 0.08, 0.1)
		mi.position = world_pos(p)
		floors[p] = mi
	else:
		var props := LevelData.tile_props(t)
		var h := 1.0 if int(props.blocks_light) == 1 else 0.5
		if int(props.movable) == 1:
			h = 0.8
			mat.albedo_color = Color(0.45, 0.3, 0.15)
		elif int(props.blocks_light) == 1:
			mat.albedo_color = Color(0.35, 0.33, 0.3)
		else:
			mat.albedo_color = Color(0.5, 0.45, 0.4)
		var m := BoxMesh.new()
		m.size = Vector3(TILE, h, TILE)
		mi.mesh = m
		mi.position = world_pos(p, h / 2.0)
		objects[p] = mi
	mi.material_override = mat
	add_child(mi)
