class_name FxView
extends Node3D
## Hiệu ứng hình cho thao tác và chiêu: tia lửa, khói, bụi bước chân, lửa cháy, xoáy sáng, bóng tối hút vào, chữ nổi.
## Chỉ vẽ, không đổi trạng thái game. Camera nhìn thẳng xuống nên hạt tỏa theo mặt sàn (xz), bay lên chỉ để đè lên sprite.

const SPARK := Color(1.0, 0.78, 0.4)
const EMBER := Color(1.0, 0.42, 0.1)
const SMOKE := Color(0.32, 0.3, 0.28, 0.7)
const HEAL := Color(0.55, 1.0, 0.6)
const SHADOW := Color(0.2, 0.05, 0.3, 0.9)
const TOP := 0.6   # độ cao vẽ hạt: trên mọi sprite phẳng

static var _dot_tex: GradientTexture2D

var _fire: Dictionary = {}   # ô -> CPUParticles3D lửa đang cháy
var _channel: CPUParticles3D

## Chấm tròn mềm, dùng chung cho mọi hạt.
static func _dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(0.5, 0.0)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex

static func _pos(p: Vector2i) -> Vector3:
	return LevelBuilder.world_pos(p, TOP)

func _particles(at: Vector3, color: Color, amount: int, life: float, speed: float, size: float, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed
	p.damping_max = speed * 1.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _dot()
	m.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

## Bật đèn, nhặt đèn, Mồi lửa.
func spark(p: Vector2i) -> void:
	_particles(_pos(p), SPARK, 28, 0.55, 2.4, 0.12)
	_particles(_pos(p), EMBER, 10, 0.8, 1.2, 0.2)

## Tắt đèn: khói xám tỏa chậm.
func smoke(p: Vector2i) -> void:
	_particles(_pos(p), SMOKE, 14, 0.9, 0.6, 0.3, false)

## Bụi dưới chân mỗi bước / hộp bị đẩy.
func dust(p: Vector2i, amount := 6) -> void:
	var d := _particles(_pos(p) + Vector3(0, -0.3, 0.3), Color(0.55, 0.5, 0.42, 0.5), amount, 0.45, 0.7, 0.14, false)
	d.flatness = 1.0

## Đèn đôi: vòng tia sáng xoáy quanh người.
func swirl(p: Vector2i) -> void:
	var s := _particles(_pos(p), SPARK, 36, 0.7, 0.2, 0.1)
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	s.emission_ring_axis = Vector3.UP
	s.emission_ring_radius = 0.55
	s.emission_ring_inner_radius = 0.45
	s.emission_ring_height = 0.0
	s.tangential_accel_min = 6.0
	s.tangential_accel_max = 8.0
	s.explosiveness = 0.6

## Nuốt sáng: bóng tối từ quanh đèn bị hút vào tâm.
func implode(p: Vector2i) -> void:
	var s := _particles(_pos(p), SHADOW, 40, 0.6, 0.0, 0.3, false)
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 1.2
	s.radial_accel_min = -7.0
	s.radial_accel_max = -5.0
	s.explosiveness = 0.3

## Bức tường lửa: chai dầu bay theo đường vòng (to lên rồi nhỏ lại vì camera nhìn thẳng xuống), vỡ ra tia lửa.
func throw(from: Vector2i, to: Vector2i) -> void:
	var bottle := _particles(_pos(from), EMBER, 12, 0.25, 0.3, 0.2)
	bottle.one_shot = false
	bottle.explosiveness = 0.0
	var tw := create_tween()
	tw.tween_property(bottle, "position", _pos(to), 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(bottle, "scale", Vector3.ONE * 2.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bottle, "scale", Vector3.ONE, 0.15).set_delay(0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_particles(_pos(to), SPARK, 40, 0.6, 3.0, 0.14)
		bottle.queue_free())

## Ô đang cháy (GridState.fire_tiles): thêm lửa ô mới, ô tắt thì ngừng phun và tự dọn khi hạt cuối tàn.
func sync_fire(tiles: Array) -> void:
	for p in _fire.keys():
		if p not in tiles:
			_fire[p].emitting = false
			_fire.erase(p)
	for p in tiles:
		if _fire.has(p):
			continue
		var f := _particles(_pos(p), EMBER, 48, 0.7, 0.5, 0.35)
		f.one_shot = false
		f.explosiveness = 0.0
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		f.emission_box_extents = Vector3(0.45, 0.0, 0.45)
		f.spread = 35.0
		var ramp := Gradient.new()   # vàng trắng ở lõi, đỏ rồi tàn
		ramp.set_color(0, Color(1.0, 0.9, 0.5))
		ramp.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
		ramp.add_point(0.4, Color(1.0, 0.45, 0.1, 0.9))
		f.color_ramp = ramp
		var c := Curve.new()   # bùng lên rồi co lại
		c.add_point(Vector2(0, 0.4))
		c.add_point(Vector2(0.3, 1.0))
		c.add_point(Vector2(1, 0.2))
		f.scale_amount_curve = c
		_fire[p] = f

## Băng bó: hạt xanh bay quanh người suốt lúc băng, gắn vào node người chơi để đi theo.
func channel(on: bool, owner_node: Node3D) -> void:
	if on == (_channel != null):
		return
	if not on:
		_channel.emitting = false
		_channel = null
		return
	_channel = _particles(Vector3(0, TOP, 0), HEAL, 24, 0.9, 0.3, 0.12)
	_channel.one_shot = false
	_channel.explosiveness = 0.0
	_channel.local_coords = true
	_channel.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_channel.emission_ring_axis = Vector3.UP
	_channel.emission_ring_radius = 0.5
	_channel.emission_ring_inner_radius = 0.3
	_channel.emission_ring_height = 0.0
	_channel.tangential_accel_min = 2.0
	_channel.tangential_accel_max = 3.0
	_channel.reparent(owner_node, false)

## Chữ nổi (hồi máu, mất máu): trôi lên phía trên màn hình (-z) rồi mờ dần.
func float_text(p: Vector2i, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = Hud.title_font
	l.position = _pos(p) + Vector3(0, 0.3, -0.4)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:z", l.position.z - 0.8, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.tween_callback(l.queue_free)
