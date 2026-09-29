## Chạy toàn bộ test: .\tools\test.ps1   (hoặc: godot --headless --path . -s res://tests/run.gd)
## Chỉ một nhóm: thêm "-- unit" / "-- integration" / "-- parity".
## Tìm đệ quy mọi tests/**/test_*.gd, gọi mọi hàm test_* (được phép await); thoát mã 1 nếu có lỗi.
extends SceneTree

func _initialize() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var failed := 0
	var passed := 0
	for path in _find("res://tests"):
		if not only.is_empty() and not only.any(func(g): return path.contains("/%s/" % g)):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s: script không biên dịch được" % path)
			continue
		var t: Object = script.new()
		t.tree = self
		for m in t.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			t.errors.clear()
			await t.call(m.name)
			var name := "%s.%s" % [path.trim_prefix("res://tests/"), m.name]
			if t.errors.is_empty():
				passed += 1
				print("PASS " + name)
			else:
				failed += 1
				print("FAIL " + name)
				for e in t.errors:
					print("    " + e)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _find(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_find(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out
