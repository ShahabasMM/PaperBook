#!/usr/bin/env python3
"""Generate every PaperBook launcher/app icon from assets/logo/paperbook.png.

The source art is a full-bleed near-black canvas with a centred white open-book
mark. This script detects the mark automatically (no hard-coded crop box),
extracts it with clean alpha, and re-composites it at every required size.

Run from the project root:  python3 tool/generate_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "logo" / "paperbook.png"

# Relative width of the mark inside a square icon.
MARK_RATIO = 0.64
# Safer ratios for round / adaptive masks.
MASKABLE_RATIO = 0.56
ADAPTIVE_FOREGROUND_RATIO = 0.50
# macOS / Windows: rounded tile with breathing room.
CONTENT_RATIO = 0.86
# Rounded-corner radius as a fraction of the tile edge (Apple-style squircle).
RADIUS_RATIO = 0.225

# The artwork has a soft halo around the mark; ignore anything dimmer than this
# above the background so icons stay crisp instead of carrying the glow.
MARK_THRESHOLD = 100


def background_color(src: Image.Image) -> tuple[int, int, int]:
    """Median colour of the outer border — the artwork's tile colour."""
    w, h = src.size
    px = src.load()
    samples: list[tuple[int, int, int]] = []
    for x in range(0, w, 5):
        samples.append(px[x, 0])
        samples.append(px[x, h - 1])
    for y in range(0, h, 5):
        samples.append(px[0, y])
        samples.append(px[w - 1, y])
    samples.sort(key=sum)
    return samples[len(samples) // 2]


def mark_bbox(src: Image.Image, bg: tuple[int, int, int]) -> tuple[int, int, int, int]:
    """Tight bounding box of the bright mark, ignoring background noise."""
    w, h = src.size
    px = src.load()
    floor = max(bg) + MARK_THRESHOLD
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if max(r, g, b) > floor:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    if max_x < 0:
        raise SystemExit(f"No mark found in {SRC}")
    return min_x, min_y, max_x, max_y


def extract_mark(
    src: Image.Image,
    bg: tuple[int, int, int],
    box: tuple[int, int, int, int],
) -> Image.Image:
    """White mark on transparency, un-premultiplied from the dark background."""
    min_x, min_y, max_x, max_y = box
    w, h = max_x - min_x + 1, max_y - min_y + 1
    mark = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = src.load()
    mp = mark.load()
    bg_peak = max(bg)
    floor = bg_peak + MARK_THRESHOLD

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            r, g, b = px[x, y]
            peak = max(r, g, b)
            if peak <= floor:
                continue
            # White mark over a dark tile: the channel value IS the coverage.
            alpha = round(255 * (peak - bg_peak) / (255 - bg_peak))
            alpha = max(0, min(255, alpha))
            if alpha == 0:
                continue
            # Un-premultiply so anti-aliased edges stay white, not grey.
            scale = 255.0 / alpha
            mp[x - min_x, y - min_y] = (
                min(255, round((r - bg[0]) * scale)),
                min(255, round((g - bg[1]) * scale)),
                min(255, round((b - bg[2]) * scale)),
                alpha,
            )
    return mark


def scaled_mark(mark: Image.Image, target_width: int) -> Image.Image:
    mw, mh = mark.size
    target_height = max(1, round(mh * target_width / mw))
    return mark.resize((target_width, target_height), Image.LANCZOS)


def centered_mark(mark: Image.Image, canvas: int, ratio: float) -> Image.Image:
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    m = scaled_mark(mark, max(1, round(canvas * ratio)))
    out.alpha_composite(m, ((canvas - m.width) // 2, (canvas - m.height) // 2))
    return out


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    """Anti-aliased rounded-square mask, supersampled for smooth corners."""
    scale = 4
    big = size * scale
    radius = int(round(big * radius_ratio))
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=radius, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def square_icon(
    mark: Image.Image,
    size: int,
    tile: tuple[int, int, int],
    ratio: float,
    rounded: bool,
) -> Image.Image:
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    plate = Image.new("RGBA", (size, size), tuple(tile) + (255,))
    if rounded:
        plate.putalpha(rounded_mask(size, RADIUS_RATIO))
    out.alpha_composite(plate)
    out.alpha_composite(centered_mark(mark, size, ratio))
    return out


def rounded_tile(
    mark: Image.Image,
    size: int,
    tile: tuple[int, int, int],
    ratio: float = MARK_RATIO,
) -> Image.Image:
    """Rounded tile with macOS / Windows style padding around it."""
    content = max(1, round(size * CONTENT_RATIO))
    inner = square_icon(mark, content, tile, ratio, rounded=True)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(inner, ((size - content) // 2, (size - content) // 2))
    return out


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    tile = background_color(src)
    box = mark_bbox(src, tile)
    mark = extract_mark(src, tile, box)
    print(f"tile: {tile}  mark box: {box}  mark: {mark.size[0]}x{mark.size[1]}")

    # ---- In-app logo + web splash mark (background-free) ------------------
    # The mark stays white on transparency; the app tints it to theme ink.
    save_png(centered_mark(mark, 512, 0.96), ROOT / "assets" / "logo" / "paperbook_icon.png")
    save_png(scaled_mark(mark, 256), ROOT / "web" / "brand-mark.png")

    # ---- Android ----------------------------------------------------------
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save_png(
            square_icon(mark, size, tile, MARK_RATIO, rounded=True),
            android_res / f"mipmap-{density}" / "ic_launcher.png",
        )

    for density, size in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        save_png(
            centered_mark(mark, size, ADAPTIVE_FOREGROUND_RATIO),
            android_res / f"mipmap-{density}" / "ic_launcher_foreground.png",
        )
        mono = centered_mark(mark, size, ADAPTIVE_FOREGROUND_RATIO)
        white = Image.new("RGBA", mono.size, (255, 255, 255, 0))
        white.putalpha(mono.getchannel("A"))
        save_png(white, android_res / f"mipmap-{density}" / "ic_launcher_monochrome.png")

    anydpi = android_res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    colors = android_res / "values" / "colors.xml"
    text = colors.read_text()
    if "ic_launcher_background" not in text:
        text = text.replace(
            "</resources>",
            "    <!-- App icon tile colour. -->\n"
            f'    <color name="ic_launcher_background">#{tile[0]:02X}{tile[1]:02X}{tile[2]:02X}</color>\n'
            "</resources>",
        )
        colors.write_text(text)

    # ---- iOS --------------------------------------------------------------
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }.items():
        # App Store icons must not carry an alpha channel.
        save_png(
            square_icon(mark, size, tile, MARK_RATIO, rounded=False).convert("RGB"),
            ios / name,
        )

    # ---- macOS ------------------------------------------------------------
    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(rounded_tile(mark, size, tile), macos / f"app_icon_{size}.png")

    # ---- Web --------------------------------------------------------------
    web_icons = ROOT / "web" / "icons"
    save_png(square_icon(mark, 192, tile, MARK_RATIO, rounded=False).convert("RGB"),
             web_icons / "Icon-192.png")
    save_png(square_icon(mark, 512, tile, MARK_RATIO, rounded=False).convert("RGB"),
             web_icons / "Icon-512.png")
    save_png(square_icon(mark, 192, tile, MASKABLE_RATIO, rounded=False).convert("RGB"),
             web_icons / "Icon-maskable-192.png")
    save_png(square_icon(mark, 512, tile, MASKABLE_RATIO, rounded=False).convert("RGB"),
             web_icons / "Icon-maskable-512.png")
    save_png(square_icon(mark, 64, tile, MARK_RATIO, rounded=False).convert("RGB"),
             ROOT / "web" / "favicon.png")

    # ---- Windows ----------------------------------------------------------
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    frames = [rounded_tile(mark, s, tile) for s in (16, 24, 32, 48, 64, 128, 256)]
    frames[-1].save(
        ico_path,
        format="ICO",
        sizes=[(f.width, f.height) for f in frames],
        append_images=frames[:-1],
    )

    print("icons generated")


if __name__ == "__main__":
    main()
