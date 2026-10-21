"""Finishes the Android project that `flutter create` generated for one app:
sets the launcher label, adds the app's manifest extras (android_manifest_extra.xml
goes inside <manifest>, android_application_extra.xml inside <application>) and, when android/key.properties exists, switches the
release build to the upload key needed for Google Play.

Usage: python3 tool/prepare_android.py apps/<app> "<Label>"
"""
import re
import sys
from pathlib import Path

app_dir = Path(sys.argv[1])
label = sys.argv[2]
android = app_dir / "android"

# 1. App name under the launcher icon.
manifest = android / "app/src/main/AndroidManifest.xml"
text = manifest.read_text()
text = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', text, count=1)
extra = app_dir / "android_manifest_extra.xml"
if extra.exists() and "<!-- ud-extra -->" not in text:
    text = text.replace("</manifest>", "<!-- ud-extra -->\n" + extra.read_text() + "\n</manifest>", 1)
    print("manifest extras added")
app_extra = app_dir / "android_application_extra.xml"
if app_extra.exists() and "<!-- ud-app-extra -->" not in text:
    text = text.replace("</application>", "<!-- ud-app-extra -->\n" + app_extra.read_text() + "\n    </application>", 1)
    print("application extras added")
manifest.write_text(text)
print("label set:", label)

# 2. Turn off R8 shrinking and keep plugin classes that are called from Dart through JNI. Without this,
#    R8 (release shrinking) strips methods such as
#    SharedPreferencesApiRegistrar.getAll and the app hangs on the splash screen.
rules = android / "app/proguard-rules.pro"
keep = """
# ud-keep: plugin classes reached from Dart via JNI/Pigeon
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class kotlin.** { *; }
-dontwarn kotlinx.coroutines.**
"""
existing = rules.read_text() if rules.exists() else ""
if "ud-keep" not in existing:
    rules.write_text(existing + keep)
    print("proguard keep rules added")

# Make sure the rules file is used by the release build.
kts_file = android / "app/build.gradle.kts"
groovy_file = android / "app/build.gradle"
if kts_file.exists():
    g = kts_file.read_text()
    if "proguard-rules.pro" not in g:
        g = g.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("debug")\n'
            '            isMinifyEnabled = false\n'
            '            isShrinkResources = false\n'
            '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
            1,
        )
        kts_file.write_text(g)
        print("proguard file wired into build.gradle.kts")
elif groovy_file.exists():
    g = groovy_file.read_text()
    if "proguard-rules.pro" not in g:
        g = g.replace(
            "signingConfig signingConfigs.debug",
            "signingConfig signingConfigs.debug\n"
            "            minifyEnabled false\n"
            "            shrinkResources false\n"
            "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
            1,
        )
        groovy_file.write_text(g)
        print("proguard file wired into build.gradle")

# 3. Release signing (only when a keystore was provided).
if not (android / "key.properties").exists():
    print("no key.properties: release build signed with debug key (fine for testing, not for Play)")
    sys.exit(0)

kts = android / "app/build.gradle.kts"
groovy = android / "app/build.gradle"

if kts.exists():
    g = kts.read_text()
    if "keystoreProperties" not in g:
        g = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + g
        g = g.replace(
            "android {",
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
            "}\n\nandroid {",
            1,
        )
        g = g.replace(
            "    buildTypes {",
            "    signingConfigs {\n"
            '        create("release") {\n'
            '            keyAlias = keystoreProperties["keyAlias"] as String\n'
            '            keyPassword = keystoreProperties["keyPassword"] as String\n'
            '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '            storePassword = keystoreProperties["storePassword"] as String\n'
            "        }\n"
            "    }\n\n    buildTypes {",
            1,
        )
        g = g.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("release")',
        )
    kts.write_text(g)
elif groovy.exists():
    g = groovy.read_text()
    if "keystoreProperties" not in g:
        g = g.replace(
            "android {",
            "def keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\nandroid {",
            1,
        )
        g = g.replace(
            "    buildTypes {",
            "    signingConfigs {\n"
            "        release {\n"
            "            keyAlias keystoreProperties['keyAlias']\n"
            "            keyPassword keystoreProperties['keyPassword']\n"
            "            storeFile file(keystoreProperties['storeFile'])\n"
            "            storePassword keystoreProperties['storePassword']\n"
            "        }\n"
            "    }\n\n    buildTypes {",
            1,
        )
        g = g.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
    groovy.write_text(g)
else:
    sys.exit("could not find app/build.gradle(.kts)")

print("release signing configured")
