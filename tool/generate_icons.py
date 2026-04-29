"""Generate every platform icon from the recolored fish master.

Run from the repo root:
    python3 tool/generate_icons.py

Source: assets/branding/source_fish.png (the original screenshot the user pasted).
Outputs:
    assets/branding/   — masters + the in-app logo
    ios/Runner/Assets.xcassets/AppIcon.appiconset/
    macos/Runner/Assets.xcassets/AppIcon.appiconset/
    android/app/src/main/res/mipmap-*/
    android/app/src/main/res/mipmap-anydpi-v26/  (adaptive icon XML)
    android/app/src/main/res/drawable/ic_launcher_foreground.png
    android/app/src/main/res/values/ic_launcher_background.xml
    web/favicon.png
    web/icons/Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png

The fish has a tall aspect (~3:1), so square icons end up with generous
horizontal margins. We bias toward smaller margins on iOS/macOS so the fish
is still legible at 16–40px sizes; maskable PWA icons use the spec-mandated
larger safe area instead.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "source_fish.png"
BRANDING = ROOT / "assets" / "branding"

# ── colors ────────────────────────────────────────────────────────────────────
MAROON = (139, 30, 44)            # AppColors.maroonSeed (0xFF8B1E2C)
CREAM = (251, 246, 246)           # AppColors.lightScaffold (0xFFFBF6F6)
ANDROID_ADAPTIVE_BG_HEX = "#FBF6F6"

# Source image colors used to extract foreground/background:
SRC_BG = np.array([175, 206, 214], dtype=np.float32)
SRC_NAVY = np.array([20, 28, 36], dtype=np.float32)
SRC_WHITE = np.array([254, 254, 245], dtype=np.float32)


# ── recolor pass ──────────────────────────────────────────────────────────────
def _fit_blend(rgb: np.ndarray, c0: np.ndarray, c1: np.ndarray):
    """Best-fit α (clipped) and residual norm for the model rgb = (1-α)c0 + αc1."""
    delta = c1 - c0
    denom = float(np.dot(delta, delta))
    alpha = np.sum((rgb - c0) * delta, axis=2, keepdims=True) / denom
    alpha_clipped = np.clip(alpha, 0.0, 1.0)
    pred = c0 + alpha_clipped * delta
    residual = np.sqrt(np.sum((rgb - pred) ** 2, axis=2, keepdims=True))
    return alpha_clipped, residual


def recolor_to_maroon_transparent(src_path: Path) -> Image.Image:
    """Strict two-color recolor.

    For every source pixel pick the blend model (bg+navy, bg+white, navy+white)
    with the smallest residual, then map that pixel to either pure maroon or
    pure white. Alpha carries all anti-aliasing; the output never contains an
    intermediate hue.
    """
    src = np.array(Image.open(src_path).convert("RGBA")).astype(np.float32)
    rgb = src[..., :3]

    # Three models — α encodes coverage of the second color in each pair.
    a_bg_navy, res_bg_navy = _fit_blend(rgb, SRC_BG, SRC_NAVY)         # → MAROON @ α
    a_bg_white, res_bg_white = _fit_blend(rgb, SRC_BG, SRC_WHITE)      # → WHITE @ α
    a_navy_white, res_navy_white = _fit_blend(rgb, SRC_NAVY, SRC_WHITE)  # interior

    residuals = np.concatenate([res_bg_navy, res_bg_white, res_navy_white], axis=2)
    best = np.argmin(residuals, axis=2, keepdims=True)

    # Alpha per model: 1.0 for the interior model, blend coverage otherwise.
    ones = np.ones_like(a_bg_navy)
    alpha = np.where(
        best == 0, a_bg_navy,
        np.where(best == 1, a_bg_white, ones),
    )

    # Class per model: model 0 → MAROON, model 1 → WHITE,
    # model 2 → MAROON if α<0.5 (navy-dominant) else WHITE.
    is_maroon = np.where(
        best == 0, ones,
        np.where(best == 1, np.zeros_like(a_bg_navy),
                 (a_navy_white < 0.5).astype(np.float32)),
    )

    # Floor suppresses the soft drop-shadow at the bottom of the source.
    floor = 0.18
    alpha = np.clip((alpha - floor) / (1.0 - floor), 0.0, 1.0)

    maroon_arr = np.array(MAROON, dtype=np.float32)
    white_arr = np.array([255.0, 255.0, 255.0], dtype=np.float32)
    color = is_maroon * maroon_arr + (1.0 - is_maroon) * white_arr

    out = np.concatenate([color, alpha * 255.0], axis=2)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    return img.crop(img.getbbox())


def fit_into_square(content: Image.Image, size: int, margin_ratio: float) -> Image.Image:
    """Center `content` on a transparent square `size` with `margin_ratio` padding."""
    cw, ch = content.size
    target = int(size * (1 - 2 * margin_ratio))
    scale = min(target / cw, target / ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    resized = content.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2), resized)
    return canvas


def square_with_bg(
    content: Image.Image,
    size: int,
    bg_rgb: tuple[int, int, int],
    margin_ratio: float,
) -> Image.Image:
    """Solid `bg_rgb` square with `content` centered and `margin_ratio` padding."""
    canvas = Image.new("RGBA", (size, size), (*bg_rgb, 255))
    fg = fit_into_square(content, size, margin_ratio)
    canvas.alpha_composite(fg)
    return canvas


def rounded_square_with_bg(
    content: Image.Image,
    canvas_size: int,
    bg_rgb: tuple[int, int, int],
    *,
    shape_inset_ratio: float,    # inset of the rounded square from the canvas edge
    corner_radius_ratio: float,   # corner radius as fraction of the rounded square size
    content_inside_margin: float,  # margin of content within the rounded square
) -> Image.Image:
    """macOS-style rounded-square icon with transparent ring around the shape."""
    inset = int(round(canvas_size * shape_inset_ratio))
    shape_size = canvas_size - 2 * inset
    radius = int(round(shape_size * corner_radius_ratio))

    # Draw the rounded shape onto a transparent canvas.
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (inset, inset, inset + shape_size - 1, inset + shape_size - 1),
        radius=radius,
        fill=(*bg_rgb, 255),
    )

    # Place the content inside the rounded square with its own margin.
    content_target = int(round(shape_size * (1 - 2 * content_inside_margin)))
    cw, ch = content.size
    scale = min(content_target / cw, content_target / ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    resized = content.resize((new_w, new_h), Image.LANCZOS)
    cx = inset + (shape_size - new_w) // 2
    cy = inset + (shape_size - new_h) // 2
    canvas.alpha_composite(resized, (cx, cy))
    return canvas


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"  → {path.relative_to(ROOT)}  ({img.size[0]}×{img.size[1]})")


def flatten_for_ios(img: Image.Image, bg_rgb: tuple[int, int, int]) -> Image.Image:
    """iOS rejects icons with alpha; flatten onto an opaque background."""
    bg = Image.new("RGB", img.size, bg_rgb)
    bg.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
    return bg


# ── main ──────────────────────────────────────────────────────────────────────
def main() -> None:
    print("Recoloring source...")
    fish = recolor_to_maroon_transparent(SOURCE)
    print(f"  cropped fish: {fish.size}")
    save(fish, BRANDING / "logo_cropped.png")

    # In-app logo: the fish on a transparent 1024px square (referenced as
    # `assets/branding/logo.png` from pubspec.yaml).
    logo_square_1024 = fit_into_square(fish, 1024, margin_ratio=0.05)
    save(logo_square_1024, BRANDING / "logo.png")

    # iOS-style master: opaque cream background, square with small margin.
    print("\niOS icons...")
    ios_master = square_with_bg(fish, 1024, CREAM, margin_ratio=0.06)
    save(ios_master, BRANDING / "ios_master_1024.png")

    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_specs = {
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
    }
    for name, size in ios_specs.items():
        # Resize from the high-res master so anti-aliasing is consistent.
        out = ios_master.resize((size, size), Image.LANCZOS)
        out = flatten_for_ios(out, CREAM)
        save(out, ios_dir / name)

    # macOS master: rounded squircle on transparent canvas (Apple icon-grid style).
    print("\nmacOS icons...")
    mac_master = rounded_square_with_bg(
        fish,
        1024,
        CREAM,
        shape_inset_ratio=0.098,       # ~100px inset on a 1024 canvas
        corner_radius_ratio=0.2237,     # Apple's ~22.4% corner radius
        content_inside_margin=0.06,
    )
    save(mac_master, BRANDING / "macos_master_1024.png")

    macos_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in macos_sizes:
        out = mac_master.resize((size, size), Image.LANCZOS)
        save(out, macos_dir / f"app_icon_{size}.png")

    # Android legacy launcher icons (one PNG per density).
    print("\nAndroid icons...")
    android_master = square_with_bg(fish, 1024, CREAM, margin_ratio=0.10)
    save(android_master, BRANDING / "android_master_1024.png")

    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    android_legacy = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_legacy.items():
        out = android_master.resize((size, size), Image.LANCZOS)
        save(out, android_res / folder / "ic_launcher.png")

    # Adaptive icon (Android 8+): foreground is the fish only, transparent bg
    # (the system layers it onto a solid color from the values resource). The
    # foreground must fit within the inner ~66dp safe zone of a 108dp drawable,
    # so apply an extra ~22% margin on top of the artwork.
    adaptive_fg = fit_into_square(fish, 432, margin_ratio=0.22)
    for folder, size in {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }.items():
        out = adaptive_fg.resize((size, size), Image.LANCZOS)
        save(out, android_res / folder / "ic_launcher_foreground.png")

    anydpi = android_res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    print(f"  → {(anydpi / 'ic_launcher.xml').relative_to(ROOT)}")

    values = android_res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{ANDROID_ADAPTIVE_BG_HEX}</color>\n'
        '</resources>\n'
    )
    print(f"  → {(values / 'ic_launcher_background.xml').relative_to(ROOT)}")

    # Web favicon + PWA icons.
    print("\nWeb icons...")
    web = ROOT / "web"
    web_master = square_with_bg(fish, 1024, CREAM, margin_ratio=0.08)
    save(web_master, BRANDING / "web_master_1024.png")

    save(web_master.resize((64, 64), Image.LANCZOS), web / "favicon.png")
    save(web_master.resize((192, 192), Image.LANCZOS), web / "icons" / "Icon-192.png")
    save(web_master.resize((512, 512), Image.LANCZOS), web / "icons" / "Icon-512.png")

    # Maskable variant: extra safe-area padding so launcher masks don't crop the
    # fish (the spec wants content inside the inner 80% radius circle).
    maskable_master = square_with_bg(fish, 1024, CREAM, margin_ratio=0.22)
    save(maskable_master, BRANDING / "web_maskable_master_1024.png")
    save(maskable_master.resize((192, 192), Image.LANCZOS), web / "icons" / "Icon-maskable-192.png")
    save(maskable_master.resize((512, 512), Image.LANCZOS), web / "icons" / "Icon-maskable-512.png")

    print("\nDone.")


if __name__ == "__main__":
    main()
