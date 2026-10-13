"""Draws the launcher icon for each of the ten apps, in that app's own visual style.

Every icon is split into the two layers of an Android adaptive icon, on a 1024 px canvas:
  background: full bleed, may be cropped by the launcher's mask
  foreground: the symbol, kept inside the safe zone (roughly 250..774)
Writes, per app, into icons/<slug>/:
  background.png, foreground.png   adaptive-icon layers, 1024 px
  icon.png                         both layers on a rounded square (legacy launchers, web)
  small.png                        96 px, for the app picker in the prototype viewer
and store/<slug>-512.png plus store/all-icons-preview.png.

Glyphs are from Lucide (ISC licence), the same set the app screens use.
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

LUCIDE = {
    "wrench": '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
    "moon": '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    "hammer": '<path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18.5 14.5"/>',
    "sprout": '<path d="M7 20h10"/><path d="M10 20c5.5-2.5.8-6.4 3-10"/><path d="M9.5 9.4c1.1.8 1.8 2.2 2.3 3.7-2 .4-3.5.4-4.8-.3-1.2-.6-2.3-1.9-3-4.2 2.8-.5 4.4 0 5.5.8z"/><path d="M14.1 6a7 7 0 0 0-1.1 4c1.9-.1 3.3-.6 4.3-1.4 1-1 1.6-2.3 1.7-4.6-2.7.1-4 1-4.9 2z"/>',
    "languages": '<path d="m5 8 6 6"/><path d="m4 14 6-6 2-3"/><path d="M2 5h12"/><path d="M7 2h1"/><path d="m22 22-5-10-5 10"/><path d="M14 18h6"/>',
    "hand": '<path d="M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2"/><path d="M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2"/><path d="M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
    "scissors": '<circle cx="6" cy="6" r="3"/><path d="M8.12 8.12 12 12"/><path d="M20 4 8.12 15.88"/><circle cx="6" cy="18" r="3"/><path d="M14.8 14.8 20 20"/>',
    "leaf": '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/>',
}


def glyph(name, cx, cy, size, color, width=2.0, fill="none"):
    """A Lucide glyph centred on (cx, cy), `size` px wide, stroke `width` in the glyph's 24-unit grid."""
    k = size / 24
    return (f'<g transform="translate({cx - size / 2} {cy - size / 2}) scale({k})" fill="{fill}" stroke="{color}" '
            f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">{LUCIDE[name]}</g>')


def arc(cx, cy, r, a0, a1):
    """SVG arc path from angle a0 to a1 (degrees, 0 = 12 o'clock, clockwise)."""
    import math
    def pt(a):
        t = math.radians(a - 90)
        return cx + r * math.cos(t), cy + r * math.sin(t)
    (x0, y0), (x1, y1) = pt(a0), pt(a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f}"


# ------------------------------------------------------------------ the ten icons
# Each returns (background svg, foreground svg), both drawn on the 1024 canvas.

def lendr():
    # Neo-brutalist: yellow field, orange sun, a thick-bordered card with a hard offset shadow.
    bg = '<rect width="1024" height="1024" fill="#FFD60A"/><circle cx="880" cy="150" r="300" fill="#FF5C00"/>'
    fg = ('<rect x="330" y="330" width="400" height="400" fill="#111"/>'
          '<rect x="294" y="294" width="400" height="400" fill="#FFFFFF" stroke="#111" stroke-width="30"/>'
          + glyph("wrench", 494, 494, 250, "#111", 2.6))
    return bg, fg


def hush():
    # Night calm: deep navy, soft lavender rings like a sound fading out, a crescent moon.
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#ECEBFF" opacity="{o}"/>'
                    for x, y, r, o in [(170, 210, 6, .7), (860, 260, 5, .5), (230, 820, 4, .4), (820, 840, 7, .6),
                                       (120, 520, 4, .35), (910, 560, 4, .4), (520, 110, 5, .5)])
    bg = ('<defs><radialGradient id="g" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#2A2F66"/>'
          '<stop offset="1" stop-color="#0B1020"/></radialGradient></defs>'
          f'<rect width="1024" height="1024" fill="url(#g)"/>{stars}')
    fg = ('<circle cx="512" cy="512" r="262" fill="none" stroke="#A99BFF" stroke-width="10" opacity=".25"/>'
          '<circle cx="512" cy="512" r="206" fill="none" stroke="#A99BFF" stroke-width="12" opacity=".5"/>'
          '<circle cx="512" cy="512" r="150" fill="#A99BFF"/>'
          + glyph("moon", 512, 512, 150, "#0B1020", 0, fill="#0B1020")
          + '<circle cx="658" cy="366" r="22" fill="#5EEAD4"/>')
    return bg, fg


