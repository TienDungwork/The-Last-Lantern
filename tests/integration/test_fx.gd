extends "res://tests/lib/test_case.gd"
## FxView headless: mọi hiệu ứng chạy không lỗi, hạt một lần tự dọn, lửa theo đúng ô đang cháy.

func test_actor_glides_between_tiles() -> void:
	var actor := ActorView.new()
	tree.root.add_child(actor)
	actor.snap_to(Vector2i(0, 0))
	actor.move_to(Vector2i(1, 0))
	await tree.create_timer(ActorView.STEP_TIME / 2).timeout
	ok(actor.position.x > 0.2 and actor.position.x < 0.9, "giữa đường: x=%.2f" % actor.position.x)
	actor.move_to(Vector2i(2, 0))   # bước tiếp tới trước khi tới ô: trượt tiếp, không giật về
	await tree.create_timer(ActorView.STEP_TIME * 2).timeout
	eq(actor.position, LevelBuilder.world_pos(Vector2i(2, 0)), "tới ô đích")
	actor.free()

func test_effects_run_and_clean_up() -> void:
	var fx := FxView.new()
	var actor := ActorView.new()
	tree.root.add_child(fx)
	tree.root.add_child(actor)
	var p := Vector2i(3, 3)
	fx.spark(p)
	fx.smoke(p)
	fx.dust(p)
	fx.swirl(p)
	fx.implode(p)
	fx.throw(p, p + Vector2i(4, 0))
	fx.float_text(p, "+10", FxView.HEAL)
	fx.channel(true, actor)
	ok(fx._channel.get_parent() == actor, "băng bó: hạt đi theo người chơi")
	fx.channel(false, actor)
	fx.sync_fire([p, p + Vector2i(0, 1)])
	eq(fx._fire.size(), 2, "2 ô lửa")
	fx.sync_fire([p])
	eq(fx._fire.keys(), [p], "ô tắt thì bỏ")
	actor.bump(1)
	actor.pop()
	fx.sync_fire([])
	await tree.create_timer(1.0).timeout   # hạt một lần tàn, chữ nổi và chai dầu tự gỡ
	eq(fx._fire.size(), 0, "hết lửa")
	eq(actor.hop, 0.0, "nảy xong về chỗ")
	eq(actor.nudge, Vector3.ZERO, "xô tường xong về chỗ")
	fx.free()
	actor.free()
