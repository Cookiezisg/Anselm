#!/usr/bin/env python3
"""Generate the desktop app icons from the Anselm brand geometry.

The brand icon is a white rounded square with the six-square mark (3 · 2 · 1) in near-black:
in a 512 canvas the squares are 88 wide on a 106 grid, inset 106 on every side. This script
draws that geometry at full resolution instead of rasterising the SVG, so there is no extra
tool in the pipeline:

  • macOS  — Apple's template: a 1024 canvas with the 824-point rounded square centred and a
             soft shadow, exported at every size Assets.xcassets/AppIcon.appiconset lists.
  • Windows — full-bleed rounded square packed into app_icon.ico (16/32/48/256).

从品牌几何生成桌面图标。品牌图标=白色圆角方 + 近黑六方块(3·2·1):512 画布上方块宽 88、网格 106、四周
内缩 106。这里按几何直接高分辨率绘制而不是栅格化 SVG,流水线不多带工具:macOS 按 Apple 模板(1024 画布
居中 824 圆角方 + 柔和阴影,导出 AppIcon.appiconset 列出的每个尺寸);Windows 为满幅圆角方打进 .ico。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent.parent  # frontend/
MAC = HERE / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
WIN = HERE / "windows/runner/resources/app_icon.ico"

WHITE, INK = (255, 255, 255, 255), (20, 20, 20, 255)


def tile(size: int, radius_ratio: float) -> Image.Image:
    """The brand tile at `size` px: white rounded square with the mark, transparent corners."""
    s = 8  # supersample for clean edges
    n = size * s
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * radius_ratio), fill=WHITE)
    unit, grid, inset = 88 / 512, 106 / 512, 106 / 512
    for row, cols in enumerate((3, 2, 1)):
        for col in range(cols):
            x0 = (inset + col * grid) * n
            y0 = (inset + row * grid) * n
            d.rectangle([x0, y0, x0 + unit * n, y0 + unit * n], fill=INK)
    return img.resize((size, size), Image.LANCZOS)


def macos_icon(canvas: int = 1024) -> Image.Image:
    """Apple's macOS template: 824/1024 rounded square, ~22.4% corner, drop shadow below."""
    inner = round(canvas * 824 / 1024)
    t = tile(inner, 0.2237)
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    # Shadow: the tile's alpha, blurred and offset down, at ~30% black.
    shadow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    alpha = t.split()[3]
    shadow_layer = Image.new("RGBA", t.size, (0, 0, 0, 77))
    shadow_layer.putalpha(alpha.point(lambda a: a * 77 // 255))
    off = (canvas - inner) // 2
    shadow.paste(shadow_layer, (off, off + round(canvas * 0.012)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(canvas * 0.012))
    img.alpha_composite(shadow)
    img.alpha_composite(t, (off, off))
    return img


def main() -> None:
    base = macos_icon()
    for size in (16, 32, 64, 128, 256, 512, 1024):
        out = MAC / f"app_icon_{size}.png"
        base.resize((size, size), Image.LANCZOS).save(out)
        print(f"✓ {out.relative_to(HERE)}")
    win = tile(256, 114 / 512)
    win.save(WIN, sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
    print(f"✓ {WIN.relative_to(HERE)}")


if __name__ == "__main__":
    main()
