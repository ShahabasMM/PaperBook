#!/usr/bin/env python3
"""Generate every PaperBook launcher/app icon from assets/logo/paperbook_icon.png.

The source artwork is used as-is: the image is padded to a square with its own
background colour and resized for each platform. Nothing is re-drawn, recoloured
or re-composited — the only extra output is the monochrome (themed icon) mask,
which Android requires.

Run from the project root:  python3 tool/generate_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "logo" / "paperbook_icon.png"

# macOS / Windows: rounded tile with a little breathing room.
CONTENT_RATIO = 0.86
# Rounded-corner radius as a fraction of the tile edge (Apple-style squircle).
RADIUS_RATIO = 0.225
# Adaptive / maskable icons need the artwork inside the system safe zone.
ADAPTIVE_SCALE = 0.70
MASKABLE_SCALE = 0.80
# Monochrome icon: mark width relative to the layer.
MONO_RATIO = 0.46
# Anything dimmer than this above the background is treated as noise.
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


def square_art(src: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    """Pad the untouched artwork to a square using its own background colour."""
    w, h = src.size
    side = max(w, h)
    out = Image.new("RGBA", (side, side), bg + (255,))
    out.paste(src.convert("RGBA"), ((side - w) // 2, (side - h) // 2))
    return out


def resized(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    """Anti-aliased rounded-square mask, supersampled for smooth corners."""
    scale = 4
    big = size * scale
    radius = int(round(big * radius_ratio))
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=radius, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def rounded_art(square: Image.Image, size: int) -> Image.Image:
    """Rounded tile with macOS / Windows style padding."""
    content = max(1, round(size * CONTENT_RATIO))
    inner = resized(square, content)
    inner.putalpha(rounded_mask(content, RADIUS_RATIO))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(inner, ((size - content) // 2, (size - content) // 2))
    return out


def scaled_layer(
    square: Image.Image,
    size: int,
    scale: float,
    bg: tuple[int, int, int] | None,
) -> Image.Image:
    """Place the artwork at [scale] of the layer (safe zones, maskable icons)."""
    out = Image.new(
        "RGBA",
        (size, size),
        (bg + (255,)) if bg is not None else (0, 0, 0, 0),
    )
    inner = resized(square, max(1, round(size * scale)))
    out.alpha_composite(inner, ((size - inner.width) // 2, (size - inner.height) // 2))
    return out


def monochrome_mask(square: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    """Silhouette of the white mark (Android themed icons need a mask)."""
    w, h = square.size
    flat = Image.new("RGB", (w, h), bg)
    flat.paste(square.convert("RGB"), (0, 0), square.getchannel("A"))
    gray = flat.convert("L")
    gp = gray.load()
    floor = max(bg) + MARK_THRESHOLD

    # Tight crop around the mark so it can be centred in the safe zone.
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if gp[x, y] > floor:
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

    mask = Image.new("L", (max_x - min_x + 1, max_y - min_y + 1), 0)
    mp = mask.load()
    span = max(1, 255 - max(bg))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            alpha = round(255 * (gp[x, y] - max(bg)) / span)
            mp[x - min_x, y - min_y] = max(0, min(255, alpha))
    return mask.crop(mask.getbbox())


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    bg = background_color(src)
    square = square_art(src, bg)
    print(f"source: {src.size[0]}x{src.size[1]}  background: {bg}  square: {square.size[0]}")

    # ---- Android ----------------------------------------------------------
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save_png(resized(square, size), android_res / f"mipmap-{density}" / "ic_launcher.png")

    mono = monochrome_mask(square, bg)
    for density, size in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        save_png(
            scaled_layer(square, size, ADAPTIVE_SCALE, None),
            android_res / f"mipmap-{density}" / "ic_launcher_foreground.png",
        )
        # Themed icons expect a solid-colour silhouette; recolour the mask white.
        target_w = max(1, round(size * MONO_RATIO))
        target_h = max(1, round(mono.height * target_w / mono.width))
        layer = Image.new("L", (size, size), 0)
        layer.paste(
            mono.resize((target_w, target_h), Image.LANCZOS),
            ((size - target_w) // 2, (size - target_h) // 2),
        )
        white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        white.putalpha(layer)
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
            f'    <color name="ic_launcher_background">#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>\n'
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
        save_png(resized(square, size).convert("RGB"), ios / name)

    # ---- macOS ------------------------------------------------------------
    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(rounded_art(square, size), macos / f"app_icon_{size}.png")

    # ---- Web --------------------------------------------------------------
    web_icons = ROOT / "web" / "icons"
    save_png(resized(square, 192).convert("RGB"), web_icons / "Icon-192.png")
    save_png(resized(square, 512).convert("RGB"), web_icons / "Icon-512.png")
    save_png(
        scaled_layer(square, 192, MASKABLE_SCALE, bg).convert("RGB"),
        web_icons / "Icon-maskable-192.png",
    )
    save_png(
        scaled_layer(square, 512, MASKABLE_SCALE, bg).convert("RGB"),
        web_icons / "Icon-maskable-512.png",
    )
    save_png(resized(square, 64).convert("RGB"), ROOT / "web" / "favicon.png")

    # ---- Windows ----------------------------------------------------------
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    frames = [rounded_art(square, s) for s in (16, 24, 32, 48, 64, 128, 256)]
    frames[-1].save(
        ico_path,
        format="ICO",
        sizes=[(f.width, f.height) for f in frames],
        append_images=frames[:-1],
    )

    print("icons generated")


if __name__ == "__main__":
    main()
