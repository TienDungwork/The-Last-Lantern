extends "res://tests/lib/test_case.gd"

func test_load_level_0() -> void:
	var L := LevelData.load_level(0)
	eq(L.width, 19, "width")
	eq(L.height, 22, "height")
	eq(L.start, Vector2i(6, 4), "start")
	eq(L.name_id, 211, "tên màn = Bar")
	eq(L.lights.size(), 19, "số đèn")
	eq(L.events.size(), 78, "số sự kiện")
	eq(L.grid[4][8], 0x38, "tường")
	eq(L.grid[4][6], 0, "sàn")
	eq(int(L.lights[1].x), 6, "light#1 x")
	eq(int(L.events[7].commands[0].op), 10, "event#7 lệnh đầu là PICKUP")

func test_tile_props() -> void:
	eq(int(LevelData.tile_props(0x38).solid), 1, "tường chắn đường")
	eq(int(LevelData.tile_props(0x38).blocks_light), 1, "tường chắn sáng")
	eq(int(LevelData.tile_props(0x43).movable), 1, "hộp đẩy được")
	eq(int(LevelData.tile_props(0x43).dim_light), 1, "hộp chắn sáng một phần")
	eq(int(LevelData.tile_props(0).solid), 0, "sàn không chắn")

func test_strings() -> void:
	ok(LevelData.text(211, "en").contains("Bar"), "chuỗi 211 tiếng Anh")
	eq(LevelData.text(211, "vi").is_empty(), false, "chuỗi 211 tiếng Việt có nội dung")
