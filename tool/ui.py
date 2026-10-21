"""Tiny UI driver for the emulator check (adb + uiautomator).

python3 tool/ui.py tap "Continue"        tap the first element whose text/description contains it
python3 tool/ui.py type "hello"          type text into the focused field
python3 tool/ui.py field 0               tap the Nth text field on screen
python3 tool/ui.py shot name             save report/<name>.png
python3 tool/ui.py scroll                scroll down once
python3 tool/ui.py back                  press back
Exit code 1 if a tap target was not found (the run continues).
"""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


def adb(*a, out=False):
    r = subprocess.run(["adb", *a], capture_output=True)
    return r.stdout if out else None


def dump():
    for _ in range(3):
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        raw = adb("exec-out", "cat", "/sdcard/ui.xml", out=True)
        try:
            return ET.fromstring(raw)
        except Exception:
            time.sleep(1)
    return None


def center(node):
    m = re.findall(r"\d+", node.get("bounds", ""))
    if len(m) != 4:
        return None
    x1, y1, x2, y2 = map(int, m)
    return (x1 + x2) // 2, (y1 + y2) // 2


def find(text):
    root = dump()
    if root is None:
        return None
    t = text.lower()
    best = None
    for n in root.iter("node"):
        label = (n.get("text", "") + " " + n.get("content-desc", "")).lower()
        if t in label:
            c = center(n)
            if c and c[1] > 60:
                # prefer the smallest matching element (the actual control)
                m = list(map(int, re.findall(r"\d+", n.get("bounds"))))
                area = (m[2] - m[0]) * (m[3] - m[1])
                if best is None or area < best[0]:
                    best = (area, c)
    return best[1] if best else None


def main():
    cmd, *args = sys.argv[1:]
    if cmd == "tap":
        for _ in range(4):
            c = find(args[0])
            if c:
                adb("shell", "input", "tap", str(c[0]), str(c[1]))
                time.sleep(2.5)
                print("tapped", args[0], c)
                return 0
            time.sleep(2)
        print("NOT FOUND", args[0])
        with open("report/steps.txt", "a") as f:
            f.write(f"NOT FOUND: {args[0]}\n")
        return 1
    if cmd == "field":
        root = dump()
        fields = [n for n in root.iter("node") if n.get("class", "").endswith("EditText")] if root is not None else []
        idx = int(args[0])
        if idx < len(fields):
            c = center(fields[idx])
            adb("shell", "input", "tap", str(c[0]), str(c[1]))
            time.sleep(1.2)
            print("field", idx, c)
            return 0
        with open("report/steps.txt", "a") as f:
            f.write(f"NO FIELD {idx}\n")
        return 1
    if cmd == "type":
        adb("shell", "input", "text", args[0].replace(" ", "%s"))
        time.sleep(1.5)
        return 0
    if cmd == "shot":
        time.sleep(2)
        png = adb("exec-out", "screencap", "-p", out=True)
        with open(f"report/{args[0]}.png", "wb") as f:
            f.write(png)
        with open("report/steps.txt", "a") as f:
            f.write(f"shot {args[0]}\n")
        return 0
    if cmd == "scroll":
        adb("shell", "input", "swipe", "540", "1700", "540", "700", "400")
        time.sleep(1.5)
        return 0
    if cmd == "back":
        adb("shell", "input", "keyevent", "4")
        time.sleep(1.5)
        return 0
    if cmd == "hidekb":
        adb("shell", "input", "keyevent", "111")
        time.sleep(1)
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
