class_name Menu
extends Control
## Mọi trang menu trên một lớp phủ: tiêu đề, tạm dừng, cài đặt, túi đồ, hỏi lại khi thoát.
## Bàn phím: mũi tên + Enter (focus của Godot), Esc = quay lại. Game đứng yên khi menu mở (game.gd kiểm tra visible).

signal new_game
signal continue_game
signal quit_to_title

const SETTINGS_PATH := "user://settings.cfg"
const FRAME := Color(0.72, 0.53, 0.28)
const LANGS := {"vi": "Tiếng Việt", "en": "English"}

var has_save := false
var in_game := false          # false = đang ở màn tiêu đề
var world: World              # cho trang túi đồ
var lang := "vi"
var music_volume := 0.8
var _page: Control
var _back: Callable = Callable()

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
	t.set_stylebox("normal", "Button", _box(Color(0.1, 0.075, 0.06, 0.9), FRAME.darkened(0.45)))
	t.set_stylebox("hover", "Button", _box(Color(0.18, 0.12, 0.08, 0.95), FRAME))
	t.set_stylebox("focus", "Button", _box(Color(0.22, 0.15, 0.09, 0.95), Color(1, 0.82, 0.35)))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.2, 0.1), Color(1, 0.82, 0.35)))
	t.set_stylebox("disabled", "Button", _box(Color(0.08, 0.07, 0.06, 0.7), Color(0.25, 0.22, 0.2)))
	t.set_stylebox("panel", "PanelContainer", Hud.panel_style(FRAME))
	return t

# --- trang ---

func open_title() -> void:
	in_game = false
	_show(_list("THE LAST LANTERN II", "Ashwood chìm trong bóng tối", [
		["Chơi tiếp", _start.bind(continue_game), not has_save],
		["Trò chơi mới", _start.bind(new_game)],
		["Cài đặt", open_settings.bind(open_title)],
		["Thoát", _confirm_quit.bind(open_title)],
	]), Callable())

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

func _toggle_equip(id: int, back: Callable) -> void:
	world.equipped = -1 if world.equipped == id else id
	open_inventory(back)

func open_inventory(back: Callable) -> void:
	var box := _panel("TÚI ĐỒ")
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
		b.focus_entered.connect(func(): info.text = item_name + hint)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_toggle_equip.bind(id, back))
		grid.add_child(b)
	box.add_child(_button("Đóng", back))
	_show(box.get_parent(), back)

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
