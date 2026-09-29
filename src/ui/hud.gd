class_name Hud
extends Label
## Góc trên trái: năng lượng, vị trí, độ sáng ô đang đứng (số để so với bản gốc).

var highlight := false   # op 27 mode 2: nháy vàng (bản gốc: khung quanh một ô HUD, sáng 300/500 ms)

func _ready() -> void:
	position = Vector2(16, 12)
	add_theme_font_size_override("font_size", 22)

func _process(_delta: float) -> void:
	modulate = Color(1, 0.85, 0.3) if highlight and Time.get_ticks_msec() % 500 <= 300 else Color.WHITE

func show_state(s: GridState, light_level: int) -> void:
	text = "Năng lượng %d/%d   Bóng đèn %d   Ô (%d,%d)   Sáng %d   Túi %s" % [
		s.energy, s.max_energy, s.bulbs, s.player.x, s.player.y, light_level, str(s.inventory)]
