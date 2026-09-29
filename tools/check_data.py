"""Kiểm tra data/ do export_data.py sinh ra. Chạy: python tools/check_data.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "data"
load = lambda p: json.loads((D / p).read_text("utf-8"))

levels = sorted((D / "levels").glob("*.json"))
assert len(levels) == 19, f"cần 19 màn, có {len(levels)}"
L0 = load("levels/00.json")
assert (L0["width"], L0["height"]) == (19, 22), L0["width"]
assert L0["start"] == [6, 4]
assert len(L0["lights"]) == 19 and len(L0["events"]) == 78
assert L0["grid"][4][8] == 0x38 and L0["grid"][4][6] == 0, "tường (8,4), sàn (6,4)"
tiles = load("tiles.json")
assert tiles["56"] == {"solid": 1, "blocks_light": 1, "dim_light": 0, "movable": 0}
assert tiles["67"]["movable"] == 1, "0x43 là hộp"
for lang in ("en", "vi"):
    assert len(load(f"strings_{lang}.json")) == 258, lang
en = load("strings_en.json")
assert "Bar" in en[211]
assert "\n" in en[12], "chuỗi nhiều dòng giữ xuống dòng"
frames = load("frames.json")
assert len(frames) == 435 and frames[171][0] == "av.png", "chân dung Hale"
items = load("items.json")
assert len(items) == 34 and items["0"]["name_id"] == 179
cm = load("citymap.json")
assert cm["width"] > 0 and len(cm["rows"]) == cm["height"]
assert (ROOT / "assets" / "original" / "av.png").exists()
print("data OK")
