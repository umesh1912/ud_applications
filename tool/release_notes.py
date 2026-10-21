"""Writes the GitHub release text: every app with its logo and download links.
Usage: python3 tool/release_notes.py <tag> > notes.md
"""
import sys

REPO = "umesh1912/ud_applications"
APPS = [
    ("doc_scanner", "DocScan", "Scan any paper into a clean PDF"),
    ("doc_vault", "Vault", "Keep important documents safe, with PIN lock"),
    ("sign_maker", "Signa", "Draw or type your signature"),
    ("pdf_studio", "PDF Studio", "Merge, split, sign and protect PDFs"),
    ("pdf_fill", "FillIt", "Fill PDF forms on your phone"),
    ("doc_writer", "Likho", "Write and edit Word documents"),
    ("ludo_star", "Ludo Royale", "Ludo with Classic, Quick and Rush modes"),
    ("learn_german", "Deutsch Dost", "Learn German in Hindi, Gujarati or English"),
    ("learn_music", "Sur", "Piano, sargam, songs and tanpura"),
    ("property_ghar", "Ghar", "Sell or rent property with a WhatsApp flyer"),
    ("bill_book", "BillBook", "Never miss a monthly bill"),
    ("pf_saathi", "PF Saathi", "Check PF balance and plan retirement"),
    ("vehicle_gaadi", "Gaadi", "Vehicle papers, renewals and fuel log"),
    ("dial_abroad", "Dial Abroad", "Call family abroad at the right time"),
    ("meet_milo", "Milo", "Free video meetings with a link"),
    ("safar_trips", "Safar", "Train booking and Tatkal countdowns"),
    ("doc_manager", "Daftar", "All your files in neat folders"),
    ("video_recorder", "ClipCam", "Record videos with pause, flip and torch"),
    ("call_recorder", "Baatcheet", "Record calls and voice notes"),
    ("valence", "Valence", "Science lessons, notes and mock tests"),
    ("sawaal", "Sawaal", "GK quiz game for every age"),
    ("hisaab", "Hisaab", "Accounts, budgets, bills, goals and investments"),
    ("pul", "Pul", "Send money abroad (demo)"),
    ("jhatpat", "Jhatpat", "Recharge and pay every bill (demo)"),
]

tag = sys.argv[1]
raw = f"https://raw.githubusercontent.com/{REPO}/main/store"
dl = f"https://github.com/{REPO}/releases/download/{tag}"

print("## Download the apps\n")
print("Tap **Download** on your Android phone, open the file and tap **Install** "
      "(allow “Install unknown apps” if Android asks).\n")
print("| | App | |")
print("|:-:|---|---|")
for app, name, desc in APPS:
    print(f'| <img src="{raw}/{app}-512.png" width="64" height="64" alt="{name}"> '
          f"| **{name}**<br>{desc} "
          f"| [**Download**]({dl}/{app}.apk)<br><sub>[old phones]({dl}/{app}-old-phones.apk) · "
          f"[Play Store file]({dl}/{app}.aab)</sub> |")
print("\n<sub>“old phones” = 32-bit Android. The .aab files are for Google Play Console.</sub>")