def use_by():
    # Fresh & chunky: green gradient, an apple-shaped countdown with a coral slice of time left.
    bg = ('<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3BD873"/>'
          '<stop offset="1" stop-color="#15964A"/></linearGradient></defs>'
          '<rect width="1024" height="1024" fill="url(#g)"/><circle cx="160" cy="900" r="320" fill="#FFFFFF" opacity=".10"/>')
    fg = ('<circle cx="512" cy="550" r="230" fill="#FFFFFF"/>'
          f'<path d="M512,550 L{arc(512, 550, 180, 0, 100)[1:]} Z" fill="#FF7A59"/>'
          '<circle cx="512" cy="550" r="40" fill="#12321F"/>'
          '<path d="M512,320 C512,280 530,250 560,232" fill="none" stroke="#12321F" stroke-width="26" stroke-linecap="round"/>'
          '<path d="M556,300 C580,236 650,216 700,232 C690,290 630,326 556,300 Z" fill="#12321F"/>')
    return bg, fg


def kin_tapes():
    # Vintage cassette: cream paper with faint ruling, a brick-red tape with a mustard label.
    rules = "".join(f'<rect x="0" y="{y}" width="1024" height="6" fill="#E6D6B6"/>' for y in range(40, 1024, 64))
    bg = f'<rect width="1024" height="1024" fill="#F3EAD8"/>{rules}'
    fg = ('<rect x="236" y="324" width="552" height="376" rx="34" fill="#C4472D"/>'
          '<rect x="276" y="360" width="472" height="150" rx="10" fill="#E0A33A"/>'
          '<rect x="306" y="400" width="250" height="20" rx="10" fill="#3B2418" opacity=".55"/>'
          '<rect x="306" y="446" width="180" height="20" rx="10" fill="#3B2418" opacity=".35"/>'
          '<rect x="346" y="546" width="332" height="96" rx="48" fill="#3B2418"/>'
          '<circle cx="412" cy="594" r="34" fill="#FBF5E8"/><circle cx="412" cy="594" r="12" fill="#3B2418"/>'
          '<circle cx="612" cy="594" r="34" fill="#FBF5E8"/><circle cx="612" cy="594" r="12" fill="#3B2418"/>'
          '<path d="M330,700 L366,650 H658 L694,700 Z" fill="#9E3622"/>')
    return bg, fg


def mend():
    # Blueprint: royal blue drafting grid, a dashed target in yellow with a hammer in it.
    grid = "".join(f'<rect x="{v}" y="0" width="3" height="1024" fill="#FFFFFF" opacity=".10"/>'
                   f'<rect x="0" y="{v}" width="1024" height="3" fill="#FFFFFF" opacity=".10"/>' for v in range(0, 1024, 64))
    bg = f'<rect width="1024" height="1024" fill="#1D3F94"/>{grid}'
    ticks = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#7DD3FC"/>'
                    for x, y, w, h in [(505, 214, 14, 70), (505, 740, 14, 70), (214, 505, 70, 14), (740, 505, 70, 14)])
    fg = ('<circle cx="512" cy="512" r="250" fill="#163378" stroke="#FACC15" stroke-width="14" stroke-dasharray="36 22"/>'
          + ticks + glyph("hammer", 512, 512, 290, "#FACC15", 2.3))
    return bg, fg


def plotswap():
    # Organic garden: cream with a soil band, a leaf-cornered olive plot, a sprout and a ripe orange fruit.
    bg = ('<rect width="1024" height="1024" fill="#F3EFE2"/>'
          '<path d="M0,780 C220,730 420,820 640,770 C800,735 920,760 1024,740 V1024 H0 Z" fill="#E5DFC6"/>')
    fg = ('<path d="M300,262 H712 Q762,262 762,312 V712 Q762,762 712,762 H300 Q262,762 262,724 V312 Q262,262 300,262 Z" '
          'fill="#5A7D2A" transform="rotate(-6 512 512)"/>'
          + glyph("sprout", 500, 530, 330, "#FFFDF6", 2.2)
          + '<circle cx="716" cy="318" r="86" fill="#E9A03B"/><circle cx="690" cy="292" r="22" fill="#FFFFFF" opacity=".5"/>')
    return bg, fg


