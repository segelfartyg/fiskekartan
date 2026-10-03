"""Generates the app icon sources in assets/icon/: "firre" in Playpen Sans
Bold, in the web app's brand green on white. flutter_launcher_icons (see
pubspec.yaml) turns these into the per-density Android and iOS icons:

    python3 tool/generate_app_icon.py
    dart run flutter_launcher_icons

Needs Pillow (pip install pillow).
"""
from PIL import Image, ImageDraw, ImageFont

TEXT = 'firre'
FONT = 'assets/fonts/PlaypenSans-Bold.ttf'
GREEN = (0x10, 0xA1, 0x5A, 255)  # --color-primary in web/src/app.css
SIZE = 1024


def render(path, text_width_ratio, background):
    img = Image.new('RGBA', (SIZE, SIZE), background)
    draw = ImageDraw.Draw(img)
    # The largest font size whose ink fits the target width.
    size = 10
    while True:
        left, _, right, _ = draw.textbbox(
            (0, 0), TEXT, font=ImageFont.truetype(FONT, size + 2))
        if right - left > SIZE * text_width_ratio:
            break
        size += 2
    font = ImageFont.truetype(FONT, size)
    left, top, right, bottom = draw.textbbox((0, 0), TEXT, font=font)
    # Center the ink itself, not the font's line box.
    draw.text(((SIZE - (right - left)) / 2 - left,
               (SIZE - (bottom - top)) / 2 - top), TEXT, font=font, fill=GREEN)
    img.save(path)


# Legacy Android and iOS: the whole square is shown.
render('assets/icon/icon.png', 0.72, (255, 255, 255, 255))
# Android adaptive foreground: launchers show only the central 66/108 of the
# canvas and may mask that to a circle, so the text stays well inside it.
render('assets/icon/icon_foreground.png', 0.46, (0, 0, 0, 0))
