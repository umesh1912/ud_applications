"""Writes the GitHub release text for the ten apps: each app with its icon and download link.
Usage: python3 tool/release_notes.py <tag> <branch> <out_dir> > notes.md
Apps whose APK is missing from <out_dir> (a failed build) are listed as not built.
"""
import json
import sys
from pathlib import Path

REPO = "umesh1912/ud_applications"
ROOT = Path(__file__).resolve().parent.parent

tag, branch, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
apps = json.loads((ROOT / "apps.json").read_text())
raw = f"https://raw.githubusercontent.com/{REPO}/{branch}/web_apps/ten_apps/store"
dl = f"https://github.com/{REPO}/releases/download/{tag}"

print("## Ten app concepts\n")
print("Tap **Download** on your Android phone, open the file and tap **Install** "
      "(allow “Install unknown apps” if Android asks). Each app installs separately.\n")
print("| | App | |")
print("|:-:|---|---|")
for a in apps:
    slug, name = a["slug"], a["name"]
    link = f"[**Download**]({dl}/{slug}.apk)" if (out / f"{slug}.apk").exists() else "_not built_"
    if (out / f"{slug}.aab").exists():
        link += f"<br><sub>[Play Store file]({dl}/{slug}.aab)</sub>"
    print(f'| <img src="{raw}/{slug}-512.png" width="64" height="64" alt="{name}"> '
          f"| **{name}**<br>{a['tagline']} | {link} |")
print("\n<sub>These are clickable prototypes: sample data, no accounts, nothing leaves the phone.</sub>")