def ride_lingo():
    # Transit signage: signal blue, a route line with stops running edge to edge, a yellow line roundel.
    bg = ('<rect width="1024" height="1024" fill="#0057FF"/>'
          '<rect x="0" y="490" width="1024" height="44" fill="#FFFFFF"/>'
          '<circle cx="236" cy="512" r="40" fill="#FFFFFF"/><circle cx="236" cy="512" r="18" fill="#0057FF"/>'
          '<circle cx="788" cy="512" r="40" fill="#FFFFFF"/><circle cx="788" cy="512" r="18" fill="#0057FF"/>')
    fg = ('<circle cx="512" cy="512" r="200" fill="#FFCC00" stroke="#0A0A0A" stroke-width="22"/>'
          + glyph("languages", 512, 512, 220, "#0A0A0A", 2.4))
    return bg, fg


def wear_count():
    # Fashion editorial: white page, a hairline hanger and one red price tag.
    bg = '<rect width="1024" height="1024" fill="#FFFFFF"/>'
    fg = ('<path d="M512,402 V372 C512,330 556,318 576,300 C602,276 588,232 552,226 C522,221 498,240 494,266" '
          'fill="none" stroke="#000" stroke-width="18" stroke-linecap="round"/>'
          '<path d="M512,402 L262,566 Q238,590 270,598 H754 Q786,590 762,566 Z" fill="none" stroke="#000" stroke-width="18" stroke-linejoin="round"/>'
          '<path d="M650,598 L650,642" stroke="#000" stroke-width="6"/>'
          '<path d="M610,642 H690 L690,742 L650,778 L610,742 Z" fill="#C8102E"/>'
          '<circle cx="650" cy="668" r="10" fill="#FFFFFF"/>'
          )
    fg = f'<g transform="translate(512 512) scale(.9) translate(-512 -500)">{fg}</g>'
    return bg, fg


def still_here():
    # Warm & accessible: peach field, a big soft halo, a coral check-in button with a waving hand.
    bg = ('<defs><radialGradient id="g" cx="50%" cy="50%" r="60%"><stop offset="0" stop-color="#FFE1D3"/>'
          '<stop offset="1" stop-color="#FFF3EA"/></radialGradient></defs><rect width="1024" height="1024" fill="url(#g)"/>')
    fg = ('<circle cx="512" cy="512" r="262" fill="#FFFFFF"/>'
          '<circle cx="512" cy="512" r="224" fill="#FF6B4A"/>'
          + glyph("hand", 512, 516, 230, "#FFFFFF", 2.3)
          + '<circle cx="700" cy="320" r="44" fill="#FFB547" stroke="#FFFFFF" stroke-width="16"/>')
    return bg, fg


def trialtrap():
    # Neon fintech: black, a lime countdown ring running out to a magenta end, scissors to cut the charge.
    bg = ('<rect width="1024" height="1024" fill="#0A0A0A"/>'
          '<circle cx="512" cy="512" r="420" fill="none" stroke="#1A1A1A" stroke-width="2"/>'
          '<circle cx="512" cy="512" r="470" fill="none" stroke="#151515" stroke-width="2"/>')
    import math
    end = math.radians(290 - 90)
    ex, ey = 512 + 220 * math.cos(end), 512 + 220 * math.sin(end)
    fg = ('<circle cx="512" cy="512" r="220" fill="none" stroke="#1F1F1F" stroke-width="56"/>'
          f'<path d="{arc(512, 512, 220, 0, 290)}" fill="none" stroke="#C6FF00" stroke-width="56" stroke-linecap="round"/>'
          f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="40" fill="#FF4FD8"/>'
          + glyph("scissors", 512, 512, 200, "#C6FF00", 2.4))
    return bg, fg


ICONS = {"lendr": lendr, "hush": hush, "use_by": use_by, "kin_tapes": kin_tapes, "mend": mend, "plotswap": plotswap,
         "ride_lingo": ride_lingo, "wear_count": wear_count, "still_here": still_here, "trialtrap": trialtrap}


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
        icon.resize((96, 96), Image.LANCZOS).save(out / "small.png", optimize=True)
        icon.resize((512, 512), Image.LANCZOS).save(ROOT / "store" / f"{slug}-512.png", optimize=True)
        tiles.append(icon.resize((200, 200), Image.LANCZOS))
        print("icon", slug)

    cols, pad = 5, 32
    sheet = Image.new("RGBA", (cols * 200 + (cols + 1) * pad, 2 * 200 + 3 * pad), "#ECEBE6")
    for i, t in enumerate(tiles):
        sheet.paste(t, (pad + (i % cols) * (200 + pad), pad + (i // cols) * (200 + pad)), t)
    sheet.save(ROOT / "store" / "all-icons-preview.png", optimize=True)


if __name__ == "__main__":
    main()
