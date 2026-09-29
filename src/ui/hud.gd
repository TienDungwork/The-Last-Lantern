class_name Hud
extends VBoxContainer
## Thanh trạng thái góc trên trái theo bản gốc (method_155): năng lượng (tim + chấm), bóng đèn, ô trang bị, túi.
## Icon lấy từ khung hình gốc, phóng nguyên lần cho sắc nét. F3 bật/tắt dòng số liệu debug.

const ICON_SCALE := 3
const FRAME_HEART := 294
const FRAME_PIP_FULL := 300
const FRAME_PIP_EMPTY := 301
const FRAME_BULB := 295
const FRAME_SLOT := 292
const FRAME_BAG := 296
const BORDER := Color(0.55, 0.4, 0.22)
const GOLD := Color(1.0, 0.82, 0.35)

var highlight := -1   # op 27 mode 2: chỉ số nhóm 0 bóng đèn, 1 năng lượng, 2 ô trang bị, 3 túi (field_244..259)
var _groups: Array[PanelContainer] = []   # theo chỉ số trên
var _pips: HBoxContainer
var _bulbs: Label
var _slot_icon: TextureRect
var _debug: Label
var _last_energy := -1

static func panel_style(border: Color = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.035, 0.82)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	return sb

static func icon(frame: int, scale: int = ICON_SCALE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Portraits.texture(frame)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = t.texture.get_size() * scale
	return t

static func outlined(l: Label, size: int) -> Label:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l

func _ready() -> void:
	position = Vector2(16, 12)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style())
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for i in 4:
		var g := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.border_color = Color.TRANSPARENT
		sb.set_border_width_all(3)
		sb.set_content_margin_all(4)
		g.add_theme_stylebox_override("panel", sb)
		var inner := HBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		g.add_child(inner)
		_groups.append(g)
	# Thứ tự hiển thị như bản gốc: năng lượng, bóng đèn, ô trang bị, túi.
	for i in [1, 0, 2, 3]:
		row.add_child(_groups[i])
	var energy := _groups[1].get_child(0)
	energy.add_child(icon(FRAME_HEART))
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 3)
	energy.add_child(_pips)
	var bulbs := _groups[0].get_child(0)
	bulbs.add_child(icon(FRAME_BULB))
	_bulbs = outlined(Label.new(), 24)
	bulbs.add_child(_bulbs)
	var slot := icon(FRAME_SLOT)
	_slot_icon = TextureRect.new()
	_slot_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_slot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	slot.add_child(_slot_icon)
	_groups[2].get_child(0).add_child(slot)
	var bag := _groups[3].get_child(0)
	bag.add_child(icon(FRAME_BAG))
	bag.add_child(outlined(Label.new(), 16))
	bag.get_child(1).text = "Tab"
	bag.get_child(1).modulate = Color(1, 1, 1, 0.6)
	_debug = outlined(Label.new(), 16)
	_debug.visible = false
	add_child(_debug)

func _process(_delta: float) -> void:
	var on := Time.get_ticks_msec() % 500 <= 300   # bản gốc: sáng 300 / 500 ms
	for i in _groups.size():
		var sb := _groups[i].get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = GOLD if i == highlight and on else Color.TRANSPARENT

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F3:
		_debug.visible = not _debug.visible

func show_state(s: GridState, light_level: int) -> void:
	if _pips.get_child_count() != s.max_energy:
		for c in _pips.get_children():
			c.free()
		for i in s.max_energy:
			_pips.add_child(icon(FRAME_PIP_FULL))
	for i in s.max_energy:
		(_pips.get_child(i) as TextureRect).texture = Portraits.texture(
			FRAME_PIP_FULL if i < s.energy else FRAME_PIP_EMPTY)
	if _last_energy > s.energy:   # mất máu: chớp đỏ
		_pips.modulate = Color(2.5, 0.4, 0.4)
		create_tween().tween_property(_pips, "modulate", Color.WHITE, 0.4)
	_last_energy = s.energy
	_bulbs.text = "× %d" % s.bulbs
	var eq := s.world.equipped
	_slot_icon.texture = Portraits.texture(int(LevelData.item(eq).frame)) if eq >= 0 else null
	_debug.text = "Ô (%d,%d)   Sáng %d   Túi %s   Trang bị %s" % [
		s.player.x, s.player.y, light_level, str(s.inventory),
		LevelData.text(int(LevelData.item(eq).name_id)) if eq >= 0 else "-"]
