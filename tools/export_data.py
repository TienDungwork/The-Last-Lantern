"""Sinh data/ cho bản Godot từ file gốc. Chạy: python tools/export_data.py
Dùng lại df2_decode.py và df2_lang.py (không chép code). Không sửa data/ bằng tay."""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]                 # lantern_godot/
GAME = ROOT.parent / "darkest_fear_2_grim_243556"          # thư mục game gốc
sys.path.insert(0, str(ROOT.parent / "tools"))
import df2_decode as dec  # noqa: E402
from df2_lang import parse_dump  # noqa: E402

PNGS = ["av", "aw", "ax", "ay", "az", "ba", "bb", "bc", "bd", "be", "bg", "bh", "bi", "bj", "bk",
        "bl", "bm", "bn", "bo", "bp", "bq", "bs", "bt", "bv"]


def dump(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), "utf-8")


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
    dump(ROOT / "data" / "strings_en.json", parse_dump((GAME / "text_English.txt").read_text("utf-8")))
    dump(ROOT / "data" / "strings_vi.json", parse_dump((GAME / "text_TiengViet.txt").read_text("utf-8")))
    (ROOT / "assets" / "original").mkdir(parents=True, exist_ok=True)
    for p in PNGS:
        shutil.copy(GAME / f"{p}.png", ROOT / "assets" / "original" / f"{p}.png")
    print("exported 19 levels, city map, tiles, frames, strings, %d png" % len(PNGS))


if __name__ == "__main__":
    main()
