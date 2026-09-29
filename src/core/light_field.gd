class_name LightField
extends RefCounted
## Độ sáng từng ô 0..7, chuyển nguyên thuật toán từ class_10.method_151/152 (game gốc).
## Tọa độ "nửa ô": ô (x,y) chiếm nửa ô 2x..2x+1. Mỗi ô sàn nhận 4 tia từ 4 góc đèn tới 4 góc ô.
## Bản gốc đặt HÀNG trước CỘT (field_228[0] = y, [1] = x); _ray giữ đúng thứ tự đó để so dòng-với-dòng.
## dir của đèn trùng mã hướng đi: 1 phải, 2 xuống, 3 trái, 4 lên.

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
		var c: Array = CORNERS_DIR if dir != 0 else CORNERS
		for y in range(maxi(ly - r + 1, 0), mini(ly + r, h)):
			for x in range(maxi(lx - r + 1, 0), mini(lx + r, w)):
				if s.tiles[y][x] >= 8:
					continue
				var acc := 0
				for k in range(0, 16, 4):
					var d := _ray(s, (y << 1) + c[k], (x << 1) + c[k + 1], (ly << 1) + c[k + 2], (lx << 1) + c[k + 3],
						dir, r << 1, int(L.type), ly, lx)
					if d < (r << 1):
						acc += r - (d >> 1)
				sum[y][x] += mini(acc >> 2, MAX_LEVEL)
	for y in h:
		for x in w:
			sum[y][x] = mini(sum[y][x], MAX_LEVEL)
	return sum

@warning_ignore("integer_division")
static func _ray(s: GridState, ty: int, tx: int, ly: int, lx: int, dir: int, rng: int, type: int,
		light_row: int, light_col: int) -> int:
	## method_152(var0=ty, var1=tx, var2=ly, var3=lx, var4=dir, var5=rng, var6=type), nửa ô.
	var dy := absi(ty - ly)
	var dx := absi(tx - lx)
	if dy > rng or dx > rng:
		return BLOCKED
	var spread := 2 if (type == 1 or type == 5) else 0
	var sy := signi(ty - ly)
	var sx := signi(tx - lx)
	match dir:
		1:
			if sx == -1 or spread * dy > dx:
				return BLOCKED
		2:
			if sy == -1 or spread * dx > dy:
				return BLOCKED
		3:
			if sx == 1 or spread * dy > dx:
				return BLOCKED
		4:
			if sy == 1 or spread * dx > dy:
				return BLOCKED
	var n := maxi(dy, dx)
	for i in n:
		var py: int
		var px: int
		if dy > dx:
			py = ly + i * sy
			px = lx + ((i * ((dx << 6) / dy)) >> 6) * sx
		elif dy < dx:
			py = ly + ((i * ((dy << 6) / dx)) >> 6) * sy
			px = lx + i * sx
		else:
			py = ly + i * sy
			px = lx + i * sx
		var row := py >> 1
		var col := px >> 1
		if i == 0 or (i == 1 and row == light_row and col == light_col):
			continue   # bỏ ô của chính đèn (đèn treo trên vật thể)
		var t := s.tile_at(Vector2i(col, row))
		if t < 8:
			t = s.boxes.get(Vector2i(col, row), 0)
		if t < 8:
			continue
		var p := LevelData.tile_props(t)
		if int(p.blocks_light) == 1:
			return BLOCKED
		if int(p.dim_light) == 1 and absi(py - ty) <= 1 and absi(px - tx) <= 1:
			return DIMMED
	return dy + dx * 40 / 100 if dy > dx else dx + dy * 40 / 100
