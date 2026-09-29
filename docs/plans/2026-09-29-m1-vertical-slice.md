# M1: Bản thử màn 0 (Quán rượu) trên Godot 4

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Mark each step complete as you go.

**Mục tiêu:** Chơi được màn 0 ở chế độ Cổ điển trong Godot: đi 4 hướng, tường chắn, ánh sáng từng ô tính đúng như bản gốc, đứng trong tối mất năng lượng, đi vào tờ giấy thì nhặt Note 1 và hiện hai câu thoại có chân dung, hình 3D tạm (khối hộp), có test headless và có bộ so sánh với bản gốc.

**Kiến trúc:** `core/` là logic thuần (không Node, không đồ họa), test bằng `godot --headless`. `view/` dựng cảnh 3D từ trạng thái `core`. `ui/` là hộp thoại và HUD. `game.gd` nối ba phần. Dữ liệu màn là JSON do `tools/export_data.py` sinh từ file `.dat` gốc, không sửa tay.

**Tài liệu liên quan:** thiết kế `docs/specs/2026-09-29-lantern-godot-design.md`; kế hoạch tổng `docs/plans/2026-09-29-master-plan.md`; giải mã dữ liệu `d:\ntiendung\games\tools\df2_decode.py`; code gốc `d:\ntiendung\games\darkest_fear_2_grim_243556\src\class_10.java`.

**Quy ước:** Thư mục dự án `d:\ntiendung\games\lantern_godot\` (đã có git). Mọi lệnh chạy trong thư mục đó bằng PowerShell. Biến `$godot` là đường dẫn tới file `Godot_v4.x-stable_win64_console.exe` (Task 0). Tọa độ ô là `(x, y)`, `grid[y][x]`. Hướng: 1 phải, 2 xuống, 3 trái, 4 lên (giữ mã của game gốc).

---

## Task 0: Cài Godot, khung dự án, bộ chạy test

**Files:**
- Create: `project.godot`, `.gitignore`, `tests/run.gd`, `tests/test_base.gd`, `tests/test_smoke.gd`, `tools/godot.ps1`

- [ ] **Bước 1: Cài Godot 4 bản stable (không phải .NET)**

```powershell
winget install --id GodotEngine.GodotEngine -e --accept-source-agreements --accept-package-agreements
$godot = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4*console.exe" | Select-Object -First 1).FullName
& $godot --version
```
Kết quả mong đợi: một dòng dạng `4.4.1.stable.official.xxxxxxx` (4.4 hoặc mới hơn). Nếu `Get-ChildItem` không thấy file, tìm trong `C:\Program Files\Godot\`. Phải dùng bản `_console.exe` thì stdout mới in ra PowerShell.

- [ ] **Bước 2: Lưu đường dẫn Godot vào script dùng chung**

`tools/godot.ps1`:
```powershell
# Trả về đường dẫn Godot console exe. Dùng: $godot = & .\tools\godot.ps1
$g = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "C:\Program Files\Godot" -Recurse -Filter "Godot_v4*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $g) { throw "Chưa cài Godot 4. Chạy: winget install GodotEngine.GodotEngine" }
$g.FullName
```

- [ ] **Bước 3: Tạo `project.godot` và `.gitignore`**

`project.godot`:
```ini
; Engine configuration file.
config_version=5

[application]

config/name="The Last Lantern II"
run/main_scene="res://game.tscn"
config/features=PackedStringArray("4.4", "Forward Plus")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720

[rendering]

renderer/rendering_method="forward_plus"
```

`.gitignore`:
```
.godot/
snap/
export/
*.import.tmp
```

- [ ] **Bước 4: Viết lớp test cơ sở**

`tests/test_base.gd`:
```gdscript
## Lớp cha cho mọi file test. Không dùng assert (assert dừng cả tiến trình);
## gom lỗi vào `errors` để runner in đủ mọi lỗi.
extends RefCounted

var errors: Array[String] = []

func eq(got: Variant, want: Variant, msg: String = "") -> void:
	if got != want:
		errors.append("%s: muốn %s, nhận %s" % [msg, str(want), str(got)])

func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
```

- [ ] **Bước 5: Viết runner**

`tests/run.gd`:
```gdscript
## Chạy: & $godot --headless --path . -s res://tests/run.gd
## Tìm mọi tests/test_*.gd, tạo instance, gọi mọi hàm test_*; in PASS/FAIL, thoát mã 1 nếu có lỗi.
extends SceneTree

func _init() -> void:
	var failed := 0
	var passed := 0
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_base.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		var t: Object = script.new()
		for m in t.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			t.errors.clear()
			t.call(m.name)
			if t.errors.is_empty():
				passed += 1
				print("PASS %s.%s" % [f, m.name])
			else:
				failed += 1
				print("FAIL %s.%s" % [f, m.name])
				for e in t.errors:
					print("    " + e)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
```

- [ ] **Bước 6: Test khói**

`tests/test_smoke.gd`:
```gdscript
extends "res://tests/test_base.gd"

func test_runner_works() -> void:
	eq(1 + 1, 2, "số học")
