"""Writes apps/<app>/pubspec.yaml. Usage:
python3 tool/new_pubspec.py <app> "<description>" "#ACCENT" [dep: constraint]...
"""
import sys
from pathlib import Path

app, desc, accent, *deps = sys.argv[1:]
root = Path(__file__).resolve().parent.parent
dep_lines = "".join(f"  {d}\n" for d in deps)
(root / "apps" / app).mkdir(parents=True, exist_ok=True)
(root / "apps" / app / "pubspec.yaml").write_text(f"""name: {app}
description: {desc}
version: 1.0.0+1
publish_to: none

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  ud_core:
    path: ../../packages/ud_core
{dep_lines}
dev_dependencies:
  flutter_launcher_icons: any

flutter:
  uses-material-design: true
  assets:
    - assets/icon/icon.png

flutter_launcher_icons:
  android: true
  ios: false
  image_path: assets/icon/icon.png
  adaptive_icon_background: assets/icon/background.png
  adaptive_icon_foreground: assets/icon/foreground.png
""")
print("pubspec:", app)
