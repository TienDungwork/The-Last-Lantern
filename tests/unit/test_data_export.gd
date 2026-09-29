extends "res://tests/lib/test_case.gd"
## Kiểm tra data/ do tools/export_data.py sinh ra (đủ file, đủ chuỗi, bảng khung hình đúng).

func test_all_levels_exported() -> void:
	for n in 19:
		ok(FileAccess.file_exists("res://data/levels/%02d.json" % n), "thiếu màn %d" % n)

func test_strings_both_languages() -> void:
	for lang in ["en", "vi"]:
		eq(LevelData.read_json("res://data/strings_%s.json" % lang).size(), 258, "số chuỗi " + lang)
	ok(LevelData.text(12, "en").contains("\n"), "chuỗi nhiều dòng giữ xuống dòng")

func test_tables() -> void:
	var frames: Array = LevelData.read_json("res://data/frames.json")
	eq(frames.size(), 435, "số khung hình")
	eq(frames[171][0], "av.png", "chân dung Hale")
	var items: Dictionary = LevelData.read_json("res://data/items.json")
	eq(items.size(), 34, "số vật phẩm")
	eq(int(items["0"].name_id), 179, "tên Note 1")
	var cm: Dictionary = LevelData.read_json("res://data/citymap.json")
	eq(cm.rows.size(), int(cm.height), "bản đồ thành phố đủ hàng")
	ok(FileAccess.file_exists("res://assets/original/av.png"), "đã chép PNG gốc")
