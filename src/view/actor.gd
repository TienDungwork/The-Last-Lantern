class_name ActorView
extends Node3D
## Hình nhân vật tạm (viên nang) trượt giữa hai ô trong STEP_TIME giây; quay mặt theo hướng.
## M3 thay mesh bằng GLB có AnimationPlayer; giữ nguyên API move_to()/face()/set_anim().

const STEP_TIME := 0.18
const FACING_Y := {1: -PI / 2, 2: PI, 3: PI / 2, 4: 0.0}   # hướng game -> góc quanh trục Y

var _tween: Tween

func _ready() -> void:
	if get_child_count() == 0 and LevelBuilder.art == "B":
		add_child(LevelBuilder.sprite("af_02"))
	elif get_child_count() == 0 and LevelBuilder.art == "A":
		_build_toon_hale()
	elif get_child_count() == 0:
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

## Hale tạm cho kiểu A, ghép khối (thay bằng GLB ở M3).
func _build_toon_hale() -> void:
	var body := Node3D.new()
	add_child(body)
	var coat := CylinderMesh.new()
	coat.top_radius = 0.16
	coat.bottom_radius = 0.28
	coat.height = 0.95
	LevelBuilder.part(body, coat, Color(0.22, 0.18, 0.15), Vector3(0, 0.58, 0))
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	LevelBuilder.part(body, head, Color(0.85, 0.66, 0.52), Vector3(0, 1.2, 0))
	var hair := SphereMesh.new()
	hair.radius = 0.16
	hair.height = 0.26
	LevelBuilder.part(body, hair, Color(0.15, 0.1, 0.08), Vector3(0, 1.27, -0.03))
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.08
	scarf.outer_radius = 0.17
	LevelBuilder.part(body, scarf, Color(0.5, 0.12, 0.1), Vector3(0, 1.05, 0))
	var bag := BoxMesh.new()
	bag.size = Vector3(0.12, 0.22, 0.2)
	LevelBuilder.part(body, bag, Color(0.4, 0.26, 0.14), Vector3(0.27, 0.6, 0.05))
	for x in [-0.1, 0.1]:
		var boot := BoxMesh.new()
		boot.size = Vector3(0.12, 0.12, 0.2)
		LevelBuilder.part(body, boot, Color(0.1, 0.07, 0.05), Vector3(x, 0.06, 0.03))

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
	var s := get_child(0) as Sprite3D
	if s and dir in [1, 3]:
		s.flip_h = dir == 1

## SPECIAL 15/16 (method_105, field_145..148): nằm xuống 0.2 s rồi nằm yên; đứng dậy sau 1.5 s nằm, 1.3 s nhổm lên.
## Kiểu B: ngả sprite nằm ngang (bỏ kéo cao bù góc nhìn khi nằm).
func lie(lying: bool) -> float:
	var s := get_child(0) as Sprite3D
	if s == null:
		return 0.0
	var up_scale := 1.0 / cos(deg_to_rad(LevelBuilder.B_PITCH))
	var tw := create_tween().set_parallel()
	if lying:
		tw.tween_property(s, "rotation:z", PI / 2, 0.2)
		tw.tween_property(s, "scale:y", 1.0, 0.2)
		return 1.7
	s.rotation.z = PI / 2
	s.scale.y = 1.0
	tw.tween_property(s, "rotation:z", 0.0, 1.3).set_delay(1.5)
	tw.tween_property(s, "scale:y", up_scale, 1.3).set_delay(1.5)
	return 2.8

func set_anim(anim: String) -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(anim):
		ap.play(anim)
