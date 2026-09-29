class_name LevelData
extends RefCounted
## Dữ liệu tĩnh của một màn (data/levels/NN.json) và các bảng dùng chung.
## Không đổi trong lúc chơi; trạng thái động nằm ở GridState.

var index: int
var width: int
var height: int
var tileset: int
var name_id: int
var start: Vector2i
var grid: Array = []      # grid[y][x] -> int; <8 = sàn, >=8 = vật thể (khung hình = giá trị - 8)
var lights: Array = []    # Dictionary {x, y, type, on, radius, dir}
var events: Array = []    # Dictionary {id, x, y, w, h, flags, commands: [{op, args, text}]}

static var _tiles: Dictionary = {}
static var _strings: Dictionary = {}   # lang -> Array[String]

static func read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "không mở được " + path)
	var v: Variant = JSON.parse_string(f.get_as_text())
	assert(v != null, "JSON hỏng: " + path)
	return v

static func load_level(n: int) -> LevelData:
	var d: Dictionary = read_json("res://data/levels/%02d.json" % n)
	var L := LevelData.new()
	L.index = n
	L.width = int(d.width)
	L.height = int(d.height)
	L.tileset = int(d.tileset)
	L.name_id = int(d.name_id)
	L.start = Vector2i(int(d.start[0]), int(d.start[1]))
	for row in d.grid:
		var r := PackedInt32Array()
		for t in row:
			r.append(int(t))
		L.grid.append(r)
	L.lights = d.lights
	L.events = d.events
	return L

static func tile_props(tile: int) -> Dictionary:
	if _tiles.is_empty():
		_tiles = read_json("res://data/tiles.json")
	return _tiles.get(str(tile), {"solid": 0, "blocks_light": 0, "dim_light": 0, "movable": 0})

static func text(id: int, lang: String = "vi") -> String:
	if not _strings.has(lang):
		_strings[lang] = read_json("res://data/strings_%s.json" % lang)
	return _strings[lang][id]
