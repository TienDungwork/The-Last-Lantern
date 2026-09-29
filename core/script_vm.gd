class_name ScriptVM
extends RefCounted
## Chạy các lệnh kịch bản của một sự kiện lên GridState. Xem class_10.method_209 (bản gốc).

var s: GridState

func _init(state: GridState) -> void:
	s = state

func run(e: Dictionary) -> void:
	for c in e.commands:
		_exec(int(c.op), c.args)

func _exec(op: int, _a: Array) -> void:
	push_error("ScriptVM: lệnh %d chưa cài" % op)
