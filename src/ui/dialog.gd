class_name DialogBox
extends PanelContainer
## Hộp thoại dưới màn hình: chân dung trái, chữ phải. show_line() rồi chờ người chơi bấm interact.

signal closed

var _portrait: TextureRect
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -220
	offset_left = 40
	offset_right = -40
	offset_bottom = -30
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(160, 160)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_portrait)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 26)
	box.add_child(_label)
	hide()

func show_line(text_id: int, portrait: int, lang: String) -> void:
	_label.text = LevelData.text(text_id, lang)
	_portrait.visible = portrait >= 0
	if portrait >= 0:
		_portrait.texture = Portraits.texture(portrait)
	show()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev.is_action_pressed("interact"):
		hide()
		get_viewport().set_input_as_handled()
		closed.emit()
