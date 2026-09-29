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
