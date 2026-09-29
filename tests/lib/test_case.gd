## Lớp cha cho mọi file test. Không dùng assert (assert dừng cả tiến trình);
## gom lỗi vào `errors` để runner in đủ mọi lỗi. `tree` để test tích hợp await khung hình/timer.
extends RefCounted

var errors: Array[String] = []
var tree: SceneTree

func eq(got: Variant, want: Variant, msg: String = "") -> void:
	if got != want:
		errors.append("%s: muốn %s, nhận %s" % [msg, str(want), str(got)])

func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
