"""Ghép bộ tile image/new/aa.png lên bố cục một màn, xuất ảnh xem trước 2D.

    python tools/preview_map.py [level] [out.png]      (chạy trong lantern_godot/)
    python tools/preview_map.py --sheet                  (xuất ảnh đánh số các sprite)
"""
import json
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFilter

SRC = "image/new/aa.png"
T = 64  # px mỗi ô


def sprites(im):
    """Tách sprite theo vùng alpha liền nhau (trên lưới 4px cho nhanh)."""
    s = 4
    a = im.getchannel("A").resize((im.width // s, im.height // s), Image.BOX).load()
    w, h = im.width // s, im.height // s
    seen, boxes = set(), []
    for y in range(h):
        for x in range(w):
            if a[x, y] < 20 or (x, y) in seen:
                continue
            q, x0, y0, x1, y1 = deque([(x, y)]), x, y, x, y
            seen.add((x, y))
            while q:
                cx, cy = q.popleft()
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and a[nx, ny] >= 20:
                        seen.add((nx, ny))
                        q.append((nx, ny))
            if (x1 - x0) * (y1 - y0) > 16:
                boxes.append((x0 * s, y0 * s, (x1 + 1) * s, (y1 + 1) * s))
    boxes.sort(key=lambda b: (b[1] // 200, b[0]))
    return boxes


def sheet(im, boxes):
    out = im.copy()
    d = ImageDraw.Draw(out)
    for i, b in enumerate(boxes):
        d.rectangle(b, outline=(255, 0, 0, 255), width=2)
        d.text((b[0] + 3, b[1] + 3), str(i), fill=(255, 255, 0, 255))
    out.save("snap/aa_sheet.png")
    print(len(boxes), "sprites -> snap/aa_sheet.png")
    for i, b in enumerate(boxes):
        print(i, b)


# Vùng cắt tay trên aa.png (2169x725); cắt sát lại theo alpha khi nạp.
BOX = {
    "path": (85, 190, 190, 297), "path_leaf": (339, 190, 434, 297),
    "well": (17, 402, 180, 540), "slab": (186, 396, 292, 519), "hatch": (303, 396, 483, 513),
    "crate": (17, 546, 186, 684), "box_open": (201, 551, 381, 682), "crate_s": (409, 515, 515, 587),
    "trough": (504, 593, 669, 674), "cage": (515, 413, 710, 589),
    "fence_tall": (724, 413, 911, 682), "post": (911, 440, 945, 657), "fence_low": (964, 525, 1212, 688),
    "lantern": (1245, 449, 1356, 688), "posts": (1370, 434, 1472, 674), "woodpile": (1472, 445, 1790, 674),
    "grave": (1786, 449, 2055, 635), "cross": (2055, 449, 2154, 625),
    "pine": (1447, 106, 1917, 445), "pine_s": (1908, 120, 2140, 448), "roots": (466, 116, 720, 413),
}
# ponytail: đoán loại vật theo giá trị ô (frame gốc 130–135), chưa đối chiếu sprite gốc.
OBJ = {138: "grave", 139: "cross", 140: "woodpile", 141: "grave", 142: "cross", 143: "well"}


def load(im):
    out = {}
    for k, b in BOX.items():
        c = im.crop(b)
        out[k] = c.crop(c.getchannel("A").getbbox())
    return out


def put(canvas, spr, x, y, w, anchor_bottom=True):
    """Dán sprite rộng w px, đáy chạm đáy ô (x, y)."""
    h = round(spr.height * w / spr.width)
    s = spr.resize((w, h), Image.LANCZOS)
    px = x * T + (T - w) // 2
    py = (y + 1) * T - h if anchor_bottom else y * T
    canvas.alpha_composite(s, (px + T, py + T))  # +T: lề 1 ô quanh map


def render(level, out):
    im = Image.open(SRC).convert("RGBA")
    S = load(im)
    d = json.load(open(f"data/levels/{level:02d}.json", encoding="utf-8"))
    W, H, g = d["width"], d["height"], d["grid"]
    cv = Image.new("RGBA", ((W + 2) * T, (H + 2) * T), (18, 16, 14, 255))
    floor = [S["path"].resize((T, T)), S["path_leaf"].resize((T, T))]
    for y in range(-1, H + 1):
        for x in range(-1, W + 1):
            cv.alpha_composite(floor[(x * 7 + y * 13) % 5 == 0], ((x + 1) * T, (y + 1) * T))
    # rừng thông viền trên + rễ cây hai góc dưới
    for x in range(-1, W + 1, 3):
        put(cv, S["pine" if x % 2 else "pine_s"], x, -1, T * 3, anchor_bottom=False)
    put(cv, S["roots"], -1, H, T * 2)
    put(cv, S["roots"], W - 1, H, T * 2)
    lights = {(l["x"], l["y"]) for l in d["lights"]}
    for y in range(H):  # vẽ theo hàng để vật hàng dưới đè hàng trên
        for x in range(W):
            v = g[y][x]
            if v >= 8 and v in OBJ:
                put(cv, S[OBJ[v]], x, y, T)
            elif v >= 8:
                corner = (x in (0, W - 1)) and (y in (0, H - 1))
                vertical = 0 < y < H - 1 and (x in (0, W - 1) or (y > 0 and g[y - 1][x] >= 8 and g[y - 1][x] not in OBJ))
                put(cv, S["fence_tall" if corner else "posts" if vertical else "fence_low"], x, y, T)
            if (x, y) in lights:
                put(cv, S["lantern"], x, y, T // 2)
    # bóng tối: tối 75%, khoét sáng quanh đèn theo radius
    dark = Image.new("L", cv.size, 170)
    dd = ImageDraw.Draw(dark)
    for l in d["lights"]:
        cx, cy = (l["x"] + 1.5) * T, (l["y"] + 1.5) * T
        r = (l["radius"] + 0.5) * T
        dd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=40)
    shade = Image.new("RGBA", cv.size, (8, 6, 12, 255))
    shade.putalpha(dark.filter(ImageFilter.GaussianBlur(T)))
    glow = Image.new("RGBA", cv.size, (255, 170, 60, 0))
    glow.putalpha(dark.point(lambda v: max(0, 120 - v) // 3).filter(ImageFilter.GaussianBlur(T)))
    cv.alpha_composite(glow)
    cv.alpha_composite(shade)
    sx, sy = d["start"]
    ImageDraw.Draw(cv).ellipse(((sx + 1.3) * T, (sy + 1.3) * T, (sx + 1.7) * T, (sy + 1.7) * T), outline=(90, 200, 255, 255), width=3)
    cv.convert("RGB").save(out)
    print("saved", out, cv.size)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        im = Image.open(SRC).convert("RGBA")
        sheet(im, sprites(im))
        sys.exit()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    render(int(args[0]) if args else 4, args[1] if len(args) > 1 else "image/img_map.png")
