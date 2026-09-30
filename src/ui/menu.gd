class_name Menu
extends Control
## Mọi trang menu trên một lớp phủ: tiêu đề, tạm dừng, cài đặt, túi đồ, hỏi lại khi thoát.
## Bàn phím: mũi tên + Enter (focus của Godot), Esc = quay lại. Game đứng yên khi menu mở (game.gd kiểm tra visible).

signal new_game(hero: String)
signal continue_game
signal quit_to_title

const SETTINGS_PATH := "user://settings.cfg"
const FRAME := Color(0.72, 0.53, 0.28)
const LANGS := {"vi": "Tiếng Việt", "en": "English"}
const MAP_ITEM := 3
const MAP_CELL := 12   # px mỗi ô bản đồ (bản gốc 4)
const MAP_COLORS := [Color8(0xE7, 0xE6, 0xCF), Color8(0xB7, 0xB8, 0xB7), Color8(0x82, 0x80, 0x59)]   # method_176
const MAP_LEGEND := [379, 381, 382, 377, 380, 378, 383]   # method_174, cùng thứ tự câu 129..135
const MAXED := Color(0.45, 0.85, 0.4)     # trang Kỹ năng: đã tối đa
const WINDOW := Vector2(900, 500)          # cửa sổ Túi đồ / Kỹ năng cố định, vừa 1024x576
const INV_SLOTS := 18                      # 6 x 3 ô
const DETAIL_W := 298                      # bề rộng chữ trong khung chi tiết
## Trang Kỹ năng: tên (khóa trong World.UPGRADES / UNLOCKS) -> [tên hiện, tóm tắt, [mô tả từng cấp]].
## Chiêu không có cấp (Bức tường lửa, Đèn đôi, Một trong số họ) chỉ hiện thông tin.
const UPGRADE_TEXT := {
	"kindle": ["Mồi lửa", "Thắp lại đèn tắt hoặc nến tàn ở ô kề. Hồi chiêu 8 s.",
		["Đèn vừa thắp sáng rộng thêm 1 ô trong 10 s", "Hồi chiêu 8 → 6 s"]],
	"bandage": ["Băng bó", "Đứng yên 3 s ở chỗ đủ sáng để hồi 10 máu. Hồi chiêu 20 s.", ["Hồi 15 máu", "Hồi 25 máu"]],
	"fire_wall": ["Bức tường lửa", "Ném chai dầu thành vệt lửa 3 ô trong 8 s. Tu sĩ quay đầu, Boss 2 mất máu như trúng một cây đèn. Hồi chiêu 50 s.", []],
	"twin_lamp": ["Đèn đôi", "Mang 2 đèn cùng sáng. Phím 4 đổi đèn cầm tay với đèn đeo lưng.", []],
	"lamp_keeper": ["Người giữ đèn", "Nến cầm theo cháy lâu hơn.", ["Lâu gấp rưỡi", "Lâu gấp đôi"]],
	"max_hp": ["Máu tối đa", "Máu tối đa 100. Tăng bao nhiêu hồi bấy nhiêu.", ["110 máu", "125 máu"]],
	"quick_hands": ["Tay quen", "Chiêu 1, 2, 3 hồi nhanh hơn.", ["Nhanh hơn 10%", "Nhanh hơn 25%"]],
	"thick_skin": ["Da dày", "Mất máu trong bóng tối ít hơn (gốc: tối hẳn 10, mờ 4 máu/s).",
		["Tối hẳn 9, mờ 3 máu/s", "Tối hẳn 8, mờ 2 máu/s"]],
	"shadow_hunter": ["Thợ săn bóng", "Quái bóng tối chết nhanh hơn trong sáng (gốc 2 s).", ["Chết sau 1,75 s", "Chết sau 1,5 s"]],
	"swallow_light": ["Nuốt sáng", "Tắt một nguồn sáng trong 3 ô trong 8 s. Hồi chiêu 10 s.", ["Hiệu lực 12 s", "Tầm 5 ô"]],
	"call_shadow": ["Gọi bóng", "Sinh vật bóng tối trong 3 ô tới ô tối chỉ định, đứng 10 s. Hồi chiêu 12 s.",
		["Tầm 5 ô, đứng 15 s", "Gọi 2 sinh vật"]],
	"one_of_them": ["Một trong số họ", "Hương áo choàng tu sĩ thôi làm Clara choáng: mặc không giới hạn thời gian.", []],
	"regen": ["Hồi phục", "Hồi máu trong vùng an toàn (gốc 2 máu/s).", ["3 máu/s", "4 máu/s"]],
	"hood": ["Mũ trùm", "Bỏng ánh sáng ít hơn (gốc 7 máu/s).", ["6 máu/s", "5 máu/s"]],
	"fast_wake": ["Tỉnh nhanh", "Thanh virus giảm nhanh hơn (gốc 20 mỗi giây).", ["25 mỗi giây", "30 mỗi giây"]],
	"night_eye": ["Mắt đêm+", "Vật phẩm phát sáng mờ để dễ tìm trong tối.", ["Trong 4 ô", "Trong 7 ô"]],
}

