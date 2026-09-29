class_name LightingView
extends Node3D
## Đồng bộ hình ảnh với LightField: tô sàn theo mức 0..7 và đặt đèn Godot cho mỗi nguồn đang bật.

const LEVEL_COLORS := [
	Color(0.05, 0.05, 0.07), Color(0.16, 0.14, 0.1), Color(0.27, 0.23, 0.15), Color(0.38, 0.32, 0.2),
	Color(0.5, 0.42, 0.26), Color(0.62, 0.52, 0.32), Color(0.75, 0.64, 0.4), Color(0.9, 0.8, 0.55)]
# dir của đèn = mã hướng đi: 1 phải (+x), 2 xuống (+y lưới = +z thế giới), 3 trái, 4 lên
const DIR_TO_VEC := {1: Vector3(1, 0, 0), 2: Vector3(0, 0, 1), 3: Vector3(-1, 0, 0), 4: Vector3(0, 0, -1)}

const WARM := Color(1.0, 0.74, 0.45)
const FLICKER := 0.12   # biên độ lung linh của lửa (tỉ lệ năng lượng)
# Bụi: không nhận ánh sáng môi trường nên chỉ hiện chỗ có đèn chiếu (bụi trong luồng đèn).
const DUST_SHADER := "shader_type spatial;
render_mode ambient_light_disabled, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	ALBEDO = vec3(1.0, 0.86, 0.62);
	ALPHA = COLOR.a;
}"

var _lights: Array[Light3D] = []
var _props: Array[Node3D] = []
var _dust: CPUParticles3D
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	for l in _lights:   # nhiễu từ 3 sóng sin lệch pha theo vị trí: mỗi ngọn lửa nháy riêng, không đồng bộ
		var ph: float = l.position.x * 3.1 + l.position.z * 1.7
		var n := sin(_t * 7.0 + ph) * 0.5 + sin(_t * 13.0 + ph * 2.3) * 0.3 + sin(_t * 23.0 + ph * 0.7) * 0.2
		l.light_energy = l.get_meta("base") * (1.0 + FLICKER * n)

func _make_dust() -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.amount = 160
	d.lifetime = 8.0
	d.preprocess = 8.0
	d.local_coords = false   # bụi đã bay không bị kéo theo người chơi
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(8, 1.2, 6)
	d.direction = Vector3.UP
	d.spread = 180.0
	d.initial_velocity_min = 0.02
	d.initial_velocity_max = 0.08
	d.gravity = Vector3(0, -0.004, 0)
	var ramp := Gradient.new()   # hiện dần rồi tắt dần
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 0.9))
	ramp.add_point(0.8, Color(1, 1, 1, 0.9))
	d.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.2 / LevelBuilder.TEXELS_PER_TILE * LevelBuilder.TILE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = DUST_SHADER
	q.material = mat
	d.mesh = q
	return d

func setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.3)
	env.ambient_light_energy = 0.25
	if LevelBuilder.art == "B":   # tối vẫn thấy lờ mờ nền; không glow (phủ mờ cả cảnh)
		env.ambient_light_color = Color(0.3, 0.3, 0.36)
		env.ambient_light_energy = 0.45
		# Sương thể tích chỉ sáng nhờ đèn (không nhận ambient): quầng ấm quanh lửa, luồng sáng từ đèn chiếu.
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.035
		env.volumetric_fog_albedo = Color(0.75, 0.68, 0.6)
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_ambient_inject = 0.0
		env.volumetric_fog_length = 24.0
		_dust = _make_dust()
		add_child(_dust)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func sync(s: GridState, field: Array, builder: LevelBuilder) -> void:
	# Kiểu B: sàn giữ màu texture, để đèn thật tỏa mềm thay vì tô từng ô.
	for p in builder.floors if LevelBuilder.art != "B" else []:
		var lvl: int = field[p.y][p.x]
		(builder.floors[p].material_override as StandardMaterial3D).albedo_color = LEVEL_COLORS[lvl]
	for l in _lights:
		l.queue_free()
	_lights.clear()
	for m in _props:
		m.queue_free()
	_props.clear()
	for i in s.lights.size():
		var L: Dictionary = s.lights[i]
		if int(L.type) in [0, 1, 2] and i != s.carried and LevelBuilder.art == "B":
			var sp := LevelBuilder.sprite("ad_14")
			sp.shaded = int(L.on) == 0   # đèn đang cháy tự sáng
			sp.position = LevelBuilder.world_pos(Vector2i(int(L.x), int(L.y)))
			add_child(sp)
			_props.append(sp)
		elif int(L.type) in [0, 1, 2] and i != s.carried:   # đèn nhặt được nằm dưới đất
			var mi := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = 0.12
			m.bottom_radius = 0.15
			m.height = 0.35
			mi.mesh = m
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.9, 0.7, 0.3)
			mat.emission_enabled = int(L.on) == 1
			mat.emission = Color(1.0, 0.8, 0.4)
			mi.material_override = mat
			mi.position = LevelBuilder.world_pos(Vector2i(int(L.x), int(L.y)), 0.18)
			add_child(mi)
			_props.append(mi)
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
		if LevelBuilder.art == "B":   # lửa ấm, bóng viền mềm, tắt dần êm
			light.light_color = WARM
			light.light_energy = 3.0
			light.light_size = 0.2
			light.light_volumetric_fog_energy = 1.5
			if light is OmniLight3D:
				light.omni_attenuation = 1.5
		light.set_meta("base", light.light_energy)
		_lights.append(light)
	if _dust:
		_dust.position = LevelBuilder.world_pos(s.player, 1.0)
