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
const WINDOW := Vector2(900, 470)          # cửa sổ Túi đồ / Kỹ năng cố định, vừa 1024x576
const INV_SLOTS := 18                      # 6 x 3 ô
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	theme = _theme()
	load_settings()
	hide()

static func _box(bg: Color, border: Color, width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(12)
	return sb

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
	var box := _panel("TÚI ĐỒ")
	_tabs(box, false, back)
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	box.add_child(info)
	if world.inventory.is_empty():
		info.text = "Túi trống."
	for id in world.inventory:
		var it := LevelData.item(id)
		var b := Button.new()
		b.icon = Portraits.texture(int(it.frame))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(84, 84)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if id == world.equipped:
			b.add_theme_stylebox_override("normal", _box(Color(0.25, 0.17, 0.08), Color(1, 0.82, 0.35), 4))
		var item_name := LevelData.text(int(it.name_id), lang)
		var hint := "  (đang dùng — Enter để cất)" if id == world.equipped else "  — Enter để dùng"
		if World.NOTE_TEXT.has(id):
			hint = "  — Enter để đọc"
		if _combine >= 0:
			hint = "  — Enter để ghép với %s" % LevelData.text(int(LevelData.item(_combine).name_id), lang)
		b.focus_entered.connect(func(): info.text = item_name + hint)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_toggle_equip.bind(id, back))
		var n := world.count(id)
		if n >= 0:
			var c := Label.new()
			c.text = str(n) + ("/6" if id == 29 else "")
			c.add_theme_font_size_override("font_size", 18)
			c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
			b.add_child(c)
		grid.add_child(b)
	box.add_child(_button("Đóng", back))
	_show(box.get_parent(), back)

## Hai nút chuyển trang dưới tiêu đề túi đồ: Túi đồ | Kỹ năng (N điểm).
func _tabs(box: VBoxContainer, skills: bool, back: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for t in [["Túi đồ", false], ["Kỹ năng (%d điểm)" % world.upgrade_points(), true]]:
		var b := Button.new()
		b.text = t[0]
		b.custom_minimum_size = Vector2(240, 0)
		b.mouse_entered.connect(b.grab_focus)
		if t[1] == skills:
			b.add_theme_stylebox_override("normal", _box(Color(0.25, 0.17, 0.08), Color(1, 0.82, 0.35), 4))
		else:
			b.pressed.connect(_discard_then.bind(open_skills.bind(back) if t[1] else open_inventory.bind(back)))
		row.add_child(b)
	box.add_child(row)
	box.move_child(row, 1)

## Spec mục 6b. Bấm + là mua thử ngay trên world; Lưu thì chốt, rời trang chưa lưu thì trả lại như cũ.
func open_skills(back: Callable) -> void:
	if _skill_snap.is_empty():
		_skill_snap = [world.upgrades.duplicate(), world.max_energy, world.energy]
	var box := _panel("TÚI ĐỒ")
	_tabs(box, true, back)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(620, 48)
	info.add_theme_font_size_override("font_size", 18)
	info.text = "Trỏ vào một dòng để xem mô tả."
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	box.add_child(rows)
	var table: Dictionary = World.UPGRADES[world.hero]
	for n in table:
		var u: Array = table[n]
		var lv := world.upgrade_level(n)
		var saved := int(_skill_snap[0].get(n, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var ic := TextureRect.new()
		ic.texture = Hud.skill_icon(world.hero, n)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.custom_minimum_size = Vector2(40, 40)
		row.add_child(ic)
		var name_l := Label.new()
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_l.text = UPGRADE_TEXT[n][0]
		name_l.custom_minimum_size = Vector2(240, 0)
		row.add_child(name_l)
		var lv_l := Label.new()
		lv_l.text = "%d/%d" % [lv, u[0]]
		lv_l.custom_minimum_size = Vector2(90, 0)
		lv_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lv_l)
		var cost := Label.new()
		cost.custom_minimum_size = Vector2(160, 0)
		cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost.add_theme_font_size_override("font_size", 18)
		row.add_child(cost)
		if lv >= u[0]:
			cost.text = "Tối đa"
			for l in [name_l, lv_l, cost]:
				l.add_theme_color_override("font_color", MAXED)
		elif world.bosses_down < u[2]:
			cost.text = "Sắp mở khóa"
			row.modulate = DIMMED
		else:
			cost.text = "%d điểm" % u[1]
			if not world.can_buy(n):
				row.modulate = DIMMED
		if lv > saved:
			lv_l.add_theme_color_override("font_color", Color(1, 0.82, 0.35))
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(56, 0)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:   # nút nhỏ vừa dòng 40 px
			var sb := (theme if theme else _theme()).get_stylebox(st, "Button").duplicate() as StyleBoxFlat
			sb.set_content_margin_all(2)
			plus.add_theme_stylebox_override(st, sb)
		plus.disabled = not world.can_buy(n)
		plus.pressed.connect(func():
			world.buy(n)
			open_skills(back))
		var show_desc := func(): info.text = UPGRADE_TEXT[n][1]
		plus.focus_entered.connect(show_desc)
		plus.mouse_entered.connect(show_desc)
		row.mouse_entered.connect(show_desc)
		row.add_child(plus)
		rows.add_child(row)
	box.add_child(info)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	var pts := Label.new()
	pts.text = "Điểm còn lại: %d" % world.upgrade_points()
	pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(pts)
	var save := _button("Lưu", func():
		_skill_snap = []
		open_skills(back))
	save.disabled = world.upgrades == _skill_snap[0]
	for b in [save, _button("Đóng", _discard_then.bind(back))]:
		b.custom_minimum_size = Vector2(150, 0)
		foot.add_child(b)
	box.add_child(foot)
	_show(box.get_parent(), _discard_then.bind(back))

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
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", Color(1, 0.82, 0.45))
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
