class_name LightingView
extends Node3D
## Đồng bộ hình ảnh với LightField: tô sàn theo mức 0..7 và đặt đèn Godot cho mỗi nguồn đang bật.

const LEVEL_COLORS := [
	Color(0.05, 0.05, 0.07), Color(0.16, 0.14, 0.1), Color(0.27, 0.23, 0.15), Color(0.38, 0.32, 0.2),
	Color(0.5, 0.42, 0.26), Color(0.62, 0.52, 0.32), Color(0.75, 0.64, 0.4), Color(0.9, 0.8, 0.55)]
# dir của đèn = mã hướng đi: 1 phải (+x), 2 xuống (+y lưới = +z thế giới), 3 trái, 4 lên
const DIR_TO_VEC := {1: Vector3(1, 0, 0), 2: Vector3(0, 0, 1), 3: Vector3(-1, 0, 0), 4: Vector3(0, 0, -1)}

var _lights: Array[Light3D] = []

func setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.3)
	env.ambient_light_energy = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func sync(s: GridState, field: Array, builder: LevelBuilder) -> void:
	for p in builder.floors:
		var lvl: int = field[p.y][p.x]
		(builder.floors[p].material_override as StandardMaterial3D).albedo_color = LEVEL_COLORS[lvl]
	for l in _lights:
		l.queue_free()
	_lights.clear()
	for L in s.lights:
		if int(L.on) == 0 or int(L.radius) <= 0:
			continue
		var pos := LevelBuilder.world_pos(Vector2i(int(L.x), int(L.y)), 1.2)
		var light: Light3D
		if int(L.dir) != 0:
			var spot := SpotLight3D.new()
			spot.spot_range = float(L.radius) * 1.5
			spot.spot_angle = 35.0
			add_child(spot)
			spot.position = pos
			spot.look_at(pos + DIR_TO_VEC[int(L.dir)] + Vector3(0, -0.3, 0))
			light = spot
		else:
			var omni := OmniLight3D.new()
			omni.omni_range = float(L.radius) * 1.2
			add_child(omni)
			omni.position = pos
			light = omni
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 2.0
		light.shadow_enabled = true
		_lights.append(light)
