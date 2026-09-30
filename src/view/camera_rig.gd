class_name CameraRig
extends Node3D
## Camera 2.5D: nhìn xuống ~55°, bám mượt theo mục tiêu. Con: Camera3D.
## Kiểu B: trực giao nhìn thẳng xuống, 1 ô = TEXELS_PER_TILE pixel, vị trí khoá theo lưới pixel để hình không rung/nhòe khi trượt.

@export var target: Node3D
@export var pitch_deg := 55.0
@export var distance := 9.0
@export var smooth := 8.0

var cam: Camera3D
var _pixel := LevelBuilder.art == "B"
var _smooth_pos: Vector3

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	if _pixel:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		pitch_deg = LevelBuilder.B_PITCH
		distance = 20.0
		cam.far = 40.0   # các lớp frame phẳng chỉ cách nhau vài phần nghìn: cần độ sâu mịn
	add_child(cam)
	rotation_degrees.x = -pitch_deg
	cam.position = Vector3(0, 0, distance)
	cam.current = true
	if target:
		global_position = target.global_position
	_smooth_pos = global_position

func _process(delta: float) -> void:
	if target:
		_smooth_pos = _smooth_pos.lerp(target.global_position, clampf(delta * smooth, 0.0, 1.0))
	global_position = _smooth_pos
	if _pixel:
		var px := 1.0 / LevelBuilder.TEXELS_PER_TILE
		cam.size = get_viewport().get_visible_rect().size.y * px
		var b := global_basis
		var p := _smooth_pos
		global_position = b.x * snappedf(p.dot(b.x), px) + b.y * snappedf(p.dot(b.y), px) + b.z * p.dot(b.z)
