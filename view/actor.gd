class_name ActorView
extends Node3D
## Hình nhân vật tạm (viên nang) trượt giữa hai ô trong STEP_TIME giây; quay mặt theo hướng.
## M3 thay mesh bằng GLB có AnimationPlayer; giữ nguyên API move_to()/face()/set_anim().

const STEP_TIME := 0.18
const FACING_Y := {1: -PI / 2, 2: PI, 3: PI / 2, 4: 0.0}   # hướng game -> góc quanh trục Y

var _tween: Tween

func _ready() -> void:
	if get_child_count() == 0:
		var mi := MeshInstance3D.new()
		var m := CapsuleMesh.new()
		m.radius = 0.25
		m.height = 1.4
		mi.mesh = m
		mi.position.y = 0.7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.75, 0.6)
		mi.material_override = mat
		add_child(mi)

func snap_to(p: Vector2i) -> void:
	if _tween:
		_tween.kill()
	position = LevelBuilder.world_pos(p)

func move_to(p: Vector2i) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", LevelBuilder.world_pos(p), STEP_TIME)
	_tween.finished.connect(set_anim.bind("idle"), CONNECT_ONE_SHOT)
	set_anim("walk")

func face(dir: int) -> void:
	rotation.y = FACING_Y.get(dir, 0.0)

func set_anim(anim: String) -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(anim):
		ap.play(anim)
