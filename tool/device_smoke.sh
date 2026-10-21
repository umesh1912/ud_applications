#!/usr/bin/env bash
# Called by device-check.yml inside the emulator runner.
# Installs app.apk, opens it, taps through the first screen a little,
# and saves screenshots + logs into report/.
set -x
mkdir -p report
PKG="com.udapps.$APP"
adb install -r app.apk > report/install.txt 2>&1
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 25
adb exec-out screencap -p > report/1-start.png
adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 && adb pull /sdcard/ui.xml report/1-start.xml > /dev/null 2>&1
# Is the process still alive?
adb shell pidof "$PKG" > report/pid.txt 2>&1 || echo "NOT RUNNING" > report/pid.txt
# A few generic taps in the middle/bottom to see if anything reacts
adb shell input tap 540 1500
sleep 4
adb exec-out screencap -p > report/2-tap.png
adb logcat -d > report/logcat-full.txt
grep -E "flutter|FATAL|AndroidRuntime|Exception|Error" report/logcat-full.txt | grep -v "GoogleApiManager\|chromium" | tail -n 300 > report/logcat.txt
ls -la report
exit 0
