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
    $UI field 0; $UI type Aarav; $UI hidekb; $UI tap "School, 11"; $UI scroll; $UI scroll; $UI tap "Let's play"; sleep 3; $UI shot 02-home
    $UI tap "Quick play"; sleep 2; $UI shot 03-quiz
    $UI tap "A"; sleep 1; $UI shot 04-answered
    $UI tap "Next question"; $UI shot 05-next
    $UI back; $UI tap "Quit"; $UI scroll; $UI shot 06-home-bottom
    $UI tap "Science"; sleep 2; $UI shot 07-category
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
    $UI tap "Finish KYC"; $UI field 0; $UI type "Asha Mehta"; $UI field 1; $UI type ABCDE1234F; $UI field 2; $UI type 1234; $UI hidekb
    $UI tap "Start video KYC"; $UI tap "Mark as done"; $UI scroll; $UI tap "I agree"; $UI tap "Submit"; sleep 8; $UI shot 03-kyc
    $UI field 0; $UI type 4826; $UI hidekb; $UI tap "Save PIN"; $UI tap "Done"; sleep 2
    $UI tap "Start a transfer"; $UI tap "Someone new"; $UI field 1; $UI type "John Smith"; $UI field 2; $UI type "Chase Bank"
    $UI field 3; $UI type 123456789; $UI field 4; $UI type CHASUS33; $UI hidekb; $UI scroll; $UI tap "Save recipient"; sleep 2
    $UI field 0; $UI type 50000; $UI hidekb; $UI shot 04-quote
    $UI scroll; $UI tap "Continue"; $UI shot 05-review
    ;;
  jhatpat)
    $UI field 0; $UI type Meera; $UI field 1; $UI type 9876543210; $UI hidekb; $UI tap "Get code"
    $UI field 0; $UI type 123456; $UI tap "Verify"; sleep 3; $UI shot 02-home
    $UI tap "10-digit number"; $UI type 9876543210; $UI hidekb; $UI tap "See plans"; sleep 2; $UI shot 03-plans
    $UI tap "299"; sleep 2; $UI shot 04-checkout
    $UI scroll; $UI scroll; $UI tap "Pay"; sleep 4; $UI shot 05-receipt
    $UI back; $UI tap "History"; $UI shot 06-history
    ;;
esac

adb shell pidof "$PKG" > report/pid.txt 2>&1 || echo "NOT RUNNING" > report/pid.txt
adb logcat -d > report/logcat-full.txt
grep -E " E flutter|FATAL|AndroidRuntime|Exception" report/logcat-full.txt | tail -n 300 > report/logcat.txt
exit 0
