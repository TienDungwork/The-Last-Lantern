## Lớp cha cho mọi file test. Không dùng assert (assert dừng cả tiến trình);
## gom lỗi vào `errors` để runner in đủ mọi lỗi. `tree` để test tích hợp await khung hình/timer.
extends RefCounted

var errors: Array[String] = []
var tree: SceneTree

func eq(got: Variant, want: Variant, msg: String = "") -> void:
	if got != want:
		errors.append("%s: muốn %s, nhận %s" % [msg, str(want), str(got)])

## Cho hiệu ứng đang chặn hàng đợi thoại của game.gd (xoá màn, Hale đứng dậy ở màn 0) chạy xong ngay.
func skip_fx(game: Node) -> void:
	while game._fx_wait > 0.0:
		game._process(game._fx_wait + 0.01)

func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
