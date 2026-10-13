"""Draws the CareLoop (patient) and CareLoop Pro (doctor) launcher icons.

Each icon is split into the two layers of an Android adaptive icon on a 1024 px canvas
(background full bleed, symbol inside the safe zone ~250..774). Writes, per app, into icons/<slug>/:
  background.png, foreground.png   adaptive-icon layers
  icon.png                         both layers on a rounded square (legacy launchers, web)
and store/<slug>-512.png (Play Store) plus store/icons-preview.png.

Glyph outlines are from Lucide (ISC licence), the icon set the apps use.
Needs: pip install cairosvg pillow
Run:   python3 tool/make_icons.py
"""
import io
import json
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
S = 1024

HEART = "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"
PULSE = "M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"
STETHOSCOPE = ('<path d="M11 2v2"/><path d="M5 2v2"/><path d="M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1"/>'
               '<path d="M8 15a6 6 0 0 0 12 0v-3"/><circle cx="20" cy="10" r="2"/>')


def glyph(body, cx, cy, size, color, width, fill="none"):
    k = size / 24
    return (f'<g transform="translate({cx - size / 2} {cy - size / 2}) scale({k})" fill="{fill}" stroke="{color}" '
            f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">{body}</g>')


def careloop():
    # Patient app: calm teal field with a soft light bloom; a white heart with a coral heartbeat through it.
    bg = ('<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#19B39C"/>'
          '<stop offset="1" stop-color="#0B5A54"/></linearGradient>'
          '<radialGradient id="b" cx="30%" cy="25%" r="60%"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".28"/>'
          '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient></defs>'
          '<rect width="1024" height="1024" fill="url(#g)"/><rect width="1024" height="1024" fill="url(#b)"/>')
    fg = (glyph(f'<path d="{HEART}"/>', 512, 530, 470, "#FFFFFF", 0, fill="#FFFFFF")
          + glyph(f'<path d="{PULSE}"/>', 512, 530, 470, "#FF7A59", 2.1)
          + '<circle cx="716" cy="330" r="34" fill="#FF7A59" stroke="#FFFFFF" stroke-width="14"/>')
    return bg, fg


def careloop_pro():
    # Doctor app: deep navy to indigo, a white stethoscope with an amber chest piece.
    bg = ('<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#27307A"/>'
          '<stop offset="1" stop-color="#0E1330"/></linearGradient>'
          '<radialGradient id="b" cx="75%" cy="20%" r="55%"><stop offset="0" stop-color="#6366F1" stop-opacity=".55"/>'
          '<stop offset="1" stop-color="#6366F1" stop-opacity="0"/></radialGradient></defs>'
          '<rect width="1024" height="1024" fill="url(#g)"/><rect width="1024" height="1024" fill="url(#b)"/>')
    fg = (glyph(STETHOSCOPE, 500, 512, 440, "#FFFFFF", 2.2)
          # Amber chest piece over the glyph's circle at (20, 10) in its 24-unit grid.
          + f'<circle cx="{500 - 220 + 20 * 440 / 24:.1f}" cy="{512 - 220 + 10 * 440 / 24:.1f}" r="62" fill="#F59E0B" stroke="#FFFFFF" stroke-width="22"/>')
    return bg, fg


ICONS = {"careloop": careloop, "careloop_pro": careloop_pro}


def render(body):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">{body}</svg>'
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert("RGBA")


def rounded_mask(size, radius_frac=0.225):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * radius_frac), fill=255)
    return m


def main():
    apps = json.loads((ROOT / "apps.json").read_text())
    (ROOT / "store").mkdir(exist_ok=True)
    tiles = []
    for app in apps:
        slug = app["slug"]
        bg_svg, fg_svg = ICONS[slug]()
        out = ROOT / "icons" / slug
        out.mkdir(parents=True, exist_ok=True)
        bg, fg = render(bg_svg), render(fg_svg)
        bg.save(out / "background.png", optimize=True)
        fg.save(out / "foreground.png", optimize=True)
        # The launcher shows the middle 72/108 of an adaptive icon; crop the same way for the flat icon.
        inset = round(S * 18 / 108)
        full = Image.alpha_composite(bg, fg).crop((inset, inset, S - inset, S - inset)).resize((S, S), Image.LANCZOS)
        icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        icon.paste(full, (0, 0), rounded_mask(S))
        icon.save(out / "icon.png", optimize=True)
        icon.resize((512, 512), Image.LANCZOS).save(ROOT / "store" / f"{slug}-512.png", optimize=True)
        tiles.append(icon.resize((240, 240), Image.LANCZOS))
        print("icon", slug)

    pad = 40
    sheet = Image.new("RGBA", (len(tiles) * 240 + (len(tiles) + 1) * pad, 240 + 2 * pad), "#E8EBF0")
    for i, t in enumerate(tiles):
        sheet.paste(t, (pad + i * (240 + pad), pad), t)
    sheet.save(ROOT / "store" / "icons-preview.png", optimize=True)


if __name__ == "__main__":
    main()
