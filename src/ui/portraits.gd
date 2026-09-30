class_name Portraits
extends RefCounted
## Tra khung hình -> AtlasTexture. Dùng cho chân dung hội thoại và sprite tạm.
## Ảnh lấy từ atlas vẽ lại image/img (gấp SCALE lần gốc, cùng bố cục); thiếu file thì phóng ảnh gốc.

const SCALE := 4   # atlas mới = gốc x SCALE; rect/anchor trong frames.json vẫn theo pixel gốc

static var _frames: Array = []
static var _images: Dictionary = {}
static var _sheets: Dictionary = {}
static var _cache: Dictionary = {}

static func frame(id: int) -> Dictionary:
	if _frames.is_empty():
		_frames = LevelData.read_json("res://data/frames.json")
	var f: Array = _frames[id]
	# anchor: class_7.method_55 vẽ frame tại (x, y) - anchor
	return {"png": f[0], "rect": Rect2(int(f[1]), int(f[2]), int(f[3]), int(f[4])), "anchor": Vector2(int(f[5]), int(f[6]))}

## Atlas cỡ SCALE (image/img/<png>), không có thì ảnh gốc phóng SCALE lần.
static func image(png: String) -> Image:
	if not _images.has(png):
		# load() thay vì Image.load_from_file: bản export chỉ có .ctex đã import, không có file png gốc.
		var hd := "res://image/img/" + png
		var img: Image
		if ResourceLoader.exists(hd):
			img = load(hd).get_image()
		else:
			img = load("res://assets/original/" + png).get_image()
			img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_images[png] = img
	return _images[png]

## Texture cỡ SCALE (rộng = rect.size.x * SCALE).
static func texture(id: int) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var f := frame(id)
	if not _sheets.has(f.png):
		_sheets[f.png] = ImageTexture.create_from_image(image(f.png))
	var at := AtlasTexture.new()
	at.atlas = _sheets[f.png]
	at.region = Rect2(f.rect.position * SCALE, f.rect.size * SCALE)
	_cache[id] = at
	return at