var has_save := false
var in_game := false          # false = đang ở màn tiêu đề
var world: World              # cho trang túi đồ
var lang := "vi"
var music_volume := 0.8
var _page: Control
var _back: Callable = Callable()
var _combine := -1            # field_287/288: món đang chờ ghép, -1 = không
var _skill_snap: Array = []   # trang Kỹ năng: [upgrades, max_energy, energy] trước khi cộng thử; rỗng = không có gì chưa lưu
var _inv_sel := -1            # món đang xem ở Túi đồ (giữ khi mở lại)
var _skill_sel := ""          # kỹ năng đang xem ở trang Kỹ năng

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	theme = _theme()
	load_settings()
	hide()

func _theme() -> Theme:
	var t := Theme.new()
	t.set_font_size("font_size", "Button", 26)
	t.set_font_size("font_size", "Label", 24)
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Label", Color.BLACK)
	t.set_color("font_color", "Button", Color(0.9, 0.85, 0.75))
	t.set_color("font_hover_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_focus_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_font("font", "Button", Hud.title_font)
	t.set_stylebox("normal", "Button", Hud.plate_style(Color.WHITE, 12))
	t.set_stylebox("hover", "Button", Hud.plate_style(Color(1.25, 1.1, 0.9), 12))
	t.set_stylebox("focus", "Button", Hud.focus_style())
	t.set_stylebox("pressed", "Button", Hud.plate_style(Hud.TINT_SELECTED, 12))
	t.set_stylebox("disabled", "Button", Hud.plate_style(Hud.TINT_DIM, 12))
	t.set_stylebox("panel", "PanelContainer", Hud.frame_style())
	return t

# --- trang ---

func open_title() -> void:
	in_game = false
	_show(_list("THE LAST LANTERN II", "Ashwood chìm trong bóng tối", [
		["Chơi tiếp", _start.bind(continue_game), not has_save],
		["Trò chơi mới", open_hero_select],
		["Cài đặt", open_settings.bind(open_title)],
		["Thoát", _confirm_quit.bind(open_title)],
	]), Callable())

func open_hero_select() -> void:
	_show(_list("CHỌN NHÂN VẬT", "Bản lưu cũ sẽ bị ghi đè." if has_save else "", [
		["Daniel — người mang đèn", _start_hero.bind("daniel")],
		["Clara — đứa trẻ của bóng tối", _start_hero.bind("clara")],
		["Quay lại", open_title],
	]), open_title)

func _start_hero(hero: String) -> void:
	_close()
	new_game.emit(hero)

func _start(sig: Signal) -> void:
	_close()
	sig.emit()

func open_pause() -> void:
	in_game = true
	_show(_list("TẠM DỪNG", "", [
		["Tiếp tục", _close],
		["Túi đồ", open_inventory.bind(open_pause)],
		["Cài đặt", open_settings.bind(open_pause)],
		["Về màn tiêu đề", func(): quit_to_title.emit()],
		["Thoát", _confirm_quit.bind(open_pause)],
	]), _close)

func open_settings(back: Callable) -> void:
	var box := _panel("CÀI ĐẶT")
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = music_volume
	vol.custom_minimum_size = Vector2(320, 32)
	vol.value_changed.connect(_set_volume)
	box.add_child(_row("Âm lượng", vol))
	var lang_btn := Button.new()
	lang_btn.text = LANGS[lang]
	lang_btn.pressed.connect(_toggle_lang.bind(lang_btn))
	box.add_child(_row("Ngôn ngữ", lang_btn))
	box.add_child(_button("Xong", back))
	_show(box.get_parent(), back)

func _set_volume(v: float) -> void:
	music_volume = v
	_apply_settings()

func _toggle_lang(btn: Button) -> void:
	lang = "en" if lang == "vi" else "vi"
	btn.text = LANGS[lang]
	_apply_settings()

## Dòng 4270: đang ghép thì món vừa chọn là món thứ hai; ghi chú = đọc; bản đồ = mở bản đồ;
## món có công thức = cầm lên và chờ chọn món ghép.
func _toggle_equip(id: int, back: Callable) -> void:
	if _combine >= 0:
		var first := _combine
		_combine = -1
		if id == first or world.combine(first, id):
			open_inventory(back)
			return
	if World.NOTE_TEXT.has(id):
		open_note(id, back)
		return
	world.equipped = -1 if world.equipped == id else id
	if world.equipped == MAP_ITEM:   # method_169: chọn bản đồ trong túi đồ -> mở màn 19 (bản đồ)
		open_map(back)
		return
	if world.equipped == id and world.can_combine(id):
		_combine = id
	open_inventory(back)

func open_note(id: int, back: Callable) -> void:
	var box := _panel(LevelData.text(int(LevelData.item(id).name_id), lang))
	var l := Label.new()
	l.text = LevelData.text(World.NOTE_TEXT[id], lang)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(680, 0)
	l.add_theme_font_size_override("font_size", 20)
	box.add_child(l)
	box.add_child(_button("Đóng", open_inventory.bind(back)))
	_show(box.get_parent(), open_inventory.bind(back))

## method_176: ô 4 px ba màu, điểm đánh dấu (op 4/5) vẽ đè, cửa khóa (377) vẽ sau cùng. Enter = chú giải (method_174).
func open_map(back: Callable, legend := false) -> void:
	var box := _panel(LevelData.text(181, lang))
	var cells := world.map_cells()
	var img := Image.create(cells[0].size(), cells.size(), false, Image.FORMAT_RGB8)
	for y in cells.size():
		for x in cells[y].size():
			img.set_pixel(x, y, MAP_COLORS[cells[y][x]])
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(img)
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.custom_minimum_size = img.get_size() * MAP_CELL
	var markers: Array = LevelData.read_json("res://data/map_markers.json")
	var ids: Array = world.map_markers.keys().filter(func(i): return i < markers.size())
	ids.sort_custom(func(a, b): return int(markers[a].icon_frame != 377) > int(markers[b].icon_frame != 377))
	for i in ids:
		var m: Dictionary = markers[i]
		var ic := Hud.icon(int(m.icon_frame), MAP_CELL / 4)
		map.add_child(ic)
		ic.position = (Vector2(int(m.x), int(m.y)) + Vector2(0.5, 0.5)) * MAP_CELL - ic.custom_minimum_size / 2
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.add_child(map)
	box.add_child(body)
	if legend:
		var keys := VBoxContainer.new()
		keys.alignment = BoxContainer.ALIGNMENT_CENTER
		for k in MAP_LEGEND.size():
			keys.add_child(_row_icon(MAP_LEGEND[k], LevelData.text(129 + k, lang)))
		body.add_child(keys)
	box.add_child(_button("Ẩn chú giải" if legend else "Chú giải", open_map.bind(back, not legend)))
	box.add_child(_button("Đóng", back))
	_show(box.get_parent(), back)

func _row_icon(frame: int, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(Hud.icon(frame, 3))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	return row

func open_inventory(back: Callable) -> void:
	var w := _window(false, back)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	w[1].add_child(grid)
	var focus: Button = null
	for k in maxi(INV_SLOTS, ceili(world.inventory.size() / 6.0) * 6):
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		grid.add_child(b)
		if k >= world.inventory.size():
			b.disabled = true   # ô trống
			b.focus_mode = Control.FOCUS_NONE
			continue
		var id: int = world.inventory[k]
		b.icon = Portraits.texture(int(LevelData.item(id).frame))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if id == world.equipped or id == _combine:
			for st in ["normal", "hover"]:
				b.add_theme_stylebox_override(st, Hud.plate_style(Hud.TINT_SELECTED, 12))
		var n := world.count(id)
		if n >= 0:
			var c := Hud.outlined(Label.new(), 18)
			c.text = str(n) + ("/6" if id == 29 else "")
			c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
			b.add_child(c)
		b.focus_entered.connect(_inv_detail.bind(w[2], id))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_toggle_equip.bind(id, back))
		if focus == null or id == _inv_sel:
			focus = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w[3].add_child(spacer)
	w[3].add_child(_foot_button("Đóng", back))
	_show(w[0], back)
	if focus:
		_inv_detail(w[2], world.inventory[focus.get_index()])
		focus.grab_focus.call_deferred()
	else:
		_detail_head(w[2], null, "Túi trống")

func _inv_detail(detail: VBoxContainer, id: int) -> void:
	_inv_sel = id
	var it := LevelData.item(id)
	_detail_head(detail, Portraits.texture(int(it.frame)), LevelData.text(int(it.name_id), lang))
	var n := world.count(id)
	if n >= 0:
		_detail_line(detail, "Số lượng: %d%s" % [n, "/6" if id == 29 else ""])
	if id == world.equipped:
		_detail_line(detail, "Đang cầm trên tay.", MAXED)
	_grow(detail)
	var hint := "Enter: cất đi" if id == world.equipped else "Enter: dùng"
	if World.NOTE_TEXT.has(id):
		hint = "Enter: đọc"
	elif _combine >= 0:
		hint = "Enter: ghép với %s" % LevelData.text(int(LevelData.item(_combine).name_id), lang)
	elif world.can_combine(id) and id != world.equipped:
		hint = "Enter: cầm lên để ghép"
	_detail_line(detail, hint, Hud.GOLD)

## Khung chung Túi đồ / Kỹ năng (mockup 2026-09-30): tab trên cùng, lưới trái, khung chi tiết phải, thanh đáy.
## Trả [cửa sổ, chỗ đặt lưới, khung chi tiết, thanh đáy].
func _window(skills: bool, back: Callable) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = WINDOW
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["TÚI ĐỒ", false], ["KỸ NĂNG (%d)" % world.upgrade_points(), true]]:
		var b := Button.new()
		b.text = t[0]
		b.custom_minimum_size = Vector2(220, 0)
		if t[1] == skills:
			b.focus_mode = Control.FOCUS_NONE
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, Hud.plate_style(Hud.TINT_SELECTED, 12))
			b.add_theme_color_override("font_color", Hud.GOLD)
			b.add_theme_color_override("font_hover_color", Hud.GOLD)
		else:
			b.modulate = Color(0.8, 0.8, 0.8)
			b.pressed.connect(_discard_then.bind(open_skills.bind(back) if t[1] else open_inventory.bind(back)))
		tabs.add_child(b)
	box.add_child(tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(DETAIL_W + 32, 0)
	side.add_theme_stylebox_override("panel", Hud.plate_style(Color(0.7, 0.66, 0.62), 16))
	body.add_child(side)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	side.add_child(detail)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	return [panel, left, detail, foot]

func _detail_head(detail: VBoxContainer, tex: Texture2D, name: String) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if tex:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(72, 72)
		row.add_child(ic)
	var t := Hud.title(name, 30)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = DETAIL_W - (84 if tex else 0)   # chữ tự xuống dòng cần bề rộng cố định, không thì cao vọt
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	detail.add_child(row)

func _detail_line(detail: VBoxContainer, text: String, color := Color(0.92, 0.88, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = DETAIL_W
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	detail.add_child(l)
	return l

func _grow(box: BoxContainer) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(c)

func _foot_button(text: String, action: Callable) -> Button:
	var b := _button(text, action)
	b.custom_minimum_size = Vector2(150, 0)
	return b

## Spec mục 6b. Bấm + (hoặc Enter trên ô) là mua thử ngay trên world; Lưu thì chốt, rời trang chưa lưu thì trả lại như cũ.
func open_skills(back: Callable) -> void:
	if _skill_snap.is_empty():
		_skill_snap = [world.upgrades.duplicate(), world.max_energy, world.energy]
	var w := _window(true, back)
	var names: Array = Hud.SKILL_ICONS[world.hero].filter(func(n): return UPGRADE_TEXT.has(n))
	if _skill_sel not in names:
		_skill_sel = names[0]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	w[1].add_child(grid)
	var focus: Button = null
	for n in names:
		var u: Array = World.UPGRADES[world.hero].get(n, [])
		var lv := world.upgrade_level(n)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.icon = Hud.skill_icon(world.hero, n)
		b.expand_icon = true
		for st in ["normal", "hover", "pressed", "disabled"]:   # icon đã có khung sắt riêng
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		if not _skill_open(n):
			b.modulate = Color(0.3, 0.3, 0.3)
		elif not u.is_empty() and lv < u[0] and not world.can_buy(n):
			b.modulate = Color(0.65, 0.65, 0.65)
		b.focus_entered.connect(_skill_detail.bind(w[2], n, back))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_buy_skill.bind(n, back))
		b.set_meta("skill", n)
		cell.add_child(b)
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 8)
		pips.custom_minimum_size = Vector2(0, 12)
		for i in (u[0] if not u.is_empty() else 0):
			pips.add_child(_pip(i < lv, lv >= u[0], i >= int(_skill_snap[0].get(n, 0))))
		cell.add_child(pips)
		grid.add_child(cell)
		if n == _skill_sel:
			focus = b
	var cur := TextureRect.new()
	cur.texture = Hud.skill_icon("clara", "bracelet") if world.hero == "clara" else Portraits.texture(int(LevelData.item(21).frame))
	cur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cur.custom_minimum_size = Vector2(40, 40)
	w[3].add_child(cur)
	var pts := Label.new()
	pts.text = "Điểm còn lại: %d" % world.upgrade_points()
	pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w[3].add_child(pts)
	var save := _foot_button("Lưu", func():
		_skill_snap = []
		open_skills(back))
	save.disabled = world.upgrades == _skill_snap[0]
	w[3].add_child(save)
	w[3].add_child(_foot_button("Đóng", _discard_then.bind(back)))
	_show(w[0], _discard_then.bind(back))
	_skill_detail(w[2], _skill_sel, back)
	focus.grab_focus.call_deferred()

func _skill_open(n: String) -> bool:
	var u: Array = World.UPGRADES[world.hero].get(n, [])
	return world.unlocked(n) if u.is_empty() else world.bosses_down >= int(u[2])

## Chấm cấp dưới icon: vàng = đã có, sáng hơn = vừa cộng chưa lưu, xanh = đã tối đa, tối = chưa có.
func _pip(bought: bool, maxed: bool, unsaved: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(12, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = (MAXED if maxed else (Color(1, 0.95, 0.7) if unsaved else Hud.GOLD)) if bought else Color(0.1, 0.08, 0.06)
	sb.border_color = Color(0.55, 0.42, 0.22)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _buy_skill(n: String, back: Callable) -> void:
	if world.buy(n):
		open_skills(back)

func _skill_detail(detail: VBoxContainer, n: String, back: Callable) -> void:
	_skill_sel = n
	if _page:
		for b in _page.find_children("*", "Button", true, false):
			if b.has_meta("skill"):
				b.add_theme_stylebox_override("normal", Hud.focus_style() if b.get_meta("skill") == n else StyleBoxEmpty.new())
	var t: Array = UPGRADE_TEXT[n]
	_detail_head(detail, Hud.skill_icon(world.hero, n), t[0])
	_detail_line(detail, t[1])
	var u: Array = World.UPGRADES[world.hero].get(n, [])
	var lv := world.upgrade_level(n)
	for i in t[2].size():
		var col := Hud.GOLD if i < lv else (Color(0.95, 0.9, 0.8) if i == lv else Color(0.55, 0.52, 0.48))
		_detail_line(detail, "Cấp %d: %s" % [i + 1, t[2][i]], col)
	_grow(detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	detail.add_child(row)
	if not _skill_open(n):
		var boss: int = World.UNLOCKS[world.hero].get(n, u[2] if not u.is_empty() else 0)
		status.text = "Sắp mở khóa (sau Boss %d)" % boss
		status.modulate = Color(0.7, 0.7, 0.7)
		return
	if u.is_empty():
		status.text = "Đã mở"
		status.add_theme_color_override("font_color", MAXED)
		return
	if lv >= u[0]:
		status.text = "Tối đa"
		status.add_theme_color_override("font_color", MAXED)
		return
	status.text = "%d điểm" % u[1] if world.can_buy(n) else "Thiếu điểm (cần %d)" % u[1]
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 56)
	plus.add_theme_font_size_override("font_size", 34)
	plus.disabled = not world.can_buy(n)
	plus.pressed.connect(_buy_skill.bind(n, back))
	row.add_child(plus)

func _discard_skills() -> void:
	if _skill_snap.is_empty():
		return
	world.upgrades = _skill_snap[0]
	world.max_energy = _skill_snap[1]
	world.energy = _skill_snap[2]
	_skill_snap = []

func _discard_then(then: Callable) -> void:
	_discard_skills()
	then.call()

func _confirm_quit(back: Callable) -> void:
	_show(_list("THOÁT GAME?", "Tiến trình từ lần tự lưu gần nhất vẫn còn.", [
		["Thoát", func(): get_tree().quit()],
		["Không", back],
	]), back)

# --- dựng ---

func _panel(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var head := Hud.title(title, 38)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	return box

func _list(title: String, subtitle: String, items: Array) -> Control:
	var box := _panel(title)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 18)
		sub.modulate = Color(1, 1, 1, 0.7)
		box.add_child(sub)
	for it in items:
		var b := _button(it[0], it[1])
		b.disabled = it.size() > 2 and it[2]
		box.add_child(b)
	return box.get_parent()

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 0)
	b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)
	return b

func _row(label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	row.add_child(control)
	return row

func _show(page: Control, back: Callable) -> void:
	if _page:
		_page.queue_free()
	_page = page
	_back = back
	add_child(page)
	show()
	page.reset_size()
	page.position = (size - page.size) / 2
	page.resized.connect(func(): page.position = (size - page.size) / 2)
	var first := page.find_children("*", "Button", true, false).filter(func(b): return not b.disabled)
	if not first.is_empty():
		first[0].grab_focus.call_deferred()

func _close() -> void:
	_discard_skills()
	_combine = -1
	if _page:
		_page.queue_free()
		_page = null
	hide()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev.is_action_pressed("menu") and _back.is_valid():
		get_viewport().set_input_as_handled()
		_back.call()

# --- cài đặt ---

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		lang = cfg.get_value("game", "lang", lang)
		music_volume = cfg.get_value("audio", "music_volume", music_volume)
	if not LANGS.has(lang):
		lang = "vi"
	music_volume = clampf(music_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(music_volume))

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(music_volume))
	var cfg := ConfigFile.new()
	cfg.set_value("game", "lang", lang)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)
