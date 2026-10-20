"""Generates launcher icons for every UD app.

Each icon is an illustrated symbol (cream + gold on the app's accent colour)
in one shared style. Writes, per app, into apps/<app>/assets/icon/:
  icon.png        full icon (legacy launchers, Play Store source), 1024 px
  foreground.png  adaptive-icon foreground (transparent, symbol in safe zone)
  background.png  adaptive-icon background (gradient)
and store/<app>-512.png for the Play Store listing.

Needs: pip install cairosvg pillow
Run:   python3 tool/make_icons.py
"""
import io
from pathlib import Path

import cairosvg
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
C = "#FBF5EA"   # cream
G = "#F5B841"   # gold
G2 = "#D9962A"  # deep gold
WOOD = "#F3D9A6"


def shade(hex_color, f):
    """f > 0 lightens towards white, f < 0 darkens towards black."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    t = 255 if f > 0 else 0
    f = abs(f)
    return "#%02X%02X%02X" % tuple(round(c + (t - c) * f) for c in (r, g, b))


# ---------------------------------------------------------------- symbols
# Each returns SVG drawn on a 1024 canvas, kept inside roughly 270..760.

def doc_page(x, y, w, h, fold=80, fill=C):
    return (f'<path d="M{x+24},{y} H{x+w-fold} L{x+w},{y+fold} V{y+h-24} Q{x+w},{y+h} {x+w-24},{y+h} '
            f'H{x+24} Q{x},{y+h} {x},{y+h-24} V{y+24} Q{x},{y} {x+24},{y} Z" fill="{fill}"/>'
            f'<path d="M{x+w-fold},{y} V{y+fold-18} Q{x+w-fold},{y+fold} {x+w-fold+18},{y+fold} H{x+w} Z" fill="#E6DAC4"/>')


def lines(x, ys, widths, color, h=22, op=0.5):
    return "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h/2}" fill="{color}" opacity="{op}"/>'
                   for y, w in zip(ys, widths))


def doc_scanner(A):
    return (doc_page(362, 300, 300, 420)
            + lines(404, [440, 492, 544, 596], [210, 180, 216, 130], A)
            + f'<g fill="none" stroke="{G}" stroke-width="34" stroke-linecap="round" stroke-linejoin="round">'
              '<path d="M296,340 V272 H364"/><path d="M660,272 H728 V340"/>'
              '<path d="M728,680 V748 H660"/><path d="M364,748 H296 V680"/></g>'
            + f'<rect x="300" y="503" width="424" height="16" rx="8" fill="{G}"/>')


def doc_vault(A):
    shield = ("M512,262 C600,312 680,322 732,322 V520 C732,640 640,722 512,772 "
              "C384,722 292,640 292,520 V322 C344,322 424,312 512,262 Z")
    return (f'<path d="{shield}" fill="{C}"/>'
            f'<path d="{shield}" fill="none" stroke="{G}" stroke-width="20" '
            'transform="translate(512 517) scale(0.78) translate(-512 -517)"/>'
            f'<circle cx="512" cy="478" r="50" fill="{A}"/>'
            f'<path d="M486,500 L466,622 H558 L538,500 Z" fill="{A}"/>')


def sign_maker(A):
    nib = (f'<g transform="rotate(40 512 470)">'
           f'<path d="M512,650 L438,505 C426,474 436,442 460,420 L460,336 H564 V420 '
           f'C588,442 598,474 586,505 Z" fill="{C}"/>'
           f'<rect x="440" y="282" width="144" height="62" rx="16" fill="{G}"/>'
           f'<path d="M512,648 V522" stroke="{A}" stroke-width="12" stroke-linecap="round"/>'
           f'<circle cx="512" cy="508" r="20" fill="{A}"/></g>')
    squiggle = (f'<path d="M392,614 C430,560 468,700 520,660 S600,600 630,668 S704,700 744,640" '
                f'fill="none" stroke="{G}" stroke-width="30" stroke-linecap="round"/>')
    return squiggle + nib


def pdf_studio(A):
    return (f'<rect x="420" y="262" width="290" height="390" rx="28" fill="{C}" opacity="0.55" '
            'transform="rotate(8 565 457)"/>'
            + doc_page(340, 320, 300, 410)
            + lines(380, [400, 452, 504], [210, 180, 150], A)
            + f'<rect x="292" y="580" width="268" height="116" rx="26" fill="{G}"/>'
            f'<text x="426" y="664" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" '
            f'font-size="80" fill="{A}">PDF</text>')


def pdf_fill(A):
    rows = ""
    for i, y in enumerate([350, 460, 570]):
        if i == 0:
            rows += (f'<rect x="392" y="{y}" width="70" height="70" rx="16" fill="{G}"/>'
                     f'<path d="M408,{y+36} L422,{y+50} L448,{y+20}" fill="none" stroke="{A}" '
                     'stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            rows += (f'<rect x="398" y="{y+6}" width="58" height="58" rx="14" fill="none" '
                     f'stroke="{A}" stroke-width="12" opacity="0.7"/>')
        rows += f'<rect x="490" y="{y+24}" width="{150 if i != 1 else 120}" height="22" rx="11" fill="{A}" opacity="0.45"/>'
    badge = (f'<circle cx="680" cy="676" r="86" fill="{G}"/>'
             f'<path d="M640,678 L668,706 L722,648" fill="none" stroke="{A}" stroke-width="22" '
             'stroke-linecap="round" stroke-linejoin="round"/>')
    return f'<rect x="340" y="282" width="330" height="440" rx="32" fill="{C}"/>' + rows + badge


def doc_writer(A):
    pencil = (f'<g transform="translate(548 612) rotate(40) scale(0.78)">'
              f'<rect x="-34" y="-332" width="68" height="258" fill="{G}"/>'
              f'<rect x="-34" y="-332" width="22" height="258" fill="{G2}" opacity="0.45"/>'
              f'<rect x="-34" y="-376" width="68" height="46" fill="#D6CEBD"/>'
              f'<rect x="-34" y="-432" width="68" height="60" rx="16" fill="#E8877A"/>'
              f'<path d="M-34,-76 L0,0 L34,-76 Z" fill="{WOOD}"/>'
              f'<path d="M-11,-25 L0,0 L11,-25 Z" fill="{A}"/></g>')
    return (f'<rect x="316" y="282" width="340" height="450" rx="32" fill="{C}"/>'
            f'<rect x="356" y="332" width="176" height="36" rx="18" fill="{A}"/>'
            + lines(356, [410, 460, 510, 560], [260, 236, 252, 150], A)
            + pencil)


def ludo_star(A):
    pips = [(-96, -96, "#E5533D"), (96, -96, "#3FA46A"), (0, 0, A),
            (-96, 96, "#3D7BD9"), (96, 96, G)]
    die = (f'<g transform="rotate(-8 512 584)">'
           f'<rect x="342" y="414" width="340" height="340" rx="72" fill="{C}"/>'
           + "".join(f'<circle cx="{512+dx}" cy="{584+dy}" r="34" fill="{c}"/>' for dx, dy, c in pips)
           + '</g>')
    crown = (f'<path d="M386,392 L362,276 L452,332 L512,246 L572,332 L662,276 L638,392 Z" fill="{G}"/>'
             f'<rect x="380" y="380" width="264" height="34" rx="12" fill="{G2}"/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="17" fill="{C}"/>'
                       for x, y in [(362, 276), (512, 246), (662, 276)]))
    return die + crown


def learn_german(A):
    return (f'<rect x="272" y="282" width="312" height="236" rx="64" fill="{C}"/>'
            f'<path d="M326,496 L300,590 L410,514 Z" fill="{C}"/>'
            f'<text x="428" y="462" text-anchor="middle" font-family="DejaVu Serif" font-weight="bold" '
            f'font-size="150" fill="{A}">Ä</text>'
            f'<rect x="440" y="478" width="312" height="236" rx="64" fill="{G}"/>'
            f'<path d="M698,692 L728,780 L620,708 Z" fill="{G}"/>'
            f'<text x="596" y="656" text-anchor="middle" font-family="FreeSerif" font-weight="bold" '
            f'font-size="160" fill="{A}">अ</text>')


def learn_music(A):
    keys = f'<rect x="296" y="472" width="432" height="262" rx="38" fill="{C}"/>'
    for x in [382, 469, 555, 641]:
        keys += f'<rect x="{x-3}" y="500" width="6" height="210" rx="3" fill="{A}" opacity="0.28"/>'
    for x in [382, 469, 641]:
        keys += f'<rect x="{x-24}" y="472" width="48" height="148" rx="10" fill="{A}"/>'
    notes = (f'<ellipse cx="438" cy="408" rx="48" ry="36" transform="rotate(-20 438 408)" fill="{G}"/>'
             f'<ellipse cx="608" cy="376" rx="48" ry="36" transform="rotate(-20 608 376)" fill="{G}"/>'
             f'<rect x="470" y="252" width="20" height="158" fill="{G}"/>'
             f'<rect x="640" y="222" width="20" height="158" fill="{G}"/>'
             f'<path d="M470,252 L660,222 L660,270 L470,300 Z" fill="{G}"/>')
    return keys + notes


def property_ghar(A):
    return (f'<rect x="604" y="318" width="54" height="128" rx="8" fill="{G2}"/>'
            f'<rect x="340" y="468" width="344" height="276" rx="20" fill="{C}"/>'
            f'<path d="M272,500 L512,282 L752,500 Q760,520 738,532 L512,368 L286,532 Q264,520 272,500 Z" fill="{G}"/>'
            f'<rect x="470" y="594" width="84" height="150" rx="14" fill="{A}"/>'
            f'<circle cx="538" cy="672" r="7" fill="{G}"/>'
            f'<rect x="376" y="540" width="70" height="70" rx="12" fill="{A}" opacity="0.85"/>'
            f'<rect x="578" y="540" width="70" height="70" rx="12" fill="{A}" opacity="0.85"/>')


def bill_book(A):
    zig = "".join(f" L{x},{750 if i % 2 == 0 else 720}" for i, x in enumerate(range(612, 316, -32)))
    receipt = f'<path d="M332,272 H644 V720{zig} L332,720 V272 Z" fill="{C}" stroke="{C}" stroke-width="8" stroke-linejoin="round"/>'
    return (receipt
            + f'<text x="488" y="470" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" '
              f'font-size="160" fill="{A}">₹</text>'
            + lines(378, [520, 572, 624], [220, 180, 120], A)
            + f'<circle cx="672" cy="660" r="90" fill="{G}"/>'
              f'<path d="M630,662 L660,692 L716,632" fill="none" stroke="{A}" stroke-width="22" '
              'stroke-linecap="round" stroke-linejoin="round"/>')


def pf_saathi(A):
    out = ""
    for x, n in [(292, 2), (452, 4), (612, 6)]:
        for i in range(n):
            y = 690 - i * 46
            out += (f'<rect x="{x}" y="{y}" width="124" height="44" rx="22" fill="{G}" '
                    f'stroke="{G2}" stroke-width="6"/>')
    out += (f'<path d="M296,540 L432,448 L518,494 L690,330" fill="none" stroke="{C}" stroke-width="36" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M742,280 L716,404 L620,312 Z" fill="{C}" stroke="{C}" stroke-width="16" stroke-linejoin="round"/>')
    return out


def vehicle_gaadi(A):
    return (f'<rect x="330" y="640" width="88" height="104" rx="24" fill="{shade(A, -0.35)}"/>'
            f'<rect x="606" y="640" width="88" height="104" rx="24" fill="{shade(A, -0.35)}"/>'
            f'<path d="M296,566 Q296,500 352,490 L404,378 Q416,348 450,348 H574 Q608,348 620,378 '
            f'L672,490 Q728,500 728,566 V652 Q728,684 696,684 H328 Q296,684 296,652 Z" fill="{C}"/>'
            f'<path d="M428,394 Q434,380 452,380 H572 Q590,380 596,394 L634,484 H390 Z" fill="{A}"/>'
            f'<circle cx="372" cy="574" r="40" fill="{G}"/><circle cx="652" cy="574" r="40" fill="{G}"/>'
            f'<rect x="452" y="560" width="120" height="20" rx="10" fill="{A}" opacity="0.5"/>'
            f'<rect x="440" y="610" width="144" height="44" rx="10" fill="#FFFFFF" stroke="{A}" stroke-width="6"/>')


def dial_abroad(A):
    call = ("M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 "
            "1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 "
            "0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z")
    return (f'<defs><clipPath id="globe"><circle cx="486" cy="486" r="214"/></clipPath></defs>'
            f'<circle cx="486" cy="486" r="214" fill="{C}"/>'
            f'<g clip-path="url(#globe)" fill="none" stroke="{A}" stroke-width="14" opacity="0.5">'
            '<ellipse cx="486" cy="486" rx="92" ry="214"/>'
            '<path d="M272,486 H700"/><path d="M300,396 Q486,440 672,396"/>'
            '<path d="M300,576 Q486,532 672,576"/></g>'
            f'<circle cx="684" cy="684" r="108" fill="{G}"/>'
            f'<path d="{call}" fill="{A}" transform="translate(616 616) scale(5.6)"/>')


def meet_milo(A):
    return (f'<rect x="274" y="374" width="344" height="284" rx="64" fill="{C}"/>'
            f'<path d="M636,468 L736,404 Q760,390 760,418 V614 Q760,642 736,628 L636,564 Z" fill="{C}"/>'
            f'<circle cx="400" cy="500" r="40" fill="{A}"/>'
            f'<path d="M336,624 Q336,560 400,560 Q464,560 464,624 Z" fill="{A}"/>'
            f'<circle cx="510" cy="500" r="40" fill="{A}" opacity="0.6"/>'
            f'<path d="M446,624 Q446,560 510,560 Q574,560 574,624 Z" fill="{A}" opacity="0.6"/>'
            f'<circle cx="568" cy="420" r="22" fill="{G}"/>')


def safar_trips(A):
    return (f'<g stroke="{G}" stroke-width="18" stroke-linecap="round">'
            '<path d="M392,768 L440,700"/><path d="M632,768 L584,700"/>'
            '<path d="M410,748 H614" opacity="0.6"/></g>'
            f'<path d="M354,642 V404 Q354,292 512,292 Q670,292 670,404 V642 Q670,690 622,690 '
            f'H402 Q354,690 354,642 Z" fill="{C}"/>'
            f'<rect x="394" y="356" width="236" height="140" rx="30" fill="{A}"/>'
            f'<rect x="450" y="318" width="124" height="22" rx="11" fill="{G}"/>'
            f'<circle cx="426" cy="602" r="32" fill="{G}"/><circle cx="598" cy="602" r="32" fill="{G}"/>'
            f'<rect x="478" y="590" width="68" height="24" rx="12" fill="{A}" opacity="0.5"/>'
            f'<circle cx="700" cy="318" r="74" fill="{G}"/>'
            f'<g stroke="{A}" stroke-width="14" stroke-linecap="round">'
            '<path d="M700,318 V276"/><path d="M700,318 L728,334"/></g>'
            f'<circle cx="700" cy="318" r="10" fill="{A}"/>')


def doc_manager(A):
    back = (f'<path d="M286,350 Q286,318 318,318 H440 L482,362 H706 Q738,362 738,394 V700 '
            f'Q738,732 706,732 H318 Q286,732 286,700 Z" fill="{G}"/>')
    page = (f'<g transform="rotate(-6 512 470)">' + doc_page(372, 298, 260, 300, fold=64)
            + lines(408, [380, 424, 468], [150, 186, 120], A) + '</g>')
    front = (f'<path d="M286,470 Q286,444 312,444 H712 Q738,444 738,470 V700 '
             f'Q738,732 706,732 H318 Q286,732 286,700 Z" fill="{C}"/>')
    return (back + page + front
            + f'<rect x="452" y="532" width="120" height="26" rx="13" fill="{A}" opacity="0.55"/>')


def video_recorder(A):
    return (f'<rect x="262" y="372" width="384" height="286" rx="58" fill="{C}"/>'
            f'<path d="M664,476 L752,420 Q774,406 774,432 V598 Q774,624 752,610 L664,554 Z" fill="{C}"/>'
            f'<circle cx="454" cy="515" r="92" fill="{A}"/>'
            f'<circle cx="454" cy="515" r="56" fill="{shade(A, 0.25)}"/>'
            f'<circle cx="428" cy="490" r="16" fill="#FFFFFF" opacity="0.55"/>'
            f'<circle cx="330" cy="318" r="40" fill="#E5533F"/>'
            f'<circle cx="330" cy="318" r="40" fill="none" stroke="{G}" stroke-width="14"/>')


def call_recorder(A):
    call = ("M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 "
            "1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 "
            "0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z")
    bars = "".join(f'<rect x="{x}" y="{512 - h / 2}" width="30" height="{h}" rx="15" fill="{G}"/>'
                   for x, h in [(584, 90), (634, 170), (684, 250), (734, 130)])
    return (f'<path d="{call}" fill="{C}" transform="translate(262 300) scale(17.5)"/>'
            + bars
            + f'<circle cx="694" cy="730" r="44" fill="#E5533F"/>'
            + f'<circle cx="694" cy="730" r="44" fill="none" stroke="{C}" stroke-width="12"/>')


def valence(A):
    # A periodic-table cell: number mark, a two-orbit atom, and a name bar.
    return (f'<rect x="286" y="276" width="452" height="472" rx="40" fill="{C}"/>'
            f'<rect x="286" y="276" width="452" height="472" rx="40" fill="none" stroke="{G}" stroke-width="22"/>'
            f'<rect x="330" y="320" width="64" height="26" rx="13" fill="{A}"/>'
            f'<g fill="none" stroke="{A}" stroke-width="20">'
            '<ellipse cx="512" cy="500" rx="150" ry="58" transform="rotate(28 512 500)"/>'
            '<ellipse cx="512" cy="500" rx="150" ry="58" transform="rotate(-28 512 500)"/></g>'
            f'<circle cx="512" cy="500" r="42" fill="{G}"/>'
            f'<rect x="402" y="664" width="220" height="30" rx="15" fill="{A}" opacity="0.55"/>')


APPS = {
    "doc_scanner": ("#C2512E", doc_scanner),
    "doc_vault": ("#1F5F5B", doc_vault),
    "sign_maker": ("#2B3A8C", sign_maker),
    "pdf_studio": ("#A3273B", pdf_studio),
    "pdf_fill": ("#0F6E8C", pdf_fill),
    "doc_writer": ("#5A4A3A", doc_writer),
    "ludo_star": ("#6B3FA0", ludo_star),
    "learn_german": ("#3E6B48", learn_german),
    "learn_music": ("#8E3B6E", learn_music),
    "property_ghar": ("#9C5B2E", property_ghar),
    "bill_book": ("#3D5A80", bill_book),
    "pf_saathi": ("#4C6A1F", pf_saathi),
    "vehicle_gaadi": ("#3F4752", vehicle_gaadi),
    "dial_abroad": ("#127A7A", dial_abroad),
    "meet_milo": ("#5B4FCF", meet_milo),
    "safar_trips": ("#A26B00", safar_trips),
    "doc_manager": ("#1E5A8C", doc_manager),
    "video_recorder": ("#C2412F", video_recorder),
    "call_recorder": ("#1F7A55", call_recorder),
    "valence": ("#2F5BEA", valence),
}


def svg(body, size=1024):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 1024 1024">{body}</svg>')


def render(markup):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=markup.encode()))).convert("RGBA")


def background(accent):
    return render(svg(
        f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{shade(accent, 0.16)}"/>'
        f'<stop offset="1" stop-color="{shade(accent, -0.28)}"/></linearGradient>'
        f'<radialGradient id="r" cx="0.28" cy="0.22" r="0.6">'
        f'<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.18"/>'
        f'<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient></defs>'
        f'<rect width="1024" height="1024" fill="url(#g)"/>'
        f'<rect width="1024" height="1024" fill="url(#r)"/>'))


def symbol(accent, draw, scale):
    deep = shade(accent, -0.22)
    s = render(svg(f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">{draw(deep)}</g>'))
    # soft drop shadow
    alpha = s.getchannel("A").point(lambda a: int(a * 0.32))
    shadow = Image.new("RGBA", s.size, (0, 0, 0, 0))
    shadow.putalpha(alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    out = Image.new("RGBA", s.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 18))
    out.alpha_composite(s)
    return out


def main():
    store = ROOT / "store"
    store.mkdir(exist_ok=True)
    rows = (len(APPS) + 7) // 8
    sheet = Image.new("RGBA", (8 * 200 + 20, rows * 200 + 20), "#F6F1E7")
    for i, (app, (accent, draw)) in enumerate(APPS.items()):
        if not (ROOT / "apps" / app).exists():
            continue
        out = ROOT / "apps" / app / "assets" / "icon"
        out.mkdir(parents=True, exist_ok=True)
        bg = background(accent)
        bg.convert("RGB").save(out / "background.png")
        symbol(accent, draw, 0.9).save(out / "foreground.png")
        full = bg.copy()
        full.alpha_composite(symbol(accent, draw, 1.12))
        full.convert("RGB").save(out / "icon.png")
        full.convert("RGB").resize((512, 512), Image.LANCZOS).save(store / f"{app}-512.png")

        # launch-screen logo: rounded icon tile with a soft shadow, 768 px
        # (flutter_native_splash treats it as 4x, so it shows at 192 dp)
        tile = full.resize((560, 560), Image.LANCZOS)
        from PIL import ImageDraw as _D
        m = Image.new("L", (560, 560), 0)
        _D.Draw(m).rounded_rectangle((0, 0, 559, 559), radius=140, fill=255)
        tile.putalpha(m)
        splash = Image.new("RGBA", (768, 768), (0, 0, 0, 0))
        sh = Image.new("RGBA", (768, 768), (0, 0, 0, 0))
        sh.paste(Image.new("RGBA", (560, 560), (0, 0, 0, 70)), (104, 120), m)
        splash.alpha_composite(sh.filter(ImageFilter.GaussianBlur(24)))
        splash.alpha_composite(tile, (104, 104))
        splash.save(out / "splash.png")

        # preview: rounded "squircle" like a phone launcher
        thumb = full.resize((180, 180), Image.LANCZOS)
        mask = Image.new("L", (180, 180), 0)
        from PIL import ImageDraw
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, 179, 179), radius=46, fill=255)
        sheet.paste(thumb, (20 + (i % 8) * 200, 20 + (i // 8) * 200), mask)
        print("icons:", app)
    sheet.save(store / "all-icons-preview.png")


if __name__ == "__main__":
    main()
