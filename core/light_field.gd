class_name LightField
extends RefCounted
## Độ sáng từng ô 0..7, chuyển nguyên thuật toán từ class_10.method_151/152 (game gốc).
## Tọa độ "nửa ô": ô (x,y) chiếm nửa ô 2x..2x+1. Mỗi ô sàn nhận 4 tia từ 4 góc đèn tới 4 góc ô.

const CORNERS := [0, 0, 0, 0,  1, 0, 1, 0,  1, 1, 1, 1,  0, 1, 0, 1]        # field_224 (đèn tỏa)
const CORNERS_DIR := [0, 0, 1, 1,  1, 0, 0, 1,  1, 1, 0, 0,  0, 1, 1, 0]    # field_225 (đèn có hướng)
const BLOCKED := 100
const DIMMED := 40
const MAX_LEVEL := 7

static func compute(s: GridState) -> Array:
	## Trả về map[y][x]; ô vật thể = 0.
	var w := s.level.width
	var h := s.level.height
	var sum: Array = []
	for y in h:
		var row := PackedInt32Array()
		row.resize(w)
		sum.append(row)
	for L in s.lights:
		if int(L.on) == 0 or int(L.radius) <= 0:
			continue
		var lx := int(L.x)
		var ly := int(L.y)
		var r := int(L.radius)
		var dir := int(L.dir)
		var type := int(L.type)
		var corners: Array = CORNERS_DIR if dir != 0 else CORNERS
		for y in range(maxi(ly - r + 1, 0), mini(ly + r, h)):
			for x in range(maxi(lx - r + 1, 0), mini(lx + r, w)):
				if s.tiles[y][x] >= 8:
					continue
				var acc := 0
				for k in range(0, 16, 4):
					var d := _ray(s, (x << 1) + corners[k], (y << 1) + corners[k + 1],
						(lx << 1) + corners[k + 2], (ly << 1) + corners[k + 3], dir, r << 1, type, lx, ly)
					if d < (r << 1):
						acc += r - (d >> 1)
				sum[y][x] += mini(acc >> 2, MAX_LEVEL)
	for y in h:
		for x in w:
			sum[y][x] = mini(sum[y][x], MAX_LEVEL)
	return sum

@warning_ignore("integer_division")
static func _ray(s: GridState, tx: int, ty: int, lx: int, ly: int, dir: int, rng: int, type: int,
		light_tile_x: int, light_tile_y: int) -> int:
	## method_152: (tx,ty) góc ô đích, (lx,ly) góc đèn, cả hai ở tọa độ nửa ô. rng = radius*2.
	var dx := absi(tx - lx)
	var dy := absi(ty - ly)
	if dx > rng or dy > rng:
		return BLOCKED
	var spread := 2 if (type == 1 or type == 5) else 0
	var sx := signi(tx - lx)
	var sy := signi(ty - ly)
	match dir:
		1:
			if sy == -1 or spread * dx > dy:
				return BLOCKED
		2:
			if sx == -1 or spread * dy > dx:
				return BLOCKED
		3:
			if sy == 1 or spread * dx > dy:
				return BLOCKED
		4:
			if sx == 1 or spread * dy > dx:
				return BLOCKED
	var n := maxi(dx, dy)
	for i in n:
		var px: int
		var py: int
		if dx > dy:
			px = lx + i * sx
			py = ly + ((i * ((dy << 6) / dx)) >> 6) * sy
		elif dx < dy:
			px = lx + ((i * ((dx << 6) / dy)) >> 6) * sx
			py = ly + i * sy
		else:
			px = lx + i * sx
			py = ly + i * sy
		var cx := px >> 1
		var cy := py >> 1
		if i == 0 or (i == 1 and cx == light_tile_x and cy == light_tile_y):
			continue   # bỏ ô của chính đèn (đèn treo trên vật thể)
		var t := s.tile_at(Vector2i(cx, cy))
		if t < 8:
			continue
		var p := LevelData.tile_props(t)
		if int(p.blocks_light) == 1:
			return BLOCKED
		if int(p.dim_light) == 1 and absi(px - tx) <= 1 and absi(py - ty) <= 1:
			return DIMMED
	# ponytail: bản gốc còn xét diễn viên/hộp đang mang (method_117) trên đường tia; M2 thêm khi có actor.
	return dx + dy * 40 / 100 if dx > dy else dy + dx * 40 / 100
