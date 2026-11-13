#!/usr/bin/env python3
"""Generate every PaperBook launcher/app icon from assets/logo/paperbook.png.

The source art is a black rounded tile with a white open-book mark and a lime
bookmark, sitting on a white canvas. This script crops away the white canvas,
extracts the mark and re-composites it crisply at each required size.

Run from the project root:  python3 tool/generate_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "logo" / "paperbook.png"

# Measured from the source artwork (the black tile inside the white canvas).
TILE_BOX = (321, 337, 933, 927)
TILE_BG = (3, 3, 3)

# Relative width of the book mark inside the tile (as in the source art).
MARK_RATIO = 445 / 612.0

# Safer ratios for round / adaptive masks.
MASKABLE_RATIO = 0.58
ADAPTIVE_FOREGROUND_RATIO = 0.52
CONTENT_RATIO = 0.86  # macOS / Windows: tile with breathing room


def extract_tile(src: Image.Image) -> Image.Image:
    """Crop the tile and build a faithful alpha silhouette around its corners."""
    tile = src.crop(TILE_BOX).convert("RGB")
    w, h = tile.size
    gray = tile.convert("L")
    gp = gray.load()

    # Flood-fill the white canvas from the outside; anything not reached is
    # part of the tile (this also keeps the white book mark opaque).
    white = [[gp[x, y] > 128 for x in range(w)] for y in range(h)]
    outside = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []

    def seed(x: int, y: int) -> None:
        if white[y][x] and not outside[y][x]:
            outside[y][x] = True
            stack.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while stack:
        x, y = stack.pop()
        if x > 0:
            seed(x - 1, y)
        if x + 1 < w:
            seed(x + 1, y)
        if y > 0:
            seed(x, y - 1)
        if y + 1 < h:
            seed(x, y + 1)

    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if outside[y][x]:
                ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))

    tile_rgba = tile.convert("RGBA")
    tile_rgba.putalpha(alpha)
    return tile_rgba.crop(alpha.getbbox())


def extract_mark(tile_rgba: Image.Image) -> Image.Image:
    """Return the white/lime book mark on transparency, tightly cropped."""
    w, h = tile_rgba.size
    flat = Image.new("RGBA", (w, h), TILE_BG + (255,))
    flat.alpha_composite(tile_rgba)

    # Only look well inside the tile: this excludes the anti-aliased rim while
    # still fully containing the mark.
    inset = 60
    px = flat.load()
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(inset, h - inset):
        for x in range(inset, w - inset):
            if max(px[x, y][:3]) > 40:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

    mark = Image.new("RGBA", (max_x - min_x + 1, max_y - min_y + 1), (0, 0, 0, 0))
    mp = mark.load()
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            r, g, b, _ = px[x, y]
            peak = max(r, g, b)
            if peak < 6:
                continue
            # Un-premultiply from the black background.
            scale = 255.0 / peak
            mp[x - min_x, y - min_y] = (
                min(255, round(r * scale)),
                min(255, round(g * scale)),
                min(255, round(b * scale)),
                peak,
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


def full_bleed_icon(mark: Image.Image, size: int) -> Image.Image:
    out = Image.new("RGBA", (size, size), TILE_BG + (255,))
    out.alpha_composite(centered_mark(mark, size, MARK_RATIO))
    return out


def maskable_icon(mark: Image.Image, size: int) -> Image.Image:
    out = Image.new("RGBA", (size, size), TILE_BG + (255,))
    out.alpha_composite(centered_mark(mark, size, MASKABLE_RATIO))
    return out


def rounded_tile(tile: Image.Image, size: int) -> Image.Image:
    """Authentic rounded tile, optionally with macOS/Windows style padding."""
    scale = (size * CONTENT_RATIO) / max(tile.size)
    content = (max(1, round(tile.width * scale)), max(1, round(tile.height * scale)))
    tile = tile.resize(content, Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(tile, ((size - content[0]) // 2, (size - content[1]) // 2))
    return out


def legacy_tile(tile: Image.Image, size: int) -> Image.Image:
    """Rounded tile that fills the launcher bitmap edge to edge."""
    scale = size / max(tile.size)
    content = (max(1, round(tile.width * scale)), max(1, round(tile.height * scale)))
    tile = tile.resize(content, Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(tile, ((size - content[0]) // 2, (size - content[1]) // 2))
    return out


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    tile = extract_tile(src)
    mark = extract_mark(tile)
    print(f"tile: {tile.size[0]}x{tile.size[1]}  mark: {mark.size[0]}x{mark.size[1]}")

    # ---- In-app logo + web splash mark ------------------------------------
    save_png(full_bleed_icon(mark, 512).convert("RGB"),
             ROOT / "assets" / "logo" / "paperbook_icon.png")
    save_png(scaled_mark(mark, 256), ROOT / "web" / "brand-mark.png")

    # ---- Android ----------------------------------------------------------
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                          "xxhdpi": 144, "xxxhdpi": 192}.items():
        save_png(legacy_tile(tile, size), android_res / f"mipmap-{density}" / "ic_launcher.png")

    for density, size in {"mdpi": 108, "hdpi": 162, "xhdpi": 216,
                          "xxhdpi": 324, "xxxhdpi": 432}.items():
        save_png(centered_mark(mark, size, ADAPTIVE_FOREGROUND_RATIO),
                 android_res / f"mipmap-{density}" / "ic_launcher_foreground.png")
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
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    colors = android_res / "values" / "colors.xml"
    text = colors.read_text()
    if "ic_launcher_background" not in text:
        text = text.replace(
            "</resources>",
            '    <!-- App icon tile colour. -->\n'
            '    <color name="ic_launcher_background">#030303</color>\n'
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
        save_png(full_bleed_icon(mark, size).convert("RGB"), ios / name)

    # ---- macOS ------------------------------------------------------------
    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(rounded_tile(tile, size), macos / f"app_icon_{size}.png")

    # ---- Web --------------------------------------------------------------
    web_icons = ROOT / "web" / "icons"
    save_png(full_bleed_icon(mark, 192).convert("RGB"), web_icons / "Icon-192.png")
    save_png(full_bleed_icon(mark, 512).convert("RGB"), web_icons / "Icon-512.png")
    save_png(maskable_icon(mark, 192).convert("RGB"), web_icons / "Icon-maskable-192.png")
    save_png(maskable_icon(mark, 512).convert("RGB"), web_icons / "Icon-maskable-512.png")
    save_png(full_bleed_icon(mark, 64).convert("RGB"), ROOT / "web" / "favicon.png")

    # ---- Windows ----------------------------------------------------------
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    frames = [rounded_tile(tile, s) for s in (16, 24, 32, 48, 64, 128, 256)]
    frames[-1].save(ico_path, format="ICO",
                    sizes=[(f.width, f.height) for f in frames],
                    append_images=frames[:-1])

    print("icons generated")


if __name__ == "__main__":
    main()
