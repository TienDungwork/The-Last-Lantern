class_name Hud
extends Label
## Góc trên trái: năng lượng, vị trí, độ sáng ô đang đứng (số để so với bản gốc).

func _ready() -> void:
	position = Vector2(16, 12)
	add_theme_font_size_override("font_size", 22)

func show_state(s: GridState, light_level: int) -> void:
	text = "Năng lượng %d/%d   Ô (%d,%d)   Sáng %d   Túi %s" % [
		s.energy, s.max_energy, s.player.x, s.player.y, light_level, str(s.inventory)]
