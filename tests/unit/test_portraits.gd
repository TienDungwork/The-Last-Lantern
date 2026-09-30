extends "res://tests/lib/test_case.gd"

func test_frame_lookup() -> void:
	var f := Portraits.frame(171)
	eq(f.png, "av.png", "Hale ở av.png")
	ok(f.rect.size.x > 0 and f.rect.size.y > 0, "kích cỡ dương")
	eq(Portraits.frame(325).png, "bq.png", "Jack ở bq.png")

func test_texture_loads() -> void:
	var tex := Portraits.texture(171)
	ok(tex != null, "có texture")
	ok(tex.get_width() > 0, "texture có chiều rộng")

func test_texture_is_hd_atlas() -> void:
	var f := Portraits.frame(231)
	eq(Portraits.texture(231).get_size(), f.rect.size * Portraits.SCALE, "khung cắt từ atlas image/img gấp SCALE lần")
	eq(Portraits.image("bl.png").get_width(), Image.load_from_file(ProjectSettings.globalize_path("res://assets/original/bl.png")).get_width() * Portraits.SCALE, "atlas mới cùng bố cục gốc x SCALE")
