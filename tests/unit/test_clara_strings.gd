extends "res://tests/lib/test_case.gd"
## Thoại tuyến Clara (data_enhanced/strings_*_clara.json), spec 2026-09-30-hero-select-clara mục 3.

const REQUIRED := [0, 1, 2, 3, 7, 8, 9, 31, 32, 34, 35, 36, 39, 44, 45, 48, 49, 50, 51, 56, 58, 62, 63, 78, 80,
	82, 91, 93, 94, 101, 104, 107, 109, 112, 113, 114, 116, 117, 120, 121, 160, 162, 168, 169, 170, 175, 228,
	37, 40, 42, 60, 61, 83, 95, 96, 124, 125]
const NEW_FIRST := 300
const NEW_LAST := 399

func _load(lang: String) -> Dictionary:
	return LevelData.read_json("res://data_enhanced/strings_%s_clara.json" % lang)

func _text(v: Variant) -> String:
	return v.text if v is Dictionary else v

func test_required_and_same_keys() -> void:
	var vi := _load("vi")
	var en := _load("en")
	for id in REQUIRED:
		ok(vi.has(str(id)), "vi thiếu câu %d" % id)
	var kv := vi.keys()
	var ke := en.keys()
	kv.sort()
	ke.sort()
	eq(kv, ke, "vi và en cùng bộ chỉ số")

func test_ids_and_placeholders() -> void:
	for lang in ["vi", "en"]:
		var base: Array = LevelData.read_json("res://data/strings_%s.json" % lang)
		var d := _load(lang)
		for k in d:
			var id := int(k)
			var t := _text(d[k])
			ok(t != "", "%s câu %s rỗng" % [lang, k])
			if id >= NEW_FIRST:
				ok(id <= NEW_LAST, "%s câu mới %s ngoài 300..399" % [lang, k])
				continue
			ok(id < base.size(), "%s chỉ số %s không có trong bản gốc" % [lang, k])
			for n in range(1, 8):
				var ph := "%%%d" % n
				eq(t.contains(ph), base[id].contains(ph), "%s câu %s giữ %s" % [lang, k, ph])

func test_line_120_keeps_clara_portrait() -> void:
	for lang in ["vi", "en"]:
		eq(int(_load(lang)["120"].portrait), 179, "%s câu 120 giữ chân dung Clara" % lang)
