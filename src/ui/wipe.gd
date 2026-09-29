class_name Wipe
extends Control
## SPECIAL 7 (method_185/187/184): lưới 7x7 ô đen nở từ tâm mỗi ô, lan chéo từ góc trên trái.
## Mỗi tick 20 ms ô đang lan to thêm 1/16; mỗi 8 tick mặt lan tiến một đường chéo (tối đa 12).

const TICK_MS := 20
const END_TICKS := 8 * 12 + 15   # ô góc dưới phải (chéo 12) vừa kín thì xong
const TIME := END_TICKS * TICK_MS / 1000.0

var _ms := 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()

## Độ lớn ô trên đường chéo d (= i + j) sau `ticks` tick, 0..16.
static func cell(ticks: int, d: int) -> int:
	return clampi(ticks - maxi(8 * d, 1) + 1, 0, 16)

func start() -> void:
	_ms = 0.0
	show()
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		_ms += delta * 1000.0
		queue_redraw()

func _draw() -> void:
	var ticks := int(_ms / TICK_MS)
	var c := size / 7.0
	for i in 7:
		for j in 7:
			var k := cell(ticks, i + j) / 16.0
			draw_rect(Rect2(Vector2(i, j) * c + c * (1.0 - k) / 2.0, c * k), Color.BLACK)
