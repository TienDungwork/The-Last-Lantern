class_name Hud
extends VBoxContainer
## Thanh trạng thái góc trên trái theo bản gốc (method_155): máu (tim + thanh), bóng đèn, ô trang bị, túi.
## Icon lấy từ khung hình gốc, phóng nguyên lần cho sắc nét. F3 bật/tắt dòng số liệu debug.

const ICON_SCALE := 3
const FRAME_HEART := 294
const HP_RED := Color(0.78, 0.12, 0.1)
const FRAME_BULB := 295
const FRAME_SLOT := 292
const FRAME_BAG := 296
const BORDER := Color(0.55, 0.4, 0.22)
const GOLD := Color(1.0, 0.82, 0.35)

var highlight := -1   # op 27 mode 2: chỉ số nhóm 0 bóng đèn, 1 năng lượng, 2 ô trang bị, 3 túi (field_244..259)
var _groups: Array[PanelContainer] = []   # theo chỉ số trên
var _hp: ProgressBar
var _bulbs: Label
var _slot_icon: TextureRect
var _debug: Label
var _last_energy := -1
var _skill_bar: HBoxContainer      # ô chiêu chủ động giữa đáy màn hình
var _skill_slots: Array = []       # [panel, icon, lớp hồi chiêu, số giây]
var _skill_hero := ""
var _toast: Label

## Icon kỹ năng: bảng 3x3 gen sẵn mỗi nhân vật (assets/skills/<hero>.jpg), ô theo thứ tự dưới.
const SKILL_ICONS := {
	"daniel": ["kindle", "bandage", "fire_wall", "twin_lamp", "lamp_keeper", "max_hp", "quick_hands", "thick_skin", "shadow_hunter"],
	"clara": ["swallow_light", "call_shadow", "one_of_them", "max_hp", "regen", "hood", "fast_wake", "night_eye", "bracelet"],
}
const SKILL_SLOT := 72
static var _skill_sheets: Dictionary = {}

static func skill_icon(hero: String, name: String) -> Texture2D:
	var i: int = SKILL_ICONS[hero].find(name)
	if i < 0:
		return null
	if not _skill_sheets.has(hero):
		_skill_sheets[hero] = load("res://assets/skills/%s.jpg" % hero)
	var sheet: Texture2D = _skill_sheets[hero]
	var cell := sheet.get_width() / 3.0
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((i % 3) * cell + 10, (i / 3) * cell + 10, cell - 20, cell - 20)   # bỏ khe đen giữa các ô
	return at

## Bộ giao diện chung (assets/ui): khung sắt lớn cho cửa sổ/hộp thoại, tấm sắt nhỏ cho nút/ô/thanh HUD.
static var title_font: Font = load("res://assets/fonts/EBGaramond.ttf")
const TINT_SELECTED := Color(1.45, 1.1, 0.7)   # tấm sắt ửng vàng: đang chọn / đang dùng
const TINT_MAXED := Color(0.8, 1.3, 0.75)
const TINT_DIM := Color(0.55, 0.55, 0.55)

