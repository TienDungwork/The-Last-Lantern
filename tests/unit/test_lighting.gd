extends "res://tests/lib/test_case.gd"
## Lửa lung linh: năng lượng đèn dao động quanh mức gốc, không vượt biên độ FLICKER, hai ngọn lửa không nháy đồng bộ.

func test_flicker_stays_in_range_and_varies() -> void:
	var lv := LightingView.new()
	var a := OmniLight3D.new()
	var b := OmniLight3D.new()
	b.position = Vector3(3, 0, 5)
	for l in [a, b]:
		l.set_meta("base", 3.0)
		lv.add_child(l)
		lv._lights.append(l)
	var seen_a: Array = []
	var differ := false
	for i in 60:
		lv._process(0.05)
		ok(absf(a.light_energy - 3.0) <= 3.0 * LightingView.FLICKER + 0.0001, "trong biên độ")
		seen_a.append(a.light_energy)
		differ = differ or absf(a.light_energy - b.light_energy) > 0.05
	ok(seen_a.max() - seen_a.min() > 0.2, "có dao động")
	ok(differ, "hai ngọn lửa lệch pha")
	lv.free()
