"""Writes the GitHub release text for the CareLoop apps.
Usage: python3 tool/release_notes.py <tag> <branch> <out_dir> > notes.md
"""
import json
import sys
from pathlib import Path

REPO = "umesh1912/ud_applications"
ROOT = Path(__file__).resolve().parent.parent

tag, branch, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
raw = f"https://raw.githubusercontent.com/{REPO}/{branch}/web_apps/careloop/store"
dl = f"https://github.com/{REPO}/releases/download/{tag}"

print("## CareLoop: doctor and patient apps\n")
print("Tap **Download** on your Android phone, open the file and tap **Install** "
      "(allow “Install unknown apps” if Android asks). Pick India or the United States on first launch.\n")
print("| | App | |")
print("|:-:|---|---|")
for a in json.loads((ROOT / "apps.json").read_text()):
    slug = a["slug"]
    link = f"[**Download**]({dl}/{slug}.apk)" if (out / f"{slug}.apk").exists() else "_not built_"
    if (out / f"{slug}.aab").exists():
        link += f"<br><sub>[Play Store file]({dl}/{slug}.aab)</sub>"
    who = "For patients" if a["role"] == "patient" else "For doctors"
    print(f'| <img src="{raw}/{slug}-512.png" width="64" height="64" alt="{a["name"]}"> '
          f"| **{a['name']}** · {who}<br>{a['tagline']} | {link} |")
print("\n<sub>Working prototypes with sample data: no accounts, payments are simulated, nothing leaves the phone.</sub>")
