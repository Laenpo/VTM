#!/usr/bin/env python3
"""Generate VTM App Icon — all required sizes."""

import os
import json
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = "/Users/alexzhang/WorkBuddy/2026-05-08-task-2/VTM-ios/VTM/VTM/Assets.xcassets/AppIcon.appiconset"
ICON_SIZE = 1024

# Apple required sizes for iOS (points → pixels at 1x/2x/3x)
IOS_SIZES = [
    ("iPhone 20pt 2x", 40),
    ("iPhone 20pt 3x", 60),
    ("iPhone 29pt 2x", 58),
    ("iPhone 29pt 3x", 87),
    ("iPhone 40pt 2x", 80),
    ("iPhone 40pt 3x", 120),
    ("iPhone 60pt 2x", 120),
    ("iPhone 60pt 3x", 180),
    ("iPad 20pt 1x", 20),
    ("iPad 20pt 2x", 40),
    ("iPad 29pt 1x", 29),
    ("iPad 29pt 2x", 58),
    ("iPad 40pt 1x", 40),
    ("iPad 40pt 2x", 80),
    ("iPad 76pt 1x", 76),
    ("iPad 76pt 2x", 152),
    ("iPad 83.5pt 2x", 167),
    ("App Store 1024pt 1x", 1024),
]


def make_gradient_bg(size):
    """Create a deep blue-to-purple gradient background."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        t = y / size
        r = int(37 + (124 - 37) * t)    # #25 → #7C
        g = int(99 + (58 - 99) * t)     # #63 → #3A
        b = int(235 + (237 - 235) * t)  # #EB → #ED
        for x in range(size):
            img.putpixel((x, y), (r, g, b, 255))
    return img


def draw_rounded_rect(draw, xy, radius, fill):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill)


def draw_waveform(draw, cx, cy, size, color):
    """Draw stylized waveform bars."""
    bar_count = 7
    bar_width = size * 0.06
    gap = size * 0.03
    total_width = bar_count * bar_width + (bar_count - 1) * gap
    start_x = cx - total_width / 2

    heights = [0.35, 0.60, 0.45, 0.80, 0.50, 0.65, 0.40]
    for i, h_ratio in enumerate(heights):
        x = start_x + i * (bar_width + gap)
        bar_h = size * h_ratio
        bar_y = cy - bar_h / 2
        r = bar_width / 2
        draw.rounded_rectangle(
            [x, bar_y, x + bar_width, bar_y + bar_h],
            radius=r,
            fill=color,
        )


def make_icon(size):
    """Generate a single icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background — rounded square with gradient
    bg = make_gradient_bg(size)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = int(size * 0.225)  # ~23% for iOS-style rounded corners
    mask_draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=255)
    img.paste(bg, (0, 0), mask)

    # Central elements scale factor
    s = size / ICON_SIZE

    # White circle background for icon
    circle_r = int(160 * s)
    circle_cx = size // 2
    circle_cy = int(380 * s)
    draw.ellipse(
        [circle_cx - circle_r, circle_cy - circle_r,
         circle_cx + circle_r, circle_cy + circle_r],
        fill=(255, 255, 255, 255),
    )

    # Inner blue circle
    inner_r = int(100 * s)
    draw.ellipse(
        [circle_cx - inner_r, circle_cy - inner_r,
         circle_cx + inner_r, circle_cy + inner_r],
        fill=(37, 99, 235, 255),  # blue-600
    )

    # Waveform bars in white
    waveform_color = (255, 255, 255, 255)
    draw_waveform(draw, circle_cx, circle_cy, inner_r * 1.5, waveform_color)

    # "VTM" text
    text = "VTM"
    text_y = int(700 * s)
    font_size = max(int(160 * s), 12)
    font = None
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SF-Pro-Display-Bold.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ]
    for fp in font_paths:
        try:
            font = ImageFont.truetype(fp, font_size)
            break
        except (OSError, IOError):
            continue
    if font is None:
        font = ImageFont.load_default()

    try:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_x = (size - text_w) // 2
        # Use text anchor for better centering
        draw.text((size // 2, text_y), text, fill=(255, 255, 255, 255),
                  font=font, anchor="ma")
    except Exception:
        pass  # skip text if font rendering fails at tiny sizes

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Generate all sizes
    images_list = []
    for name, px in IOS_SIZES:
        filename = f"appicon-{px}x{px}.png"
        filepath = os.path.join(OUTPUT_DIR, filename)
        icon = make_icon(px)
        icon.save(filepath, "PNG")
        images_list.append({"name": name, "size": px, "file": filename})
        print(f"  ✅ {name} ({px}×{px}) → {filename}")

    # Update Contents.json
    contents = {
        "images": [
            {
                "filename": f"appicon-40x40.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "20x20",
            },
            {
                "filename": f"appicon-60x60.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "20x20",
            },
            {
                "filename": f"appicon-58x58.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "29x29",
            },
            {
                "filename": f"appicon-87x87.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "29x29",
            },
            {
                "filename": f"appicon-80x80.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "40x40",
            },
            {
                "filename": f"appicon-120x120.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "40x40",
            },
            {
                "filename": f"appicon-120x120.png",
                "idiom": "iphone",
                "scale": "2x",
                "size": "60x60",
            },
            {
                "filename": f"appicon-180x180.png",
                "idiom": "iphone",
                "scale": "3x",
                "size": "60x60",
            },
            {
                "filename": f"appicon-20x20.png",
                "idiom": "ipad",
                "scale": "1x",
                "size": "20x20",
            },
            {
                "filename": f"appicon-40x40.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "20x20",
            },
            {
                "filename": f"appicon-29x29.png",
                "idiom": "ipad",
                "scale": "1x",
                "size": "29x29",
            },
            {
                "filename": f"appicon-58x58.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "29x29",
            },
            {
                "filename": f"appicon-40x40.png",
                "idiom": "ipad",
                "scale": "1x",
                "size": "40x40",
            },
            {
                "filename": f"appicon-80x80.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "40x40",
            },
            {
                "filename": f"appicon-76x76.png",
                "idiom": "ipad",
                "scale": "1x",
                "size": "76x76",
            },
            {
                "filename": f"appicon-152x152.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "76x76",
            },
            {
                "filename": f"appicon-167x167.png",
                "idiom": "ipad",
                "scale": "2x",
                "size": "83.5x83.5",
            },
            {
                "filename": f"appicon-1024x1024.png",
                "idiom": "ios-marketing",
                "scale": "1x",
                "size": "1024x1024",
            },
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }

    contents_path = os.path.join(OUTPUT_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"\n📄 Contents.json updated ({len(contents['images'])} entries)")
    print("🎉 App Icon generation complete!")


if __name__ == "__main__":
    main()
