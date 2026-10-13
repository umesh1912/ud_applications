"""Dresses the Capacitor Android project in android/ as one of the ten apps.

Run after `APP=<slug> npx cap add android` (which sets the package name and app name):
    python3 tool/prepare_android.py <slug> [version_code]

It writes the launcher icons (legacy, round and adaptive) at every density, the launch screen,
the status/navigation bar colours, the version code, and, when android/key.properties exists,
release signing with that upload key.
Needs: pip install pillow (and run tool/make_icons.py first if icons/ is missing).
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def resized(img, px):
    return img.resize((px, px), Image.LANCZOS)


def circle(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, img.size[0] - 1, img.size[1] - 1), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def write_icons(slug):
    src = ROOT / "icons" / slug
    bg = Image.open(src / "background.png").convert("RGBA")
    fg = Image.open(src / "foreground.png").convert("RGBA")
    icon = Image.open(src / "icon.png").convert("RGBA")
    # A full-bleed version (no rounded corners) for the round legacy icon.
    size = bg.size[0]
    inset = round(size * 18 / 108)
    flat = Image.alpha_composite(bg, fg).crop((inset, inset, size - inset, size - inset))

    for name, k in DENSITIES.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        resized(icon, round(48 * k)).save(d / "ic_launcher.png")
        circle(resized(flat, round(48 * k))).save(d / "ic_launcher_round.png")
        resized(fg, round(108 * k)).save(d / "ic_launcher_foreground.png")
        resized(bg, round(108 * k)).save(d / "ic_launcher_background.png")

    adaptive = ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    for f in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (RES / "mipmap-anydpi-v26" / f).write_text(adaptive)

    # Template placeholders that the files above replace.
    for stale in ("drawable/ic_launcher_background.xml", "drawable-v24/ic_launcher_foreground.xml",
                  "values/ic_launcher_background.xml"):
        (RES / stale).unlink(missing_ok=True)


def write_theme(app):
    bg, dark = app["bg"], app["dark"]
    light_bars = "false" if dark else "true"

    # Launch screen before Android 12: the app's background with its symbol in the middle.
    for p in RES.glob("drawable*/splash.png"):
        p.unlink()
    (RES / "drawable" / "splash.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@color/app_background"/>\n'
        '    <item android:drawable="@mipmap/ic_launcher_foreground" android:gravity="center"\n'
        '        android:width="240dp" android:height="240dp"/>\n'
        '</layer-list>\n')
    (RES / "values" / "colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="app_background">{bg}</color>\n'
        f'    <color name="colorPrimary">{bg}</color>\n'
        f'    <color name="colorPrimaryDark">{bg}</color>\n'
        f'    <color name="colorAccent">{bg}</color>\n'
        '</resources>\n')

    def app_theme(extra=""):
        return ('    <style name="AppTheme.NoActionBar" parent="Theme.AppCompat.DayNight.NoActionBar">\n'
                '        <item name="windowActionBar">false</item>\n'
                '        <item name="windowNoTitle">true</item>\n'
                '        <item name="android:background">@null</item>\n'
                '        <item name="android:windowBackground">@color/app_background</item>\n'
                '        <item name="android:statusBarColor">@color/app_background</item>\n'
                '        <item name="android:navigationBarColor">@color/app_background</item>\n'
                f'        <item name="android:windowLightStatusBar">{light_bars}</item>\n'
                f'{extra}'
                '    </style>\n')

    (RES / "values" / "styles.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <style name="AppTheme" parent="Theme.AppCompat.Light.DarkActionBar">\n'
        '        <item name="colorPrimary">@color/colorPrimary</item>\n'
        '        <item name="colorPrimaryDark">@color/colorPrimaryDark</item>\n'
        '        <item name="colorAccent">@color/colorAccent</item>\n'
        '    </style>\n\n'
        + app_theme() +
        '\n    <style name="AppTheme.NoActionBarLaunch" parent="Theme.SplashScreen">\n'
        '        <item name="android:background">@drawable/splash</item>\n'
        '        <item name="windowSplashScreenBackground">@color/app_background</item>\n'
        '        <item name="windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>\n'
        '        <item name="postSplashScreenTheme">@style/AppTheme.NoActionBar</item>\n'
        '    </style>\n'
        '</resources>\n')
    # Light navigation bar icons exist from Android 8.1 (API 27).
    v27 = RES / "values-v27"
    v27.mkdir(exist_ok=True)
    (v27 / "styles.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        + app_theme(f'        <item name="android:windowLightNavigationBar">{light_bars}</item>\n')
        + '</resources>\n')


def write_gradle(version_code):
    gradle = ROOT / "android" / "app" / "build.gradle"
    text = gradle.read_text()
    text = re.sub(r"versionCode \d+", f"versionCode {version_code}", text)
    text = re.sub(r'versionName "[^"]*"', f'versionName "1.0.{version_code}"', text)

    if (ROOT / "android" / "key.properties").exists() and "signingConfigs" not in text:
        signing = """
    signingConfigs {
        release {
            def props = new Properties()
            rootProject.file('key.properties').withInputStream { props.load(it) }
            storeFile rootProject.file(props['storeFile'])
            storePassword props['storePassword']
            keyAlias props['keyAlias']
            keyPassword props['keyPassword']
        }
    }
"""
        text = text.replace("    buildTypes {", signing + "    buildTypes {", 1)
        text = text.replace("        release {\n            minifyEnabled false",
                            "        release {\n            signingConfig signingConfigs.release\n            minifyEnabled false", 1)
        print("Release signing: upload key from android/key.properties")
    gradle.write_text(text)


def main():
    slug = sys.argv[1]
    version_code = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    app = next((a for a in json.loads((ROOT / "apps.json").read_text()) if a["slug"] == slug), None)
    if app is None:
        sys.exit(f"unknown app {slug}")
    if not RES.exists():
        sys.exit("android/ is missing: run `APP=<slug> npx cap add android` first")
    write_icons(slug)
    write_theme(app)
    write_gradle(version_code)
    for d in RES.iterdir():  # resource folders emptied above
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    print(f"Android project prepared for {app['name']} (version code {version_code})")


if __name__ == "__main__":
    main()
