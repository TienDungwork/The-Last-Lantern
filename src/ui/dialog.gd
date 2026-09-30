class_name DialogBox
extends PanelContainer
## Hộp thoại dưới màn hình: chân dung trái trong khung, chữ phải hiện dần.
## Bấm interact khi chữ đang chạy: hiện hết; bấm lần nữa: đóng (phát `closed`).

signal closed

const CHARS_PER_SEC := 60.0
const FRAME := Color(0.72, 0.53, 0.28)

var _portrait_box: PanelContainer
var _portrait: TextureRect
var _label: Label
var _more: Polygon2D
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -200
	offset_left = 80
	offset_right = -80
	offset_bottom = -24
	add_theme_stylebox_override("panel", Hud.frame_style(28))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	add_child(box)
	_portrait_box = PanelContainer.new()
	_portrait_box.add_theme_stylebox_override("panel", Hud.plate_style(Color.WHITE, 8))
	box.add_child(_portrait_box)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_box.add_child(_portrait)
	_label = Hud.outlined(Label.new(), 27)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_label.add_theme_constant_override("line_spacing", 6)
	box.add_child(_label)
	_more = Polygon2D.new()   # tam giác "bấm để tiếp"
	_more.polygon = PackedVector2Array([Vector2(0, 0), Vector2(18, 0), Vector2(9, 11)])
	_more.color = FRAME.lightened(0.3)
	add_child(_more)
	hide()

func show_line(text_id: int, portrait: int, lang: String, args: Array = []) -> void:
	portrait = LevelData.portrait(text_id, portrait)
	_label.text = LevelData.text(text_id, lang)
	for i in args.size():   # "%1" trong chuỗi gốc: số = id chuỗi (tên món), String = chèn nguyên văn (bảng thống kê)
		var v = args[i] if args[i] is String else LevelData.text(int(args[i]), lang)
		_label.text = _label.text.replace("%%%d" % (i + 1), v)
	_portrait_box.visible = portrait >= 0
	if portrait >= 0:
		_portrait.texture = Portraits.texture(portrait)
	_label.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, _label.text.length() / CHARS_PER_SEC)
	show()

func _process(_delta: float) -> void:
	_more.position = size - Vector2(40, 30)
	_more.visible = visible and _label.visible_ratio >= 1.0 and Time.get_ticks_msec() % 800 < 500

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not ev.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _label.visible_ratio < 1.0:
		_tween.kill()
		_label.visible_ratio = 1.0
		return
	hide()
	closed.emit()
