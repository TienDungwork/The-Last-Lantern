"""Cắt các sheet trong image/new thành từng sprite (theo vùng alpha liền nhau) ra assets/new/<sheet>_<nn>.png.
Ảnh AI "giả pixel" (mỗi ô pixel ~3-16px, lệch lưới, viền nhòe) được thu về lưới pixel gốc và giảm màu.
Kèm assets/new/_index.png đánh số để chọn sprite. Chạy: python tools/crop_sheets.py
"""

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC, OUT = ROOT / "image" / "new", ROOT / "assets" / "new"
CELL = 12  # gộp theo ô CELL px: các mảnh cách nhau < CELL px coi là một vật
CELL_BY_SHEET = {"aa": 3, "ad": 3}  # sheet xếp sát nhau
SMOOTH_SHEETS = {"ae"}  # vệt bóng mờ: giữ alpha chuyển dần
# Sheet một nhân vật trên nền màu phẳng: thu về đúng chiều cao texel (32 texel = 1 ô) thay vì theo cỡ pixel giả.
# ap tu sĩ áo đỏ, aq sinh vật bóng tối, ar boss 1, as boss 2, at cục lửa.
HEIGHT_BY_SHEET = {"ap": 60, "aq": 38, "ar": 84, "as": 100, "at": 22}
KEY_DIST = 90  # khoảng cách màu tới màu nền (góc ảnh) coi là nền
COLORS = 48
FLOOR_PX = 32  # sàn: 32x32 texel mỗi ô = LevelBuilder.TEXELS_PER_TILE, cùng cỡ pixel với sprite
# Texture lát: vùng đặc (không trong suốt) trong sheet gốc; mirror=True lật gương 2x2 để liền mạch.
TEXTURES = {
    "tex_floor": ("aa", (300, 170, 430, 300), False),  # dải đất có lá vàng
    "tex_wall": ("ab", (834, 471, 1354, 648), True),
}


def pixel_size(img: Image.Image) -> int:
    """Cỡ ô pixel giả: phân vị 75 độ dài các vệt cùng màu theo hàng ngang (vệt ngắn là do nhiễu/chấm)."""
    # ponytail: ước lượng thô, sai ±2px trên sheet nhiều chấm nhiễu; cần chuẩn hơn thì tìm chu kỳ bằng FFT.
    a = np.array(img.convert("RGBA")).astype(int)
    runs = []
    for row in a[::7]:
        same = (row[1:, 3] > 200) & (row[:-1, 3] > 200) & (np.abs(row[1:, :3] - row[:-1, :3]).sum(1) < 12)
        c = 1
        for s in same:
            if s:
                c += 1
            else:
                if c > 1:
                    runs.append(c)
                c = 1
    return int(min(np.percentile(runs, 75), 16)) if runs else 1


def key_background(img: Image.Image) -> Image.Image:
    """Ảnh AI không có alpha (nền một màu phẳng): màu gần màu góc ảnh -> trong suốt, kể cả lỗ kín giữa tay/chân."""
    a = np.array(img)
    if a[0, 0, 3] < 255:
        return img
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(border, axis=0)
    a[np.linalg.norm(a[:, :, :3] - bg, axis=2) < KEY_DIST] = 0
    return Image.fromarray(a)


def to_native(img: Image.Image, px: float, smooth: bool = False) -> Image.Image:
    w, h = max(1, round(img.width / px)), max(1, round(img.height / px))
    small = img.resize((w, h), Image.Resampling.BOX)
    if smooth:
        return small
    alpha = small.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    out = small.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out.putalpha(alpha)
    return out


def components(alpha: np.ndarray, cell: int = CELL) -> list[tuple[int, int, int, int]]:
    h, w = alpha.shape
    gh, gw = -(-h // cell), -(-w // cell)
    pad = np.zeros((gh * cell, gw * cell), bool)
    pad[:h, :w] = alpha > 32
    grid = pad.reshape(gh, cell, gw, cell).any(axis=(1, 3))
    seen = np.zeros_like(grid)
    boxes = []
    for sy, sx in zip(*np.nonzero(grid)):
        if seen[sy, sx]:
            continue
        q, cells = deque([(sy, sx)]), []
        seen[sy, sx] = True
        while q:
            y, x = q.popleft()
            cells.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < gh and 0 <= nx < gw and grid[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
        ys, xs = zip(*cells)
        if len(cells) * cell * cell >= 2000:
            boxes.append((min(xs) * cell, min(ys) * cell, min((max(xs) + 1) * cell, w), min((max(ys) + 1) * cell, h)))
    return sorted(boxes, key=lambda b: (b[1] // 200, b[0]))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    thumbs = []
    sizes = {}
    for sheet in sorted(SRC.glob("*.png")):
        img = key_background(Image.open(sheet).convert("RGBA"))
        px = sizes[sheet.stem] = pixel_size(img)
        boxes = components(np.array(img)[:, :, 3], CELL_BY_SHEET.get(sheet.stem, CELL))
        if sheet.stem in HEIGHT_BY_SHEET:  # một nhân vật: gộp mọi mảnh (tàn lửa, tua khói) thành một sprite
            boxes = [img.getbbox()]
        for i, box in enumerate(boxes):
            name = f"{sheet.stem}_{i:02d}"
            crop = img.crop(box)
            crop = crop.crop(crop.getbbox())
            if sheet.stem in HEIGHT_BY_SHEET:
                px = crop.height / HEIGHT_BY_SHEET[sheet.stem]
            crop = to_native(crop, px, sheet.stem in SMOOTH_SHEETS)
            crop.save(OUT / f"{name}.png")
            thumbs.append((name, crop))
    size, cols = 160, 10
    rows = -(-len(thumbs) // cols)
    index = Image.new("RGB", (cols * size, rows * (size + 16)), (90, 90, 90))
    draw = ImageDraw.Draw(index)
    for k, (name, crop) in enumerate(thumbs):
        f = (size - 8) / max(crop.size)
        t = crop.resize((max(1, int(crop.width * f)), max(1, int(crop.height * f))), Image.Resampling.NEAREST)
        x, y = (k % cols) * size, (k // cols) * (size + 16)
        index.paste(t, (x + 4, y + 4), t)
        draw.text((x + 4, y + size), f"{name} {crop.width}x{crop.height}", fill=(255, 255, 0))
    index.save(OUT / "_index.png")
    for name, (sheet, box, mirror) in TEXTURES.items():
        t = Image.open(SRC / f"{sheet}.png").convert("RGBA").crop(box)
        if not mirror:
            t.resize((FLOOR_PX, FLOOR_PX), Image.Resampling.BOX).convert("RGB").save(OUT / f"{name}.png")
            continue
        t = to_native(t, sizes[sheet]).convert("RGB")
        w, h = t.size
        tile = Image.new("RGB", (w * 2, h * 2))
        tile.paste(t, (0, 0))
        tile.paste(t.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (w, 0))
        tile.paste(t.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, h))
        tile.paste(t.transpose(Image.Transpose.ROTATE_180), (w, h))
        tile.save(OUT / f"{name}.png")
    print(len(thumbs), "sprites,", len(TEXTURES), "textures; pixel size per sheet:", sizes)


if __name__ == "__main__":
    main()
