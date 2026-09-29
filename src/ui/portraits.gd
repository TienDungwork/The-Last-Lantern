class_name Portraits
extends RefCounted
## Tra khung hình gốc -> AtlasTexture. Dùng cho chân dung hội thoại và sprite tạm.

static var _frames: Array = []
static var _sheets: Dictionary = {}
static var _cache: Dictionary = {}

static func frame(id: int) -> Dictionary:
	if _frames.is_empty():
		_frames = LevelData.read_json("res://data/frames.json")
	var f: Array = _frames[id]
	return {"png": f[0], "rect": Rect2(int(f[1]), int(f[2]), int(f[3]), int(f[4]))}

static func texture(id: int) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var f := frame(id)
	if not _sheets.has(f.png):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/original/" + f.png))
		_sheets[f.png] = ImageTexture.create_from_image(img)
	var at := AtlasTexture.new()
	at.atlas = _sheets[f.png]
	at.region = f.rect
	_cache[id] = at
	return at
