class_name CameraRig
extends Node3D
## Camera 2.5D: nhìn xuống ~55°, bám mượt theo mục tiêu. Con: Camera3D.

@export var target: Node3D
@export var pitch_deg := 55.0
@export var distance := 9.0
@export var smooth := 8.0

var cam: Camera3D

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	rotation_degrees.x = -pitch_deg
	cam.position = Vector3(0, 0, distance)
	cam.current = true
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, clampf(delta * smooth, 0.0, 1.0))
