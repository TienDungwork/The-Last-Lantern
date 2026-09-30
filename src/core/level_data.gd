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
static var _items: Dictionary = {}
static var _floor_frames: Array = []
static var hero := "daniel"            # tuyến đang chơi; "clara" thì text() áp data_enhanced/strings_<lang>_clara.json
static var _clara: Dictionary = {}     # lang -> {chỉ số: câu | {text, portrait}}

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

static func item(id: int) -> Dictionary:
	## {name_id, frame} của món đồ (field_269/270).
	if _items.is_empty():
		_items = read_json("res://data/items.json")
	return _items[str(id)]

static func floor_frames() -> Array:
	## field_198: bộ tile -> frame sàn theo mức sáng 0..7.
	if _floor_frames.is_empty():
		_floor_frames = read_json("res://data/floor_frames.json")
	return _floor_frames

static func text(id: int, lang: String = "vi") -> String:
	var o = _override(id, lang)
	if o != null:
		return o.text if o is Dictionary else o
	if not _strings.has(lang):
		_strings[lang] = read_json("res://data/strings_%s.json" % lang)
	return _strings[lang][id]

## Chân dung câu thoại: tuyến Clara hoán đổi khung 171 (Daniel) ↔ 179 (Clara), trừ câu ghi đè có kèm "portrait".
static func portrait(text_id: int, frame: int) -> int:
	if hero != "clara":
		return frame
	var o = _override(text_id, "vi")
	if o is Dictionary and o.has("portrait"):
		return int(o.portrait)
	return {171: 179, 179: 171}.get(frame, frame)

static func _override(id: int, lang: String) -> Variant:
	if hero != "clara":
		return null
	if not _clara.has(lang):
		_clara[lang] = read_json("res://data_enhanced/strings_%s_clara.json" % lang)
	return _clara[lang].get(str(id))
