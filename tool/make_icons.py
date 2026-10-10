"""Generates launcher icons for every app: a serif monogram in paper colour on
the app's accent colour. Run: python3 tool/make_icons.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APPS = {
    "doc_scanner": ("D", "#C2512E"),
    "doc_vault": ("V", "#1F5F5B"),
    "sign_maker": ("S", "#2B3A8C"),
    "pdf_studio": ("P", "#A3273B"),
    "ludo_star": ("L", "#6B3FA0"),
    "learn_german": ("Ä", "#3E6B48"),
    "learn_music": ("♪", "#8E3B6E"),
    "doc_writer": ("¶", "#5A4A3A"),
    "pdf_fill": ("F", "#0F6E8C"),
    "property_ghar": ("⌂", "#9C5B2E"),
    "bill_book": ("B", "#3D5A80"),
    "pf_saathi": ("PF", "#4C6A1F"),
    "vehicle_gaadi": ("G", "#3F4752"),
    "dial_abroad": ("+", "#127A7A"),
    "meet_milo": ("M", "#5B4FCF"),
    "safar_trips": ("✈", "#A26B00"),
}
PAPER = "#F6F1E7"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SYMBOL_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
ROOT = Path(__file__).resolve().parent.parent


def glyph(draw, letter, size, box, color):
    if len(letter) > 1:
        size = int(size * 0.62)
    font = ImageFont.truetype(FONT if letter.isalpha() else SYMBOL_FONT, size)
    l, t, r, b = draw.textbbox((0, 0), letter, font=font)
    w, h = r - l, b - t
    cx, cy = box
    draw.text((cx - w / 2 - l, cy - h / 2 - t - size * 0.04), letter, font=font, fill=color)
    # small underline accent, like a signature stroke
    y = cy + h / 2 + size * 0.08
    draw.rounded_rectangle((cx - w * 0.42, y, cx + w * 0.42, y + size * 0.06),
                           radius=size * 0.03, fill=color)


for app, (letter, accent) in APPS.items():
    if not (ROOT / "apps" / app).exists():
        continue
    out = ROOT / "apps" / app / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)

    full = Image.new("RGBA", (1024, 1024), accent)
    glyph(ImageDraw.Draw(full), letter, 560, (512, 500), PAPER)
    full.save(out / "icon.png")

    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    glyph(ImageDraw.Draw(fg), letter, 380, (512, 500), PAPER)
    fg.save(out / "foreground.png")
    print("icons:", app)
