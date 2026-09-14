#!/usr/bin/env python3
"""Render the DMG window background (macos/dmg/background.png).

Layout follows what well-known Mac apps ship (Raycast, Arc, Linear): a roomy window, large icons,
a dark brand-toned backdrop, the wordmark in the corner, one arrow, one line of instruction. The
Finder window is 800×500 points and the image is rendered at 2× for Retina. Only the backdrop,
arrow and text are drawn here; the app icon and the Applications alias are real Finder items that
create-dmg positions on top (see tool/package.sh), so their slots are left empty.

DMG 窗口背景:照知名 Mac 应用的做法(Raycast、Arc、Linear)——宽敞窗口、大图标、深色品牌底、角落放
wordmark、一支箭头、一行说明。窗口 800×500 点,2× 渲染保证 Retina 清晰。这里只画底、箭头和文字;app
图标与 Applications 别名是 Finder 真实条目,由 create-dmg 摆上去(见 tool/package.sh),故留空位。
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, S = 800, 500, 2
# Icon slots in window points; tool/package.sh passes the same numbers to create-dmg.
APP_X, DROP_X, ICON_Y, ICON = 230, 570, 235, 176
# Light palette (the app's light theme). Finder draws icon labels in the system label colour, which
# is black in light mode, so a light backdrop keeps "Anselm" / "Applications" legible for the
# majority case; the caption carries the instruction either way.
# 浅色调色板(app 浅色主题)。Finder 用系统标签色画图标名,浅色模式下是黑字,浅底才能让两个图标名可读。
SEA, INK, INK_2, INK_3, ACCENT = (245, 245, 247), (29, 29, 31), (110, 110, 115), (142, 142, 147), (0, 113, 227)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    # HelveticaNeue.ttc face 0 is Regular and face 1 is Bold; SFCompact.ttf is a single bold-ish
    # face, so it is only a fallback. HelveticaNeue.ttc 的 0 号是 Regular、1 号是 Bold。
    candidates = [
        ("/System/Library/Fonts/HelveticaNeue.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/Helvetica.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/SFCompact.ttf", 0),
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size * S, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def mark(draw: ImageDraw.ImageDraw, x: int, y: int, unit: int, fill) -> None:
    """The six-square Anselm mark (3 · 2 · 1), one `unit` per square with a half-unit gap."""
    gap = unit // 2
    for row, cols in enumerate((3, 2, 1)):
        for col in range(cols):
            x0 = x + col * (unit + gap)
            y0 = y + row * (unit + gap)
            draw.rectangle([x0, y0, x0 + unit, y0 + unit], fill=fill)


def main(out: Path) -> None:
    w, h = W * S, H * S
    # Backdrop: the app's light "sea" with a faint blue bloom top-left.
    img = Image.new("RGB", (w, h), SEA)
    glow = Image.new("RGB", (w, h), SEA)
    g = ImageDraw.Draw(glow)
    g.ellipse([-w * 0.25, -h * 0.6, w * 0.55, h * 0.5], fill=(222, 232, 246))
    glow = glow.filter(ImageFilter.GaussianBlur(160 * S))
    img = Image.blend(img, glow, 0.9)
    d = ImageDraw.Draw(img)

    # Wordmark top-left.
    mark(d, 40 * S, 36 * S, 9 * S, INK)
    f = font(17, bold=True)
    d.text((88 * S, 34 * S), "Anselm", fill=INK, font=f)

    # Large ghosted mark in the top-right corner as a brand watermark, clear of the icons and text.
    mark(d, (W - 236) * S, 24 * S, 40 * S, (233, 233, 236))

    # Arrow between the two icon slots, clear of both icons.
    y = ICON_Y * S
    x0, x1 = (APP_X + ICON // 2 + 28) * S, (DROP_X - ICON // 2 - 28) * S
    d.line([(x0, y), (x1 - 16 * S, y)], fill=INK_3, width=4 * S)
    d.polygon([(x1, y), (x1 - 22 * S, y - 13 * S), (x1 - 22 * S, y + 13 * S)], fill=INK_3)

    # Instruction under the icons.
    title = "Drag Anselm to your Applications folder"
    f1 = font(18, bold=True)
    tw = d.textlength(title, font=f1)
    d.text(((w - tw) / 2, (ICON_Y + ICON // 2 + 52) * S), title, fill=INK, font=f1)
    sub = "Runs entirely on this Mac. Open it from Launchpad when the copy finishes."
    f2 = font(13)
    tw2 = d.textlength(sub, font=f2)
    d.text(((w - tw2) / 2, (ICON_Y + ICON // 2 + 82) * S), sub, fill=INK_2, font=f2)

    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, dpi=(72 * S, 72 * S))
    print(f"✓ {out} ({W}×{H}@{S}x)")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "macos/dmg/background.png"))
