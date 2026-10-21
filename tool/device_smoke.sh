#!/usr/bin/env bash
# Called by device-check.yml inside the emulator runner.
# Installs app.apk, opens it, walks through the main screens and saves
# screenshots + logs into report/.
mkdir -p report
PKG="com.udapps.$APP"
UI="python3 tool/ui.py"
adb install -r app.apk > report/install.txt 2>&1
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 20
$UI shot 01-start

case "$APP" in
  valence)
    $UI tap "Continue with phone"; $UI field 0; $UI type 9876543210; $UI tap "Send code"
    $UI field 0; $UI type 123456; sleep 3; $UI shot 02-after-otp
    $UI field 0; $UI type Riya; $UI tap "Continue"; $UI tap "Continue"; $UI tap "Build my plan"; sleep 3; $UI shot 03-today
    $UI tap "Subjects"; $UI shot 04-subjects
    $UI tap "Practice"; $UI shot 05-practice
    ;;
  sawaal)
    $UI field 0; $UI type Aarav; $UI hidekb; $UI tap "School, 11"; $UI scroll; $UI tap "play"; sleep 3; $UI shot 02-home
    $UI tap "Quick play"; sleep 2; $UI shot 03-quiz
    $UI tap "B"; sleep 1; $UI shot 04-answered
    $UI back; $UI tap "Quit"; $UI scroll; $UI shot 05-home-bottom
    ;;
  hisaab)
    $UI field 0; $UI type Ravi; $UI hidekb; $UI tap "Continue"; sleep 2; $UI shot 02-pin
    for d in 2 5 8 0 2 5 8 0; do $UI tap "$d" > /dev/null; done
    sleep 3; $UI shot 03-home
    $UI scroll; $UI shot 04-home-2
    $UI tap "Passbook"; $UI shot 05-passbook
    $UI tap "Plan"; $UI shot 06-plan
    $UI tap "Wealth"; $UI shot 07-wealth
    $UI tap "Add entry" || true
    ;;
  pul)
    $UI field 0; $UI type 9876543210; $UI tap "Send code"; $UI field 0; $UI type 123456; $UI tap "Verify"; sleep 3; $UI shot 02-home
    $UI tap "Start a transfer"; $UI shot 03-send
    $UI back; $UI tap "Rates"; $UI shot 04-rates
    $UI tap "Account"; $UI shot 05-account
    ;;
  jhatpat)
    $UI field 0; $UI type Meera; $UI field 1; $UI type 9876543210; $UI hidekb; $UI tap "Get code"
    $UI field 0; $UI type 123456; $UI tap "Verify"; sleep 3; $UI shot 02-home
    $UI field 0; $UI type 9876543210; $UI hidekb; $UI tap "See plans"; sleep 2; $UI shot 03-plans
    $UI back; $UI scroll; $UI shot 04-home-2
    $UI tap "Rewards"; $UI shot 05-rewards
    ;;
esac

adb shell pidof "$PKG" > report/pid.txt 2>&1 || echo "NOT RUNNING" > report/pid.txt
adb logcat -d > report/logcat-full.txt
grep -E " E flutter|FATAL|AndroidRuntime|Exception" report/logcat-full.txt | tail -n 300 > report/logcat.txt
exit 0
