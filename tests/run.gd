## Chạy: & $godot --headless --path . -s res://tests/run.gd
## Tìm mọi tests/test_*.gd, tạo instance, gọi mọi hàm test_*; in PASS/FAIL, thoát mã 1 nếu có lỗi.
extends SceneTree

func _init() -> void:
	var failed := 0
	var passed := 0
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_base.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s: script không biên dịch được" % f)
			continue
		var t: Object = script.new()
		for m in t.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			t.errors.clear()
			t.call(m.name)
			if t.errors.is_empty():
				passed += 1
				print("PASS %s.%s" % [f, m.name])
			else:
				failed += 1
				print("FAIL %s.%s" % [f, m.name])
				for e in t.errors:
					print("    " + e)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