```

- [ ] **Bước 7: Import dự án lần đầu rồi chạy test**

```powershell
cd d:\ntiendung\games\lantern_godot
$godot = & .\tools\godot.ps1
& $godot --headless --path . --import
& $godot --headless --path . -s res://tests/run.gd
```
Kết quả mong đợi: `PASS test_smoke.gd.test_runner_works` và `1 passed, 0 failed`, `$LASTEXITCODE` = 0.
Lưu ý: mỗi khi thêm file `.gd` có `class_name` mới, chạy lại `--import` để Godot cập nhật bảng lớp toàn cục.

- [ ] **Bước 8: Commit**

```powershell
git add -A; git commit -m "M1 T0: Godot project skeleton + headless test runner"
```

---

## Task 1: Xuất dữ liệu game gốc sang `data/`

**Files:**
- Create: `tools/export_data.py`, `tools/check_data.py`
- Output: `data/levels/00.json`…`18.json`, `data/tiles.json`, `data/strings_en.json`, `data/strings_vi.json`, `data/citymap.json`, `data/frames.json`, `data/items.json`, `data/floor_frames.json`, `assets/original/*.png`

- [ ] **Bước 1: Viết test kiểm tra dữ liệu (chạy trước, phải fail vì chưa có file)**

`tools/check_data.py`:
```python
"""Kiểm tra data/ do export_data.py sinh ra. Chạy: python tools/check_data.py"""
import json
from pathlib import Path

D = Path(__file__).resolve().parents[1] / "data"
levels = sorted((D / "levels").glob("*.json"))
assert len(levels) == 19, f"cần 19 màn, có {len(levels)}"
L0 = json.loads((D / "levels" / "00.json").read_text("utf-8"))
assert (L0["width"], L0["height"]) == (19, 22), L0["width"]
assert L0["start"] == [6, 4]
assert len(L0["lights"]) == 19 and len(L0["events"]) == 78
assert L0["grid"][4][8] == 0x38 and L0["grid"][4][6] == 0, "tường (8,4), sàn (6,4)"
tiles = json.loads((D / "tiles.json").read_text("utf-8"))
assert tiles["56"] == {"solid": 1, "blocks_light": 1, "dim_light": 0, "movable": 0}
assert tiles["67"]["movable"] == 1, "0x43 là hộp"
for lang in ("en", "vi"):
    s = json.loads((D / f"strings_{lang}.json").read_text("utf-8"))
    assert len(s) == 258, lang
assert "Bar" in json.loads((D / "strings_en.json").read_text("utf-8"))[211]
frames = json.loads((D / "frames.json").read_text("utf-8"))
assert len(frames) == 435 and frames[171][0] == "av.png", "chân dung Hale"
items = json.loads((D / "items.json").read_text("utf-8"))
assert len(items) == 34 and items["0"]["name_id"] == 179
cm = json.loads((D / "citymap.json").read_text("utf-8"))
assert cm["width"] > 0 and len(cm["rows"]) == cm["height"]
assert (Path(__file__).resolve().parents[1] / "assets" / "original" / "av.png").exists()
print("data OK")
```

```powershell
python tools/check_data.py
```
Kết quả mong đợi: `AssertionError: cần 19 màn, có 0`.

- [ ] **Bước 2: Viết `tools/export_data.py` dùng lại bộ giải mã có sẵn**

```python
"""Sinh data/ cho bản Godot từ file gốc. Chạy: python tools/export_data.py
Dùng lại df2_decode.py (không chép code). Không sửa data/ bằng tay."""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]                 # lantern_godot/
GAME = ROOT.parent / "darkest_fear_2_grim_243556"          # thư mục game gốc
sys.path.insert(0, str(ROOT.parent / "tools"))
import df2_decode as dec  # noqa: E402

PNGS = ["av", "aw", "ax", "ay", "az", "ba", "bb", "bc", "bd", "be", "bg", "bh", "bi", "bj", "bk",
        "bl", "bm", "bn", "bo", "bp", "bq", "bs", "bt", "bv"]


def dump(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=0), "utf-8")


def parse_text(path: Path) -> list[str]:
    """text_*.txt: mỗi dòng `[N] nội dung`, `\\n` là xuống dòng trong game."""
    out = [""] * 258
    for line in path.read_text("utf-8").splitlines():
        if line.startswith("[") and "] " in line:
            n, s = line[1:].split("] ", 1)
            out[int(n)] = s.replace("\\n", "\n")
    return out


def main() -> None:
    S = dec.load_strings(GAME)
    for i, name in enumerate(dec.LEVEL_FILES):
        b = (GAME / f"{name}.dat").read_bytes()
        if i == 19:
            dump(ROOT / "data" / "citymap.json", dec.decode_citymap(b))
            continue
        L = dec.decode_level(b, S)
        assert L["bytes_used"] == L["bytes_total"], name
        dump(ROOT / "data" / "levels" / f"{i:02d}.json", {
            "index": i, "name_id": L["ambient"], "width": L["width"], "height": L["height"],
            "tileset": L["tileset"], "start": L["start"], "grid": L["grid"], "lights": L["lights"],
            "events": [{k: e[k] for k in ("id", "x", "y", "w", "h", "flags")}
                       | {"commands": [{"op": c["op"], "args": c["args"], "text": c["text"]} for c in e["commands"]]}
                       for e in L["events"]],
        })
    G = dec.decode_global((GAME / "dc.dat").read_bytes())
    dump(ROOT / "data" / "tiles.json", {str(p["tile"]): {"solid": p["b0"], "blocks_light": p["b1"],
                                                          "dim_light": p["b2"], "movable": p["movable_object"]}
                                         for p in G["tile_props"]})
    dump(ROOT / "data" / "map_markers.json", G["map_markers"])
    dump(ROOT / "data" / "frames.json", dec.decode_frames((GAME / "r").read_bytes()))
    dump(ROOT / "data" / "items.json", {str(i): {"name_id": n, "frame": f}
                                        for i, (n, f) in enumerate(zip(dec.ITEM_NAME, dec.ITEM_FRAME))})
    dump(ROOT / "data" / "floor_frames.json", dec.FLOOR_FRAMES)
    dump(ROOT / "data" / "strings_en.json", parse_text(GAME / "text_English.txt"))
    dump(ROOT / "data" / "strings_vi.json", parse_text(GAME / "text_TiengViet.txt"))
    (ROOT / "assets" / "original").mkdir(parents=True, exist_ok=True)
    for p in PNGS:
        shutil.copy(GAME / f"{p}.png", ROOT / "assets" / "original" / f"{p}.png")
    print("exported 19 levels, city map, tiles, frames, strings, %d png" % len(PNGS))


if __name__ == "__main__":
    main()
```

- [ ] **Bước 3: Chạy xuất và kiểm tra**

```powershell
python tools/export_data.py
python tools/check_data.py
```
Kết quả mong đợi: `exported 19 levels, ...` rồi `data OK`. Nếu `frames[171][0]` không phải `av.png`, xem lại bảng khung hình trong `decode_frames`; không sửa test cho khớp.

- [ ] **Bước 4: Commit**

```powershell
git add -A; git commit -m "M1 T1: export original data to data/ and assets/original"
```

---

## Task 2: `core/level_data.gd` đọc JSON màn

**Files:**
- Create: `core/level_data.gd`, `tests/test_level_data.gd`

- [ ] **Bước 1: Test**

`tests/test_level_data.gd`:
```gdscript
extends "res://tests/test_base.gd"

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
	eq(LevelData.tile_props(0x38).solid, 1, "tường chắn đường")
	eq(LevelData.tile_props(0x38).blocks_light, 1, "tường chắn sáng")
	eq(LevelData.tile_props(0x43).movable, 1, "hộp đẩy được")
	eq(LevelData.tile_props(0x43).dim_light, 1, "hộp chắn sáng một phần")
	eq(LevelData.tile_props(0).solid, 0, "sàn không chắn")

func test_strings() -> void:
	ok(LevelData.text(211, "en").contains("Bar"), "chuỗi 211 tiếng Anh")
	eq(LevelData.text(211, "vi").is_empty(), false, "chuỗi 211 tiếng Việt có nội dung")
```

- [ ] **Bước 2: Chạy test, phải fail**

```powershell
& $godot --headless --path . --import; & $godot --headless --path . -s res://tests/run.gd
```
Kết quả mong đợi: lỗi parse `LevelData` không tồn tại (runner in FAIL hoặc Godot báo lỗi script).

- [ ] **Bước 3: Cài `core/level_data.gd`**

```gdscript
class_name LevelData
extends RefCounted
## Dữ liệu tĩnh của một màn (data/levels/NN.json) và các bảng dùng chung.
## Không đổi trong lúc chơi; trạng thái động nằm ở GridState.

var index: int
var width: int
var height: int
var tileset: int
var name_id: int
var start: Vector2i
var grid: Array = []      # grid[y][x] -> int; <8 = sàn, >=8 = vật thể (khung hình = giá trị - 8)
var lights: Array = []    # Dictionary {x, y, type, on, radius, dir}
var events: Array = []    # Dictionary {id, x, y, w, h, flags, commands: [{op, args, text}]}

static var _tiles: Dictionary = {}
static var _strings: Dictionary = {}   # lang -> Array[String]

static func read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "không mở được " + path)
	var v: Variant = JSON.parse_string(f.get_as_text())
	assert(v != null, "JSON hỏng: " + path)
	return v

static func load_level(n: int) -> LevelData:
	var d: Dictionary = read_json("res://data/levels/%02d.json" % n)
	var L := LevelData.new()
	L.index = n
	L.width = int(d.width)
	L.height = int(d.height)
	L.tileset = int(d.tileset)
	L.name_id = int(d.name_id)
	L.start = Vector2i(int(d.start[0]), int(d.start[1]))
	for row in d.grid:
		var r := PackedInt32Array()
		for t in row:
			r.append(int(t))
		L.grid.append(r)
	L.lights = d.lights
	L.events = d.events
	return L

static func tile_props(tile: int) -> Dictionary:
	if _tiles.is_empty():
		_tiles = read_json("res://data/tiles.json")
	return _tiles.get(str(tile), {"solid": 0, "blocks_light": 0, "dim_light": 0, "movable": 0})

static func text(id: int, lang: String = "vi") -> String:
	if not _strings.has(lang):
		_strings[lang] = read_json("res://data/strings_%s.json" % lang)
	return _strings[lang][id]
```

- [ ] **Bước 4: Chạy test, phải pass**

```powershell
& $godot --headless --path . --import; & $godot --headless --path . -s res://tests/run.gd
```
Kết quả mong đợi: `4 passed, 0 failed`.

- [ ] **Bước 5: Commit**

```powershell
git add -A; git commit -m "M1 T2: LevelData loads level JSON, tile props, strings"
```

---

## Task 3: `core/grid_state.gd`: trạng thái động và va chạm

**Files:**
- Create: `core/grid_state.gd`, `core/script_vm.gd` (khung rỗng, Task 6 hoàn thiện), `tests/test_grid_state.gd`

- [ ] **Bước 1: Test**

`tests/test_grid_state.gd`:
```gdscript
extends "res://tests/test_base.gd"

func _state() -> GridState:
	return GridState.new(LevelData.load_level(0))

func test_spawn_at_header_start() -> void:
	var s := _state()
	eq(s.player, Vector2i(6, 4), "vị trí đầu")
	eq(s.energy, s.max_energy, "đầy năng lượng")
	eq(s.inventory.size(), 0, "túi rỗng")

func test_solid() -> void:
	var s := _state()
	eq(s.is_solid(Vector2i(8, 4)), true, "tường 0x38")
	eq(s.is_solid(Vector2i(7, 4)), false, "sàn")
	eq(s.is_solid(Vector2i(5, 3)), true, "tờ giấy 0x5a là vật thể")
	eq(s.is_solid(Vector2i(-1, 0)), true, "ngoài biên coi như tường")
	eq(s.is_solid(Vector2i(0, 22)), true, "ngoài biên dưới")

func test_event_active_from_flags() -> void:
	var s := _state()
	eq(s.event_active[7], true, "event#7 active (flags 62)")
	eq(s.event_active.size(), 78, "một cờ mỗi sự kiện")
```

- [ ] **Bước 2: Chạy test, phải fail** (`GridState` chưa có).

- [ ] **Bước 3: Khung `core/script_vm.gd`** (để GridState biên dịch được; Task 6 điền lệnh)

```gdscript
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
```

- [ ] **Bước 4: Cài `core/grid_state.gd`**

```gdscript
class_name GridState
extends RefCounted
## Trạng thái động của màn đang chơi: vị trí, năng lượng, túi đồ, ô đã đổi, đèn, cờ sự kiện.
## Không có gì về đồ họa. Mỗi hành động trả về danh sách "out" (Dictionary) cho view/ui xử lý.

const DIR_VEC := {1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0), 4: Vector2i(0, -1)}
# Cờ sự kiện: 1 repeat, 2 active, 4 from_down, 8 from_left, 16 from_up, 32 from_right, 64 by_actor, 128 on_action
const F_REPEAT := 1
const F_ACTIVE := 2
const F_BY_ACTOR := 64
const F_ON_ACTION := 128
# Hướng người chơi đang đi -> cờ "vào từ phía": đi lên (4) là vào ô đích từ phía dưới (bit 4).
# ponytail: giả định từ tên cờ; Task 13 so với bản gốc, sai thì đổi bảng này.
const ENTER_FLAG := {4: 4, 1: 8, 2: 16, 3: 32}
const OUT_OF_BOUNDS_TILE := 8 + 48   # 0x38, tường

var level: LevelData
var tiles: Array = []            # bản sao có thể đổi của level.grid
var lights: Array = []           # bản sao có thể đổi của level.lights
var event_active: Array = []     # bool theo event id
var player: Vector2i
var facing: int = 2
var control: bool = true
var max_energy: int = 5          # ponytail: giá trị khởi đầu xác nhận ở Task 13 (field_152 bản gốc)
var energy: int = 5
var inventory: Array[int] = []
var equipped: int = -1
var out: Array = []
var vm: ScriptVM

func _init(L: LevelData, spawn: Vector2i = Vector2i(-1, -1)) -> void:
	level = L
	for row in L.grid:
		tiles.append(PackedInt32Array(row))
	for l in L.lights:
		lights.append(l.duplicate())
	for e in L.events:
		event_active.append(bool(int(e.flags) & F_ACTIVE))
	player = spawn if spawn.x >= 0 else L.start
	energy = max_energy
	vm = ScriptVM.new(self)

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < level.width and p.y < level.height

func tile_at(p: Vector2i) -> int:
	return tiles[p.y][p.x] if in_bounds(p) else OUT_OF_BOUNDS_TILE

func is_solid(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t >= 8 and int(LevelData.tile_props(t).solid) == 1

func events_at(p: Vector2i, moving_dir: int) -> Array:
	## Sự kiện đang bật, phủ ô p, cho phép vào theo hướng đang đi, không phải loại by_actor/on_action.
	var r := []
	for e in level.events:
		if not event_active[int(e.id)]:
			continue
		var flags := int(e.flags)
		if flags & (F_BY_ACTOR | F_ON_ACTION):
			continue
		if p.x < int(e.x) or p.y < int(e.y) or p.x >= int(e.x) + int(e.w) or p.y >= int(e.y) + int(e.h):
			continue
		if not (flags & ENTER_FLAG[moving_dir]):
			continue
		r.append(e)
	return r

func step(dir: int) -> Array:
	## Một lượt đi của người chơi. Đi trước (nếu không chắn), rồi chạy sự kiện tại ô đích
	## (chạy cả khi bị chắn: "đi về phía tờ giấy để đọc"). Trả về out cho view.
	out.clear()
	if not control:
		return out
	facing = dir
	var target: Vector2i = player + DIR_VEC[dir]
	if is_solid(target):
		out.append({"type": "bumped", "dir": dir})
	else:
		player = target
		out.append({"type": "moved", "to": player, "dir": dir})
	for e in events_at(target, dir):
		vm.run(e)
		if not (int(e.flags) & F_REPEAT):
			event_active[int(e.id)] = false
	return out
```

- [ ] **Bước 5: Chạy test, phải pass** (`7 passed, 0 failed`).

- [ ] **Bước 6: Commit**

```powershell
git add -A; git commit -m "M1 T3: GridState with collision and event flags"
```

---

## Task 4: Di chuyển và kích hoạt sự kiện theo hướng

**Files:**
- Modify: `core/script_vm.gd`, `tests/test_grid_state.gd`

- [ ] **Bước 1: Thêm test**

Thêm vào `tests/test_grid_state.gd`:
```gdscript
func test_move_and_bump() -> void:
	var s := _state()
	var o := s.step(1)
	eq(s.player, Vector2i(7, 4), "đi phải một ô")
	eq(o[0].type, "moved", "báo moved")
	o = s.step(1)
	eq(s.player, Vector2i(7, 4), "tường (8,4) chắn")
	eq(o[0].type, "bumped", "báo bumped")
	eq(s.facing, 1, "vẫn quay mặt phải")

func test_no_control_no_move() -> void:
	var s := _state()
	s.control = false
	s.step(2)
	eq(s.player, Vector2i(6, 4), "mất điều khiển thì đứng yên")

func test_event_fires_once_when_not_repeat() -> void:
	# event#7 (5,3) flags 62: active, mọi hướng, không repeat. Đi từ (5,4) lên -> chạm tờ giấy.
	var s := GridState.new(LevelData.load_level(0), Vector2i(5, 4))
	s.vm = _CountingVM.new(s)
	s.step(4)
	eq(s.player, Vector2i(5, 4), "tờ giấy là vật thể, không đi vào được")
	eq(s.vm.runs, 1, "sự kiện chạy")
	eq(s.event_active[7], false, "không repeat thì tắt")
	s.step(4)
	eq(s.vm.runs, 1, "không chạy lần hai")

func test_event_direction_filter() -> void:
	# event#2 (12,11) flags 19 = repeat|active|from_up; event#48 cùng ô nhận mọi hướng.
	var s := GridState.new(LevelData.load_level(0), Vector2i(12, 12))
	var ids_up := s.events_at(Vector2i(12, 11), 4).map(func(e): return int(e.id))
	var ids_down := s.events_at(Vector2i(12, 11), 2).map(func(e): return int(e.id))
	eq(ids_up.has(2), false, "đi lên = vào từ dưới: #2 không khớp from_up")
	eq(ids_up.has(48), true, "#48 mọi hướng vẫn khớp")
	eq(ids_down.has(2), true, "đi xuống = vào từ trên: #2 khớp")

class _CountingVM extends ScriptVM:
	var runs := 0
	func run(_e: Dictionary) -> void:
		runs += 1
```

- [ ] **Bước 2: Chạy test**

Kết quả mong đợi: `test_move_and_bump`, `test_no_control_no_move`, `test_event_direction_filter` pass ngay (logic có ở Task 3); `test_event_fires_once_when_not_repeat` pass vì dùng VM đếm. Nếu `test_event_direction_filter` fail, kiểm tra lại bảng `ENTER_FLAG`, không đổi test.

- [ ] **Bước 3: Commit**

```powershell
git add -A; git commit -m "M1 T4: movement, bump, directional event triggering tests"
```

---

## Task 5: `core/light_field.gd`: độ sáng từng ô (chuyển từ `method_151/152`)

Nguồn: `class_10.java` dòng 3648–3725 (`method_151`: quét 4 tia từ 4 góc nửa ô), 3728–3842 (`method_152`: một tia, trả về "khoảng cách suy giảm", 100 = chắn, 40 = chắn một phần), 3532–3575 (cộng các đèn, kẹp 7). Hằng `field_224`/`field_225` dòng 243–245.

**Files:**
- Create: `core/light_field.gd`, `tests/test_light_field.gd`

- [ ] **Bước 1: Test**

`tests/test_light_field.gd`:
```gdscript
extends "res://tests/test_base.gd"

func _state() -> GridState:
	return GridState.new(LevelData.load_level(0))

func test_shape() -> void:
	var m := LightField.compute(_state())
	eq(m.size(), 22, "22 hàng")
	eq(m[0].size(), 19, "19 cột")

func test_lit_near_lamp_dark_far() -> void:
	# light#1: (6,5) type 4 on radius 4. Start (6,4) sát đèn.
	var m := LightField.compute(_state())
	ok(m[4][6] > 0, "ô start sáng")
	ok(m[4][6] <= 7, "kẹp 7")
	eq(m[20][2], 0, "góc xa (2,20) tối")

func test_wall_blocks_light() -> void:
	# Tường cột x=8 (0x38) chắn giữa đèn (6,5) và ô (9,5)? (9,5) có thể được đèn khác chiếu,
	# nên tắt hết đèn trừ light#1 rồi so hai bên tường.
	var s := _state()
	for i in s.lights.size():
		if i != 1:
			s.lights[i].on = 0
	var m := LightField.compute(s)
	ok(m[5][7] > 0, "(7,5) cùng phòng với đèn: sáng")
	eq(m[5][9], 0, "(9,5) sau tường (8,5): tối")
	eq(m[5][8], 0, "ô tường luôn 0")

func test_all_off_all_dark() -> void:
	var s := _state()
	for l in s.lights:
		l.on = 0
	var m := LightField.compute(s)
	var total := 0
	for row in m:
		for v in row:
			total += v
	eq(total, 0, "không đèn thì toàn tối")

func test_directional_light_has_no_back() -> void:
	# light#11: (12,12) type 6 dir 2 on radius 3. Sàn hai bên: (11,12) và (13,12).
	# Theo method_152, dir 2 chắn mọi ô có x nhỏ hơn đèn -> (11,12) tối, (13,12) sáng.
	var s := _state()
	for l in s.lights:
		l.on = 0
	s.lights[11].on = 1
	var m := LightField.compute(s)
	eq(m[12][11], 0, "phía sau đèn có hướng: tối")
	ok(m[12][13] > 0, "phía trước đèn có hướng: sáng")
```
Ghi chú: `dir` của đèn dùng mã riêng của bản gốc (không phải mã hướng đi). Nếu Task 13 cho thấy bản gốc chiếu theo trục khác, đổi cả `_ray` và test này cùng lúc, kèm số liệu trace trong commit.

- [ ] **Bước 2: Chạy test, phải fail** (`LightField` chưa có).

- [ ] **Bước 3: Cài `core/light_field.gd`**

```gdscript
class_name LightField
extends RefCounted
## Độ sáng từng ô 0..7, chuyển nguyên thuật toán từ class_10.method_151/152 (game gốc).
## Tọa độ "nửa ô": ô (x,y) chiếm nửa ô 2x..2x+1. Mỗi ô sàn nhận 4 tia từ 4 góc đèn tới 4 góc ô.

const CORNERS := [0, 0, 0, 0,  1, 0, 1, 0,  1, 1, 1, 1,  0, 1, 0, 1]        # field_224 (đèn tỏa)
const CORNERS_DIR := [0, 0, 1, 1,  1, 0, 0, 1,  1, 1, 0, 0,  0, 1, 1, 0]    # field_225 (đèn có hướng)
const BLOCKED := 100
const DIMMED := 40
const MAX_LEVEL := 7

static func compute(s: GridState) -> Array:
	## Trả về map[y][x]; ô vật thể = 0.
	var w := s.level.width
	var h := s.level.height
	var sum: Array = []
	for y in h:
		var row := PackedInt32Array()
		row.resize(w)
		sum.append(row)
	for L in s.lights:
		if int(L.on) == 0 or int(L.radius) <= 0:
			continue
		var lx := int(L.x)
		var ly := int(L.y)
		var r := int(L.radius)
		var dir := int(L.dir)
		var type := int(L.type)
		var corners: Array = CORNERS_DIR if dir != 0 else CORNERS
		for y in range(maxi(ly - r + 1, 0), mini(ly + r, h)):
			for x in range(maxi(lx - r + 1, 0), mini(lx + r, w)):
				if s.tiles[y][x] >= 8:
					continue
				var acc := 0
				for k in range(0, 16, 4):
					var d := _ray(s, (x << 1) + corners[k], (y << 1) + corners[k + 1],
						(lx << 1) + corners[k + 2], (ly << 1) + corners[k + 3], dir, r << 1, type, lx, ly)
					if d < (r << 1):
						acc += r - (d >> 1)
				sum[y][x] += mini(acc >> 2, MAX_LEVEL)
	for y in h:
		for x in w:
			sum[y][x] = mini(sum[y][x], MAX_LEVEL)
	return sum

@warning_ignore("integer_division")
static func _ray(s: GridState, tx: int, ty: int, lx: int, ly: int, dir: int, rng: int, type: int,
		light_tile_x: int, light_tile_y: int) -> int:
	## method_152: (tx,ty) góc ô đích, (lx,ly) góc đèn, cả hai ở tọa độ nửa ô. rng = radius*2.
	var dx := absi(tx - lx)
	var dy := absi(ty - ly)
	if dx > rng or dy > rng:
		return BLOCKED
	var spread := 2 if (type == 1 or type == 5) else 0
	var sx := signi(tx - lx)
	var sy := signi(ty - ly)
	match dir:
		1:
			if sy == -1 or spread * dx > dy:
				return BLOCKED
		2:
			if sx == -1 or spread * dy > dx:
				return BLOCKED
		3:
			if sy == 1 or spread * dx > dy:
				return BLOCKED
		4:
			if sx == 1 or spread * dy > dx:
				return BLOCKED
	var n := maxi(dx, dy)
	for i in n:
		var px: int
		var py: int
		if dx > dy:
			px = lx + i * sx
			py = ly + ((i * ((dy << 6) / dx)) >> 6) * sy
		elif dx < dy:
			px = lx + ((i * ((dx << 6) / dy)) >> 6) * sx
			py = ly + i * sy
		else:
			px = lx + i * sx
			py = ly + i * sy
		var cx := px >> 1
		var cy := py >> 1
		if i == 0 or (i == 1 and cx == light_tile_x and cy == light_tile_y):
			continue   # bỏ ô của chính đèn (đèn treo trên vật thể)
		var t := s.tile_at(Vector2i(cx, cy))
		if t < 8:
			continue
		var p := LevelData.tile_props(t)
		if int(p.blocks_light) == 1:
			return BLOCKED
		if int(p.dim_light) == 1 and absi(px - tx) <= 1 and absi(py - ty) <= 1:
			return DIMMED
	# ponytail: bản gốc còn xét diễn viên/hộp đang mang (method_117) trên đường tia; M2 thêm khi có actor.
	return dx + dy * 40 / 100 if dx > dy else dy + dx * 40 / 100
```

- [ ] **Bước 4: Chạy test, phải pass** (`16 passed, 0 failed`). Nếu `test_wall_blocks_light` fail ở `(9,5)`, in `m[5]` ra để xem; khả năng cao là nhầm thứ tự `[y][x]` ở một chỗ. Không nới test.

- [ ] **Bước 5: Commit**

```powershell
git add -A; git commit -m "M1 T5: LightField ported from method_151/152"
```

---

## Task 6: `core/script_vm.gd`: các lệnh màn 0 dùng

Màn 0 dùng: 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30. Ở M1 cài đủ để chơi đến khi nhặt Note 1 và đi loanh quanh: 2, 3, 6, 7, 8, 9, 10, 11, 15, 16, 17, 19, 20, 21, 22, 23, 26, 27, 29, 30. Lệnh còn lại (4, 5, 12, 13, 14, 18, 24, 25, 28) ghi `out` loại `"todo"` kèm op để view in cảnh báo, không dừng game. M2 cài đủ.

Bảng đối số (từ `df2_decode.disasm`): 2 `[str, hi, lo]` chân dung = hi<<8|lo (0xFFFF = không); 6 `[x, y, level]`; 7 `[on]`; 8 `[dir, steps]` (dir 5 = đặc biệt, bỏ ở M1); 9 `[x, y, level|0x80 persist, tile]`; 10 `[item]` (255 = không); 11 `[item|0x80 = NOT]` sai thì dừng sự kiện; 16 `[x, y, level]`; 17 `[light, level, radius]`; 19 `[item]`; 20/21 `[event, level]`; 22 `[event]`; 23 `[light]`; 26 `[hi, lo]`; 27 `[mode, slot, ...]`; 29 `[hi, lo, dx, dy]`; 30 `[code]`.

**Files:**
- Modify: `core/script_vm.gd`
- Create: `tests/test_script_vm.gd`

- [ ] **Bước 1: Test**

`tests/test_script_vm.gd`:
```gdscript
extends "res://tests/test_base.gd"

func _say_ids(out: Array) -> Array:
	var r := []
	for o in out:
		if o.type == "say":
			r.append(o.text_id)
	return r

func test_read_note_1() -> void:
	# event#7 tại (5,3): PICKUP Note 1, SAY 228 (chân dung 325), SAY 7 (chân dung 171), DISABLE 21,22,23
	var s := GridState.new(LevelData.load_level(0), Vector2i(5, 4))
	var out := s.step(4)
	eq(s.inventory, [0], "nhặt Note 1 (item 0)")
	eq(_say_ids(out), [228, 7], "hai câu thoại đúng thứ tự")
	var says := out.filter(func(o): return o.type == "say")
	eq(says[0].portrait, 325, "chân dung Jack")
	eq(says[1].portrait, 171, "chân dung Hale")
	eq(s.event_active[21], false, "tắt #21")
	eq(s.event_active[22], false, "tắt #22")
	eq(s.event_active[23], false, "tắt #23")

func test_say_without_portrait() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 2, "args": [10, 255, 255]}]})
	eq(s.out[0].portrait, -1, "255,255 = không chân dung")

func test_player_control_and_move() -> void:
	# event#4 (9..10,1): control off, SAY 9, MOVE right 1, control on
	var s := GridState.new(LevelData.load_level(0), Vector2i(9, 1))
	s.vm.run(s.level.events[4])
	eq(s.player, Vector2i(10, 1), "kịch bản đẩy sang phải 1")
	eq(s.control, true, "trả lại điều khiển")

func test_if_holding_aborts() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 11, "args": [3]}, {"op": 2, "args": [10, 255, 255]}]})
	eq(s.out.size(), 0, "không cầm item 3 thì dừng, không SAY")
	s.inventory.append(3)
	s.vm.run({"commands": [{"op": 11, "args": [3]}, {"op": 2, "args": [10, 255, 255]}]})
	eq(s.out.size(), 1, "cầm rồi thì chạy tiếp")
	s.out.clear()
	s.vm.run({"commands": [{"op": 11, "args": [3 | 0x80]}, {"op": 2, "args": [10, 255, 255]}]})
	eq(s.out.size(), 0, "IF_NOT_HOLDING khi đang cầm thì dừng")

func test_set_tile_and_light() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 9, "args": [13, 2, 0, 82]}, {"op": 17, "args": [3, 0, 5]}]})
	eq(s.tiles[2][13], 82, "SET_TILE")
	eq(int(s.lights[3].radius), 5, "SET_LIGHT radius")
	eq(int(s.lights[3].on), 1, "SET_LIGHT bật đèn")

func test_teleport_same_level_and_exit_door() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.vm.run({"commands": [{"op": 6, "args": [3, 9, 0]}]})
	eq(s.player, Vector2i(3, 9), "TELEPORT trong màn")
	s.vm.run({"commands": [{"op": 16, "args": [4, 13, 5]}]})
	eq(s.out.back().type, "change_level", "exit_door sang màn khác")
	eq(s.out.back().level, 5, "màn 5")

func test_enable_call_take_and_unknown() -> void:
	var s := GridState.new(LevelData.load_level(0))
	s.event_active[21] = false
	s.vm.run({"commands": [{"op": 20, "args": [21, 0]}]})
	eq(s.event_active[21], true, "ENABLE_EVENT")
	s.inventory.append(5)
	s.vm.run({"commands": [{"op": 19, "args": [5]}]})
	eq(s.inventory.has(5), false, "TAKE_ITEM")
	s.vm.run({"commands": [{"op": 22, "args": [7]}]})
	eq(s.inventory.has(0), true, "CALL_EVENT #7 nhặt Note 1")
	s.out.clear()
	s.vm.run({"commands": [{"op": 12, "args": [1]}]})
	eq(s.out[0].type, "todo", "lệnh chưa cài báo todo, không dừng")
	eq(s.out[0].op, 12, "kèm mã lệnh")
```

- [ ] **Bước 2: Chạy test, phải fail** (mọi lệnh đều `push_error`).

- [ ] **Bước 3: Cài `core/script_vm.gd`**

```gdscript
class_name ScriptVM
extends RefCounted
## Chạy các lệnh kịch bản của một sự kiện lên GridState. Xem class_10.method_209 (bản gốc)
## và bảng đối số trong tools/df2_decode.py::disasm. Lệnh chưa cài -> out {"type":"todo"}.

const TODO_OPS := [1, 4, 5, 12, 13, 14, 18, 24, 25, 28]

var s: GridState

func _init(state: GridState) -> void:
	s = state

func run(e: Dictionary) -> void:
	for c in e.commands:
		if not _exec(int(c.op), c.args):
			return   # IF_HOLDING sai: dừng sự kiện

func _u16(hi: int, lo: int) -> int:
	var v := (hi << 8) | lo
	return -1 if v == 0xFFFF else v

func _same_level(v: int) -> bool:
	return (v & 0x7F) == s.level.index

func _exec(op: int, a: Array) -> bool:
	match op:
		2:
			s.out.append({"type": "say", "text_id": int(a[0]), "portrait": _u16(int(a[1]), int(a[2]))})
		3:
			s.energy = s.max_energy
		6:
			if _same_level(int(a[2])):
				s.player = Vector2i(int(a[0]), int(a[1]))
				s.out.append({"type": "teleported", "to": s.player})
			else:
				s.out.append({"type": "change_level", "level": int(a[2]) & 0x7F, "to": Vector2i(int(a[0]), int(a[1]))})
		7:
			s.control = int(a[0]) != 0
		8:
			var dir := int(a[0])
			if GridState.DIR_VEC.has(dir):
				for i in int(a[1]):
					var t: Vector2i = s.player + GridState.DIR_VEC[dir]
					if s.is_solid(t):
						break
					s.player = t
					s.facing = dir
					s.out.append({"type": "moved", "to": s.player, "dir": dir, "scripted": true})
		9:
			if _same_level(int(a[2])):
				s.tiles[int(a[1])][int(a[0])] = int(a[3])
				s.out.append({"type": "tile_changed", "at": Vector2i(int(a[0]), int(a[1])), "tile": int(a[3])})
		10:
			if int(a[0]) != 255:
				s.inventory.append(int(a[0]))
				s.out.append({"type": "pickup", "item": int(a[0])})
		11:
			var item := int(a[0]) & 0x7F
			var want_not := (int(a[0]) & 0x80) != 0
			if s.inventory.has(item) == want_not:
				return false
		15:
			s.out.append({"type": "map_reveal", "at": Vector2i(int(a[0]), int(a[1]))})
		16:
			s.out.append({"type": "change_level", "level": int(a[2]) & 0x7F, "to": Vector2i(int(a[0]), int(a[1]))})
		17:
			if _same_level(int(a[1])):
				var L: Dictionary = s.lights[int(a[0])]
				L.radius = int(a[2])
				L.on = 1 if int(a[2]) > 0 else 0
				s.out.append({"type": "light_changed", "light": int(a[0])})
		19:
			s.inventory.erase(int(a[0]))
			s.out.append({"type": "take_item", "item": int(a[0])})
		20:
			if _same_level(int(a[1])):
				s.event_active[int(a[0])] = true
		21:
			if _same_level(int(a[1])):
				s.event_active[int(a[0])] = false
		22:
			run(s.level.events[int(a[0])])
		23:
			s.out.append({"type": "bulb_socket", "light": int(a[0]) & 0x7F})
		26, 29:
			pass   # kiểu trang trí, view đọc trực tiếp từ level.events khi dựng cảnh
		27:
			s.out.append({"type": "actor_config", "mode": int(a[0]), "slot": int(a[1]), "args": a.slice(2)})
		30:
			s.out.append({"type": "special", "code": int(a[0])})
		_:
			if op in TODO_OPS:
				s.out.append({"type": "todo", "op": op, "args": a})
			else:
				push_error("ScriptVM: mã lệnh lạ %d" % op)
	return true
```

- [ ] **Bước 4: Chạy test, phải pass** (`23 passed, 0 failed`).

- [ ] **Bước 5: Commit**

```powershell
git add -A; git commit -m "M1 T6: ScriptVM for level 0 opcodes"
```

---

## Task 7: `core/rules_classic.gd`: mất năng lượng trong tối

Nguồn: `class_10.method_97` (dòng 1713–1757): thời gian thực tính ms. Ở chỗ tối: lần đầu chờ `2000 + rand(0..999)` ms rồi −1 năng lượng, sau đó lặp lại với khoảng chờ mới; vừa ra sáng rồi lại vào tối thì chờ 800 ms. "Sáng" = độ sáng ô > 0 (`method_133`). Cầm vật phẩm 20 thì không bị trừ (M2).

**Files:**
- Create: `core/rules_classic.gd`, `tests/test_rules_classic.gd`

- [ ] **Bước 1: Test**

`tests/test_rules_classic.gd`:
```gdscript
extends "res://tests/test_base.gd"

func _dark_rules() -> RulesClassic:
	var s := GridState.new(LevelData.load_level(0))
	for l in s.lights:
		l.on = 0
	return RulesClassic.new(s, 7)

func test_lit_tile_no_damage() -> void:
	var r := RulesClassic.new(GridState.new(LevelData.load_level(0)), 7)
	r.tick(10_000)
	eq(r.s.energy, r.s.max_energy, "ô start sáng, không mất")

func test_dark_damage_after_2_to_3_seconds() -> void:
	var r := _dark_rules()
	r.tick(1)          # bắt đầu đếm
	r.tick(1_998)
	eq(r.s.energy, r.s.max_energy, "chưa tới 2 s")
	r.tick(1_001)      # tổng 3000 ms > 2999 tối đa
	eq(r.s.energy, r.s.max_energy - 1, "mất 1 sau tối đa 3 s")
	r.tick(1)
	r.tick(3_000)
	eq(r.s.energy, r.s.max_energy - 2, "lặp lại")

func test_hurt_and_death_events() -> void:
	var r := _dark_rules()
	r.s.energy = 1
	r.tick(1)
	r.tick(3_000)
	var types := r.s.out.map(func(o): return o.type)
	ok(types.has("hurt"), "báo hurt")
	ok(types.has("death"), "về 0 thì báo death")

func test_back_into_dark_waits_800ms() -> void:
	var s := GridState.new(LevelData.load_level(0))
	var r := RulesClassic.new(s, 7)
	for l in s.lights:
		l.on = 0
	r.refresh_light()
	r.tick(1)          # tối: bắt đầu đếm
	s.lights[1].on = 1
	r.refresh_light()
	r.tick(10)         # sáng: timer -> -2
	s.lights[1].on = 0
	r.refresh_light()
	r.tick(799)
	eq(s.energy, s.max_energy, "chưa tới 800 ms")
	r.tick(2)
	eq(s.energy, s.max_energy - 1, "quay lại tối: 800 ms là mất")
```

- [ ] **Bước 2: Chạy test, phải fail.**

- [ ] **Bước 3: Cài `core/rules_classic.gd`**

```gdscript
class_name RulesClassic
extends RefCounted
## Luật chế độ Cổ điển: mất năng lượng trong tối theo thời gian thực (class_10.method_97).
## Mọi số ngẫu nhiên đi qua `rng` có seed để test lặp lại được.

const FIRST_WAIT_MS := 2000
const RANDOM_EXTRA_MS := 1000
const REENTER_WAIT_MS := 800

var s: GridState
var light: Array = []
var dark_timer: int = -1    # -1 chưa đếm; -2 vừa ra chỗ sáng; >=0 ms còn lại
var rng := RandomNumberGenerator.new()

func _init(state: GridState, seed_value: int = 0) -> void:
	s = state
	rng.seed = seed_value
	refresh_light()

func refresh_light() -> void:
	light = LightField.compute(s)

func is_lit(p: Vector2i) -> bool:
	# ponytail: bản gốc (method_132) lấy sáng từ ô cạnh khi đứng trên vật thể; M2 thêm khi có hộp/cửa.
	return s.in_bounds(p) and light[p.y][p.x] > 0

func tick(dt_ms: int) -> void:
	if is_lit(s.player):
		if dark_timer >= 0:
			dark_timer = -2
		return
	if dark_timer == -2:
		dark_timer = REENTER_WAIT_MS
	if dark_timer == -1:
		dark_timer = FIRST_WAIT_MS + rng.randi() % RANDOM_EXTRA_MS
		return
	dark_timer -= dt_ms
	if dark_timer < 0:
		dark_timer = -1
		s.energy -= 1
		s.out.append({"type": "hurt", "energy": s.energy})
		if s.energy <= 0:
			s.out.append({"type": "death"})
```

- [ ] **Bước 4: Chạy test, phải pass** (`27 passed, 0 failed`).

- [ ] **Bước 5: Commit**

```powershell
git add -A; git commit -m "M1 T7: RulesClassic darkness damage timer"
```

---

## Task 8: `view/level_builder.gd`: sàn và tường 3D từ grid

Hình tạm: sàn là `PlaneMesh` 1×1 mỗi ô, vật thể là `BoxMesh` cao 1 (hộp 0x43 cao 0.8, màu nâu), vật thể không chắn sáng (`blocks_light = 0`) cao 0.5. Màu sàn đổi theo độ sáng ở Task 10. 1 ô = 1 đơn vị; ô `(x, y)` nằm tại thế giới `(x, 0, y)`.

**Files:**
- Create: `view/level_builder.gd`, `tools/snap.gd`, `snap/` (gitignore)

- [ ] **Bước 1: Cài `view/level_builder.gd`**

```gdscript
class_name LevelBuilder
extends Node3D
## Dựng lưới 3D từ GridState: một node sàn mỗi ô sàn, một khối mỗi ô vật thể.
## rebuild_tile() dùng khi SET_TILE. floor_material(x,y) để lighting.gd tô độ sáng.

const TILE := 1.0
var floors: Dictionary = {}   # Vector2i -> MeshInstance3D
var objects: Dictionary = {}  # Vector2i -> MeshInstance3D

static func world_pos(p: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(p.x * TILE, y, p.y * TILE)

func build(s: GridState) -> void:
	for c in get_children():
		c.queue_free()
	floors.clear()
	objects.clear()
	for y in s.level.height:
		for x in s.level.width:
			_place(s, Vector2i(x, y))

func rebuild_tile(s: GridState, p: Vector2i) -> void:
	for d in [floors, objects]:
		if d.has(p):
			d[p].queue_free()
			d.erase(p)
	_place(s, p)

func _place(s: GridState, p: Vector2i) -> void:
	var t := s.tiles[p.y][p.x]
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if t < 8:
		var m := PlaneMesh.new()
		m.size = Vector2(TILE, TILE)
		mi.mesh = m
		mat.albedo_color = Color(0.08, 0.08, 0.1)
		mi.position = world_pos(p)
		floors[p] = mi
	else:
		var props := LevelData.tile_props(t)
		var h := 1.0 if int(props.blocks_light) == 1 else 0.5
		if int(props.movable) == 1:
			h = 0.8
			mat.albedo_color = Color(0.45, 0.3, 0.15)
		elif int(props.blocks_light) == 1:
			mat.albedo_color = Color(0.35, 0.33, 0.3)
		else:
			mat.albedo_color = Color(0.5, 0.45, 0.4)
		var m := BoxMesh.new()
		m.size = Vector3(TILE, h, TILE)
		mi.mesh = m
		mi.position = world_pos(p, h / 2.0)
		objects[p] = mi
	mi.material_override = mat
	add_child(mi)
```

- [ ] **Bước 2: Công cụ chụp ảnh `tools/snap.gd`**

```gdscript
## Chụp cảnh một màn ra PNG rồi thoát. Chạy (cần GPU, không --headless):
##   & $godot --path . -s res://tools/snap.gd ++ --level 0 --out snap/level_0.png
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level := 0
	var out := "snap/level.png"
	for i in args.size():
		if args[i] == "--level":
			level = int(args[i + 1])
		if args[i] == "--out":
			out = args[i + 1]
	var game: Node = load("res://game.tscn").instantiate()
	game.start_level = level
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(out.get_base_dir()))
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join(out))
	print("saved ", out)
	quit()
```
`game.tscn` tạo ở Task 12; tới lúc đó mới chụp được. Ghi chú: nếu môi trường không có GPU (chạy tự động), lệnh chụp sẽ lỗi; khi đó người dùng chạy tay và gửi ảnh, không chặn các task khác.

- [ ] **Bước 3: Chạy lại toàn bộ test (không đổi), commit**

```powershell
& $godot --headless --path . --import; & $godot --headless --path . -s res://tests/run.gd
git add -A; git commit -m "M1 T8: LevelBuilder placeholder geometry + snap tool"
```

---

## Task 9: `view/actor.gd` và `view/camera_rig.gd`

**Files:**
- Create: `view/actor.gd`, `view/camera_rig.gd`

- [ ] **Bước 1: Cài `view/actor.gd`**

```gdscript
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
	position = LevelBuilder.world_pos(p)

func move_to(p: Vector2i) -> Signal:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", LevelBuilder.world_pos(p), STEP_TIME)
	set_anim("walk")
	_tween.finished.connect(func(): set_anim("idle"), CONNECT_ONE_SHOT)
	return _tween.finished

func face(dir: int) -> void:
	rotation.y = FACING_Y.get(dir, 0.0)

func set_anim(name: String) -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(name):
		ap.play(name)
```

- [ ] **Bước 2: Cài `view/camera_rig.gd`**

```gdscript
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
```

- [ ] **Bước 3: Commit**

```powershell
git add -A; git commit -m "M1 T9: placeholder ActorView and CameraRig"
```

---

## Task 10: `view/lighting.gd`: đèn Godot bám `light_field`

Hai lớp: (1) mỗi ô sàn tô màu theo độ sáng 0..7 (đúng luật game, là thứ người chơi phải đọc được); (2) một `OmniLight3D` cho mỗi đèn đang bật để tường và nhân vật có bóng thật. Đèn có hướng dùng `SpotLight3D`.

**Files:**
- Create: `view/lighting.gd`

- [ ] **Bước 1: Cài `view/lighting.gd`**

```gdscript
class_name LightingView
extends Node3D
## Đồng bộ hình ảnh với LightField: tô sàn theo mức 0..7 và đặt đèn Godot cho mỗi nguồn đang bật.

const LEVEL_COLORS := [
	Color(0.05, 0.05, 0.07), Color(0.16, 0.14, 0.1), Color(0.27, 0.23, 0.15), Color(0.38, 0.32, 0.2),
	Color(0.5, 0.42, 0.26), Color(0.62, 0.52, 0.32), Color(0.75, 0.64, 0.4), Color(0.9, 0.8, 0.55)]
# dir của đèn (mã bản gốc, xem LightField._ray): 1 chiếu +y, 2 chiếu +x, 3 chiếu -y, 4 chiếu -x
const DIR_TO_VEC := {1: Vector3(0, 0, 1), 2: Vector3(1, 0, 0), 3: Vector3(0, 0, -1), 4: Vector3(-1, 0, 0)}

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
			spot.position = pos
			add_child(spot)
			spot.look_at(pos + DIR_TO_VEC[int(L.dir)] + Vector3(0, -0.3, 0))
			light = spot
		else:
			var omni := OmniLight3D.new()
			omni.omni_range = float(L.radius) * 1.2
			omni.position = pos
			add_child(omni)
			light = omni
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 2.0
		light.shadow_enabled = true
		_lights.append(light)
```

- [ ] **Bước 2: Commit**

```powershell
git add -A; git commit -m "M1 T10: LightingView syncs floor shading and Godot lights"
```

---

## Task 11: `ui/dialog.gd`: hộp thoại có chân dung

Chân dung là khung hình trong bảng `data/frames.json` (`[png, x, y, w, h, ox, oy]`), cắt từ `assets/original/<png>` bằng `AtlasTexture`, phóng 4× với lọc nearest. M3 thay bằng chân dung vẽ từ concept theo cùng mã khung hình.

**Files:**
- Create: `ui/dialog.gd`, `ui/portraits.gd`, `tests/test_portraits.gd`

- [ ] **Bước 1: Test bảng chân dung**

`tests/test_portraits.gd`:
```gdscript
extends "res://tests/test_base.gd"

func test_frame_lookup() -> void:
	var f := Portraits.frame(171)
	eq(f.png, "av.png", "Hale ở av.png")
	ok(f.rect.size.x > 0 and f.rect.size.y > 0, "kích cỡ dương")
	eq(Portraits.frame(325).png, "bq.png", "Jack ở bq.png")

func test_texture_loads() -> void:
	var tex := Portraits.texture(171)
	ok(tex != null, "có texture")
	ok(tex.get_width() > 0, "texture có chiều rộng")
```

- [ ] **Bước 2: Cài `ui/portraits.gd`**

```gdscript
class_name Portraits
extends RefCounted
## Tra khung hình gốc -> AtlasTexture. Dùng cho chân dung hội thoại và sprite tạm.

static var _frames: Array = []
static var _sheets: Dictionary = {}
static var _cache: Dictionary = {}

static func frame(id: int) -> Dictionary:
	if _frames.is_empty():
		_frames = LevelData.read_json("res://data/frames.json")
	var f: Array = _frames[id]
	return {"png": f[0], "rect": Rect2(int(f[1]), int(f[2]), int(f[3]), int(f[4]))}

static func texture(id: int) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var f := frame(id)
	if not _sheets.has(f.png):
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/original/" + f.png))
		_sheets[f.png] = ImageTexture.create_from_image(img)
	var at := AtlasTexture.new()
	at.atlas = _sheets[f.png]
	at.region = f.rect
	_cache[id] = at
	return at
```

- [ ] **Bước 3: Chạy test, phải pass** (`29 passed, 0 failed`). `Image.load_from_file` chạy được ở headless.

- [ ] **Bước 4: Cài `ui/dialog.gd`**

```gdscript
class_name DialogBox
extends PanelContainer
## Hộp thoại dưới màn hình: chân dung trái, chữ phải. show_line() rồi chờ người chơi bấm interact.

signal closed

var _portrait: TextureRect
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -220
	offset_left = 40
	offset_right = -40
	offset_bottom = -30
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(160, 160)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_portrait)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 26)
	box.add_child(_label)
	hide()

func show_line(text_id: int, portrait: int, lang: String) -> void:
	_label.text = LevelData.text(text_id, lang)
	_portrait.visible = portrait >= 0
	if portrait >= 0:
		_portrait.texture = Portraits.texture(portrait)
	show()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev.is_action_pressed("interact"):
		hide()
		closed.emit()
		get_viewport().set_input_as_handled()
```

- [ ] **Bước 5: Commit**

```powershell
git add -A; git commit -m "M1 T11: DialogBox with original portrait atlas"
```

---

## Task 12: `game.gd` nối core ↔ view ↔ ui, phím PC

Phím (giữ đúng bản PC hiện tại): mũi tên/WASD đi; Enter/Space/E/F tương tác; Esc menu; Tab/I túi đồ; M bản đồ. M1 chỉ dùng đi và tương tác.

Luồng một lượt: nhận phím → `state.step(dir)` → duyệt `out`: `moved` → `actor.move_to`; `bumped` → `actor.face`; `say` → xếp vào hàng đợi thoại, khóa input tới khi đóng hết; `tile_changed` → `builder.rebuild_tile`; `light_changed`/`teleported` → tính lại ánh sáng; `todo` → in cảnh báo; `death` → in chữ 162 và tải lại màn. Mỗi frame: `rules.tick(delta*1000)` khi không mở thoại.

**Files:**
- Create: `game.gd`, `game.tscn`, `ui/hud.gd`

- [ ] **Bước 1: Cài `ui/hud.gd`**

```gdscript
class_name Hud
extends Label
## Góc trên trái: năng lượng, vị trí, độ sáng ô đang đứng (số để so với bản gốc).

func _ready() -> void:
	position = Vector2(16, 12)
	add_theme_font_size_override("font_size", 22)

func update(s: GridState, light_level: int) -> void:
	text = "Năng lượng %d/%d   Ô (%d,%d)   Sáng %d   Túi %s" % [
		s.energy, s.max_energy, s.player.x, s.player.y, light_level, str(s.inventory)]
```

- [ ] **Bước 2: Cài `game.gd`**

```gdscript
extends Node3D
## Nối core (GridState, RulesClassic) với view (LevelBuilder, ActorView, LightingView, CameraRig) và ui.

const KEYS := {
	"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
	"interact": [KEY_ENTER, KEY_SPACE, KEY_E, KEY_F],
	"menu": [KEY_ESCAPE], "inventory": [KEY_TAB, KEY_I], "map": [KEY_M],
}
const DIR_ACTION := {"move_right": 1, "move_down": 2, "move_left": 3, "move_up": 4}

@export var start_level := 0
@export var lang := "vi"

var state: GridState
var rules: RulesClassic
var builder: LevelBuilder
var actor: ActorView
var lighting: LightingView
var rig: CameraRig
var dialog: DialogBox
var hud: Hud
var _say_queue: Array = []
var _busy := false

func _ready() -> void:
	_setup_input()
	builder = LevelBuilder.new()
	add_child(builder)
	lighting = LightingView.new()
	add_child(lighting)
	lighting.setup_environment()
	actor = ActorView.new()
	add_child(actor)
	rig = CameraRig.new()
	rig.target = actor
	add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	dialog = DialogBox.new()
	ui.add_child(dialog)
	dialog.closed.connect(_next_say)
	load_level(start_level)

func _setup_input() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func load_level(n: int, spawn: Vector2i = Vector2i(-1, -1)) -> void:
	state = GridState.new(LevelData.load_level(n), spawn)
	rules = RulesClassic.new(state, randi())
	builder.build(state)
	actor.snap_to(state.player)
	_refresh_light()

func _refresh_light() -> void:
	rules.refresh_light()
	lighting.sync(state, rules.light, builder)
	hud.update(state, rules.light[state.player.y][state.player.x])

func _process(delta: float) -> void:
	if _busy or dialog.visible:
		return
	rules.tick(int(delta * 1000.0))
	if not state.out.is_empty():
		_handle(state.out.duplicate())
		state.out.clear()
	for action in DIR_ACTION:
		if Input.is_action_just_pressed(action):
			_handle(state.step(DIR_ACTION[action]))
			return

func _handle(out: Array) -> void:
	for o in out:
		match o.type:
			"moved":
				actor.face(o.dir)
				actor.move_to(o.to)
			"bumped":
				actor.face(o.dir)
			"teleported":
				actor.snap_to(o.to)
			"say":
				_say_queue.append(o)
			"tile_changed":
				builder.rebuild_tile(state, o.at)
			"change_level":
				print("change_level -> %d tại %s (M2)" % [o.level, str(o.to)])
			"death":
				_say_queue.append({"text_id": 162, "portrait": -1})
				_busy = true
			"todo":
				print("todo op %d %s" % [o.op, str(o.args)])
			_:
				pass
	_refresh_light()
	if not dialog.visible:
		_next_say()

func _next_say() -> void:
	if _say_queue.is_empty():
		if _busy:
			_busy = false
			load_level(state.level.index)
		return
	var o: Dictionary = _say_queue.pop_front()
	dialog.show_line(o.text_id, o.portrait, lang)
```

- [ ] **Bước 3: Tạo `game.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game.gd" id="1"]

[node name="Game" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Bước 4: Chạy game bằng tay và chụp ảnh**

```powershell
& $godot --path . -s res://tools/snap.gd ++ --level 0 --out snap/level_0.png
& $godot --path .
```
Kết quả mong đợi: cửa sổ 1280×720, phòng quán rượu bằng khối hộp, sàn sáng dần quanh đèn, nhân vật viên nang tại (6,4). Đi phải 1 ô được, phải nữa bị tường chắn. Đi trái 1 rồi lên: hiện hộp thoại Jack (chân dung) → Enter → hộp thoại Hale → Enter → HUD `Túi [0]`. Đi vào chỗ tối, sau 2–3 s năng lượng giảm 1.
Nếu chụp ảnh thất bại do không có GPU: bỏ qua, người dùng chạy tay.

- [ ] **Bước 5: Chạy toàn bộ test lần nữa, commit**

```powershell
& $godot --headless --path . --import; & $godot --headless --path . -s res://tests/run.gd
git add -A; git commit -m "M1 T12: playable level 0 with placeholder view, dialog, HUD"
```

---

## Task 13: Bộ so sánh với bản gốc

Mục đích: mọi giả định trong `core` (bảng `ENTER_FLAG`, thứ tự đi/kích sự kiện, `max_energy`, độ sáng từng ô) được đối chiếu với game gốc đang chạy. Cách: mở rộng `df2_desktop\test\AutoPlay.java` thêm lệnh `R` ghi trạng thái lớp `d` (tên gốc của `class_10`) ra một dòng JSON; script PowerShell chạy một tuyến đi cố định; test Godot chạy cùng tuyến trên `GridState` và so.

Tên trường gốc: mở `class_10.java`, tìm dòng khai báo và đọc comment `$VF: renamed from` ngay trên nó:
```powershell
cd d:\ntiendung\games\darkest_fear_2_grim_243556\src
rg -n -B1 "static byte field_129;|static byte field_130;|static int field_151;|static int field_152;|static int field_185;|static byte\[\]\[\] field_190;" class_10.java
```
Ghi các tên gốc vào `tools/parity_fields.json` (Task 13 Bước 2) theo dạng `{"x": "<tên gốc field_129>", "y": "...", "energy": "...", "max_energy": "...", "level": "...", "grid": "..."}`.

**Files:**
- Modify: `d:\ntiendung\games\df2_desktop\test\AutoPlay.java` (thêm lệnh `R`)
- Create: `tools/parity_fields.json`, `tools/parity.ps1`, `tests/parity/level00_route.json`, `tests/parity/level00_trace.jsonl`, `tests/test_parity.gd`

- [ ] **Bước 1: Thêm lệnh `R<file>` vào AutoPlay**

Trong `AutoPlay.java`, cạnh các lệnh `v`/`L`/`P` đã có, thêm nhánh:
```java
case 'R': { // R<path>: ghi một dòng JSON trạng thái lớp d
    Class<?> d = Class.forName("d");
    StringBuilder sb = new StringBuilder("{");
    for (java.lang.reflect.Field f : d.getDeclaredFields()) {
        if (!java.lang.reflect.Modifier.isStatic(f.getModifiers())) continue;
        Class<?> t = f.getType();
        f.setAccessible(true);
        Object v = f.get(null);
        if (t.isPrimitive()) sb.append('"').append(f.getName()).append("\":").append(v).append(',');
        else if (t == byte[][].class && v != null) {
            sb.append('"').append(f.getName()).append("\":[");
            for (byte[] row : (byte[][]) v) sb.append(java.util.Arrays.toString(row)).append(',');
            sb.setLength(sb.length() - 1); sb.append("],");
        }
    }
    sb.setLength(sb.length() - 1); sb.append("}\n");
    java.nio.file.Files.write(java.nio.file.Paths.get(arg), sb.toString().getBytes("UTF-8"),
        java.nio.file.StandardOpenOption.CREATE, java.nio.file.StandardOpenOption.APPEND);
    break;
}
```
Biên dịch lại như `df2_desktop\qa` đang làm (xem `levels.ps1` để biết classpath). Chạy thử một lệnh `R` khi game đang ở màn 0: file có đúng một dòng JSON, mở bằng `python -c "import json;print(len(json.loads(open('t.jsonl').readline())))"` ra số > 50.

- [ ] **Bước 2: Tuyến đi và script chạy bản gốc**

`tests/parity/level00_route.json`:
```json
{"level": 0, "spawn": [6, 4],
 "steps": [1, 1, 4, 3, 3, 4, 2, 2, 2],
 "note": "phải, phải(tường), lên(tường 0x5a), trái, trái, lên(tờ giấy: Note 1), xuống x3"}
```

`tools/parity.ps1` (chạy trong `lantern_godot`):
```powershell
# Chạy bản gốc ẩn theo tuyến trong tests/parity/levelNN_route.json, ghi trace JSONL cạnh nó.
param([int]$level = 0)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
$qa = "d:\ntiendung\games\df2_desktop\qa"
$route = Get-Content "$root\tests\parity\level$('{0:d2}' -f $level)_route.json" | ConvertFrom-Json
$trace = "$root\tests\parity\level$('{0:d2}' -f $level)_trace.jsonl"
Remove-Item $trace -ErrorAction SilentlyContinue
# Save gốc: byte 8,9,10 = x, y, level (xem df2_desktop\test\levels.ps1)
$app = Join-Path $env:TEMP "parity_appdata"; Remove-Item $app -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory "$app\DarkestFear2" | Out-Null
$b = [IO.File]::ReadAllBytes("$qa\S_base.rms"); $b[8] = $route.spawn[0]; $b[9] = $route.spawn[1]; $b[10] = $level
[IO.File]::WriteAllBytes("$app\DarkestFear2\S.rms", $b)
$cmd = "$qa\cmd.txt"
# Mỗi bước: giữ phím hướng 350 ms (h<dir>:<ms> như levels.ps1), chờ, ghi R; Enter (-5) để đóng thoại nếu có.
$keys = @{1 = -4; 2 = -2; 3 = -3; 4 = -1}
$lines = @("w1500", "R$trace")
foreach ($d in $route.steps) { $lines += "h$($keys[$d]):350"; $lines += "w600"; $lines += "k-5"; $lines += "w300"; $lines += "k-5"; $lines += "w300"; $lines += "R$trace" }
$lines += "q"
Set-Content $cmd $lines
$env:APPDATA = $app
& java -Ddf2.hidden=true -cp "$qa\classes;$qa\test" AutoPlay $cmd   # cách gọi giống levels.ps1; sửa nếu levels.ps1 dùng khác
Write-Host "trace: $trace ($((Get-Content $trace).Count) dòng)"
```
Cách AutoPlay được gọi (classpath, tên lớp chính, có cần tham số `cmd.txt` không) phải chép đúng từ `df2_desktop\test\levels.ps1`; đọc file đó trước khi viết. Chạy:
```powershell
.\tools\parity.ps1 -level 0
```
Kết quả mong đợi: `trace: ... (10 dòng)` (1 dòng đầu + 9 bước).

- [ ] **Bước 3: `tools/parity_fields.json`** với tên gốc tra ở đầu Task; ví dụ dạng (tên phải lấy từ comment, không đoán):
```json
{"x": "g", "y": "h", "energy": "aM", "max_energy": "aN", "level": "f", "grid": "c"}
```

- [ ] **Bước 4: Test so sánh trong Godot**

`tests/test_parity.gd`:
```gdscript
extends "res://tests/test_base.gd"
## So GridState với trace ghi từ bản gốc (tools/parity.ps1). Không có trace thì bỏ qua (in SKIP).

func _lines(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var out := []
	for line in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n", false):
		out.append(JSON.parse_string(line))
	return out

func test_level00_route_matches_original() -> void:
	var trace := _lines("res://tests/parity/level00_trace.jsonl")
	if trace.is_empty():
		print("SKIP: chưa có level00_trace.jsonl, chạy tools/parity.ps1 -level 0")
		return
	var F: Dictionary = LevelData.read_json("res://tools/parity_fields.json")
	var route: Dictionary = LevelData.read_json("res://tests/parity/level00_route.json")
	var s := GridState.new(LevelData.load_level(0), Vector2i(int(route.spawn[0]), int(route.spawn[1])))
	s.max_energy = int(trace[0][F.max_energy])
	s.energy = int(trace[0][F.energy])
	var rules := RulesClassic.new(s, 0)
	_compare_grid(trace[0], F, rules.light, s, "trước khi đi")
	for i in route.steps.size():
		s.step(int(route.steps[i]))
		rules.refresh_light()
		var t: Dictionary = trace[i + 1]
		eq(s.player, Vector2i(int(t[F.x]), int(t[F.y])), "bước %d vị trí" % i)
		_compare_grid(t, F, rules.light, s, "bước %d" % i)

func _compare_grid(t: Dictionary, F: Dictionary, light: Array, s: GridState, tag: String) -> void:
	## Bản gốc ghi độ sáng vào chính ô sàn (giá trị < 8). So từng ô sàn; thử cả hai chiều [y][x] và [x][y].
	var g: Array = t[F.grid]
	var mism := 0
	var mism_t := 0
	for y in s.level.height:
		for x in s.level.width:
			if s.tiles[y][x] >= 8:
				continue
			if int(g[y][x]) != light[y][x]:
				mism += 1
			if int(g[x][y]) != light[y][x]:
				mism_t += 1
	ok(mini(mism, mism_t) == 0, "%s: độ sáng lệch %d ô (hoặc %d ô nếu chuyển vị)" % [tag, mism, mism_t])
```
Chạy test. Ba kết cục và việc phải làm:
1. Vị trí lệch ở bước có sự kiện → sửa `ENTER_FLAG` hoặc thứ tự đi/kích trong `GridState.step` cho khớp bản gốc, rồi cập nhật test Task 4 nếu test đó mã hóa giả định sai.
2. Độ sáng lệch → so từng ô in ra, sửa `LightField` (thường là chiều `dir`, bỏ ô đèn, hay hằng 40/100).
3. `max_energy` khác 5 → sửa mặc định trong `GridState`, test Task 3 vẫn pass vì so `energy == max_energy`.
Kết quả mong đợi cuối: `test_level00_route_matches_original` PASS, không SKIP.

- [ ] **Bước 5: Commit (cả hai repo)**

```powershell
git add -A; git commit -m "M1 T13: parity harness against original game, level 0 route"
```
`AutoPlay.java` nằm ngoài repo `lantern_godot` (thư mục `games` chưa có git); ghi rõ trong commit message rằng cần bản `AutoPlay` có lệnh `R`.

---

## Task 14: Nghiệm thu M1 và cập nhật tài liệu

- [ ] **Bước 1: Checklist chạy tay** (ghi kết quả vào `docs/plans/m1-acceptance.md`, mỗi dòng PASS/FAIL):
  - Mở game, thấy màn 0, nhân vật ở (6,4), sàn sáng quanh đèn.
  - Đi 4 hướng, tường chắn, không lọt ra ngoài biên.
  - Đọc tờ giấy: 2 câu thoại, đúng chân dung, `Túi [0]`, đọc lại không hiện nữa.
  - Đứng chỗ tối ≥ 3 s: năng lượng giảm; về 0: hiện chữ 162, màn tải lại.
  - Console không có `push_error`; các `todo op` được liệt kê (đây là việc của M2).
  - `godot --headless -s res://tests/run.gd`: `0 failed`, parity không SKIP.
- [ ] **Bước 2: Cập nhật `docs/specs/2026-09-29-lantern-godot-design.md`** phần "tile_props bits to confirm" thành bảng đã xác nhận (Task 1) và ghi giá trị `max_energy`, `ENTER_FLAG` đã đối chiếu (Task 13).
- [ ] **Bước 3: Commit, tag**

```powershell
git add -A; git commit -m "M1 done: level 0 vertical slice accepted"; git tag m1
```

---

## Ghi chú cho người thực hiện

- Không sửa test để cho pass; nếu giả định sai thì sửa code và ghi lý do vào commit.
- Mọi số lấy từ bản gốc (2000 ms, 800 ms, 40/100, 7, 4 góc) giữ tên hằng rõ ràng, không rải số trong code.
- File tạm để thử (`snap/`, `%TEMP%\parity_appdata`) không commit.
- Godot in cảnh báo `integer_division`: đã bỏ bằng `@warning_ignore` ở đúng hàm, không tắt toàn cục.