static func _nine(path: String, margin: int, pad: int, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(pad)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = tint
	return sb

static func frame_style(pad: int = 30) -> StyleBoxTexture:
	return _nine("res://assets/ui/frame.png", 48, pad, Color.WHITE)

static func plate_style(tint: Color = Color.WHITE, pad: int = 10) -> StyleBoxTexture:
	return _nine("res://assets/ui/plate.png", 14, pad, tint)

## Viền vàng vẽ đè khi có focus (nút giữ nền tấm sắt bên dưới).
static func focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(2)
	return sb

static func title(text: String, size: int) -> Label:
	var l := outlined(Label.new(), size)
	l.text = text
	l.add_theme_font_override("font", title_font)
	l.add_theme_color_override("font_color", Color(1, 0.82, 0.45))
	return l

static func panel_style(_border: Color = BORDER) -> StyleBox:
	return plate_style(Color(0.8, 0.8, 0.8), 10)

static func icon(frame: int, scale: int = ICON_SCALE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Portraits.texture(frame)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # texture gấp Portraits.SCALE, hiện nhỏ hơn: NEAREST sẽ rụng pixel
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Portraits.frame(frame).rect.size * scale
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
	_hp = ProgressBar.new()
	_hp.show_percentage = false
	_hp.custom_minimum_size = Vector2(180, 22)
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.04)
	bg.border_color = BORDER
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HP_RED
	_hp.add_theme_stylebox_override("background", bg)
	_hp.add_theme_stylebox_override("fill", fill)
	energy.add_child(_hp)
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
	_skill_bar = HBoxContainer.new()
	_skill_bar.top_level = true   # không theo bố cục góc trên trái, nhưng ẩn/hiện cùng HUD
	_skill_bar.add_theme_constant_override("separation", 10)
	add_child(_skill_bar)
	_toast = outlined(Label.new(), 22)
	_toast.top_level = true
	_toast.modulate.a = 0.0
	add_child(_toast)

func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	create_tween().tween_property(_toast, "modulate:a", 0.0, 0.6).set_delay(1.6)

func _build_skill_bar(hero: String, names: Array) -> void:
	_skill_hero = hero
	for c in _skill_bar.get_children():
		c.queue_free()
	_skill_slots.clear()
	for k in names.size():
		var p := PanelContainer.new()
		var sb := focus_style()   # icon đã có khung sắt riêng: chỉ viền vàng khi đang băng bó
		sb.set_content_margin_all(0)
		p.add_theme_stylebox_override("panel", sb)
		var box := Control.new()
		box.custom_minimum_size = Vector2(SKILL_SLOT, SKILL_SLOT)
		p.add_child(box)
		var ic := TextureRect.new()
		ic.texture = skill_icon(hero, names[k])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(ic)
		var shade := ColorRect.new()   # phủ từ dưới lên theo phần hồi chiêu còn lại
		shade.color = Color(0, 0, 0, 0.7)
		shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		box.add_child(shade)
		var secs := outlined(Label.new(), 24)
		secs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		secs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		secs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(secs)
		var key := outlined(Label.new(), 16)
		key.text = str(k + 1)
		key.position = Vector2(4, 0)
		box.add_child(key)
		_skill_bar.add_child(p)
		_skill_slots.append([p, ic, shade, secs])

## Mỗi khung hình: hồi chiêu (lớp tối + giây), chiêu chưa mở thì ẩn ô (giữ số phím), đang băng bó thì viền vàng.
func show_skills(sk: Skills) -> void:
	var names := sk.slots()
	if _skill_hero != sk.s.world.hero or _skill_slots.size() != names.size():
		_build_skill_bar(sk.s.world.hero, names)
	for k in names.size():
		var n: String = names[k]
		var slot: Array = _skill_slots[k]
		slot[0].visible = sk.s.world.unlocked(n)
		var left := int(sk.cd.get(n, 0))
		slot[2].offset_top = -SKILL_SLOT * float(left) / sk.cooldown_max(n)
		slot[3].text = "%d" % ceili(left / 1000.0) if left > 0 else ""
		var busy := n == "bandage" and sk.bandage_ms > 0
		(slot[0].get_theme_stylebox("panel") as StyleBoxFlat).border_color = GOLD if busy else Color.TRANSPARENT
	var vp := get_viewport_rect().size
	_skill_bar.reset_size()
	_skill_bar.position = Vector2((vp.x - _skill_bar.size.x) / 2, vp.y - _skill_bar.size.y - 16)
	_toast.reset_size()
	_toast.position = Vector2((vp.x - _toast.size.x) / 2, _skill_bar.position.y - _toast.size.y - 8)

func _process(_delta: float) -> void:
	var on := Time.get_ticks_msec() % 500 <= 300   # bản gốc: sáng 300 / 500 ms
	for i in _groups.size():
		var sb := _groups[i].get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = GOLD if i == highlight and on else Color.TRANSPARENT

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F3:
		_debug.visible = not _debug.visible

func show_state(s: GridState, light_level: int) -> void:
	_hp.max_value = s.max_energy
	_hp.value = s.energy
	if _last_energy > s.energy:   # mất máu: chớp đỏ
		_hp.modulate = Color(2.5, 0.4, 0.4)
		create_tween().tween_property(_hp, "modulate", Color.WHITE, 0.4)
	_last_energy = s.energy
	_bulbs.text = "× %d" % s.bulbs
	var eq := s.world.equipped
	_slot_icon.texture = Portraits.texture(int(LevelData.item(eq).frame)) if eq >= 0 else null
	_debug.text = "Ô (%d,%d)   Sáng %d   Túi %s   Trang bị %s" % [
		s.player.x, s.player.y, light_level, str(s.inventory),
		LevelData.text(int(LevelData.item(eq).name_id)) if eq >= 0 else "-"]
