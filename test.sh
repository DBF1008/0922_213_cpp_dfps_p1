#!/system/bin/sh
#
# Regression tests for dfps config hot-reload keep-alive behavior.
#
# A broken config must never take the running instance down: the daemon
# starts the new instance first and retires the previous one only after
# the new one proves the new config is loadable.
#
# Manual usage (on Android device, as root):
#   ./build.sh Release make
#   adb push build/aarch64-linux-android23-clang/runnable/dfps /data/local/tmp/dfps
#   adb push test.sh /data/local/tmp/test.sh
#   adb shell
#   su
#   sh /data/local/tmp/test.sh /data/local/tmp/dfps
#

DFPS_BIN="${1:-/data/local/tmp/dfps}"
WORK_DIR="/data/local/tmp/dfps_test"
CONFIG="$WORK_DIR/dfps.txt"
LOG="$WORK_DIR/dfps.log"
RELOAD_WAIT=3

PASS=0
FAIL=0

dfps_pids() {
    for d in /proc/[0-9]*; do
        [ -r "$d/comm" ] || continue
        if [ "$(cat "$d/comm" 2>/dev/null)" = "dfps" ]; then
            echo "${d#/proc/}"
        fi
    done
}

dfps_count() { dfps_pids | wc -l | tr -d ' '; }

ppid_of() { awk '{print $4}' "/proc/$1/stat" 2>/dev/null; }

daemon_pid() {
    for p in $(dfps_pids); do
        if [ "$(ppid_of "$p")" = "1" ]; then
            echo "$p"
            return
        fi
    done
}

app_pid() {
    dp="$1"
    for p in $(dfps_pids); do
        if [ "$p" != "$dp" ] && [ "$(ppid_of "$p")" = "$dp" ]; then
            echo "$p"
            return
        fi
    done
}

check_eq() {
    if [ "$2" = "$3" ]; then
        echo "PASS: $1"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $1 (expected=[$3] actual=[$2])"
        FAIL=$((FAIL + 1))
    fi
}

check_ne() {
    if [ "$2" != "$3" ]; then
        echo "PASS: $1"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $1 (both=[$2])"
        FAIL=$((FAIL + 1))
    fi
}

check_log_has() {
    if grep -q "$2" "$LOG" 2>/dev/null; then
        echo "PASS: $1"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $1 (missing log line: $2)"
        FAIL=$((FAIL + 1))
    fi
}

stop_all_dfps() {
    for p in $(dfps_pids); do
        kill "$p" 2>/dev/null
    done
    sleep 1
    for p in $(dfps_pids); do
        kill -9 "$p" 2>/dev/null
    done
    sleep 1
}

start_daemon() {
    rm -f "$LOG"
    "$DFPS_BIN" -o "$LOG" "$CONFIG"
    sleep 2
}

write_good_config() {
    cat > "$CONFIG" << 'EOF'
/touchSlackMs 4000
/enableMinBrightness 8
/useSfBackdoor 0
com.example.game 60 60
- -1 -1
* 60 120
EOF
}

# $1: test name, $2: bad config content
run_bad_config_case() {
    before="$(app_pid "$(daemon_pid)")"
    printf '%s\n' "$2" > "$CONFIG"
    sleep "$RELOAD_WAIT"
    after="$(app_pid "$(daemon_pid)")"
    check_eq "$1: old instance kept alive" "$after" "$before"
    check_eq "$1: dfps process count" "$(dfps_count)" "2"
    check_log_has "$1: keep-alive logged" "keep the previous"
}

if [ ! -x "$DFPS_BIN" ]; then
    echo "dfps binary not found or not executable: $DFPS_BIN"
    exit 1
fi

mkdir -p "$WORK_DIR"
trap stop_all_dfps EXIT

echo "=== case 1: start with a good config ==="
stop_all_dfps
write_good_config
start_daemon
DPID="$(daemon_pid)"
APP1="$(app_pid "$DPID")"
check_ne "daemon is running" "$DPID" ""
check_ne "app instance is running" "$APP1" ""
check_eq "dfps process count" "$(dfps_count)" "2"
check_log_has "app loaded config" "Dfps is running"

echo "=== case 2: bad config, missing default rule '*' ==="
run_bad_config_case "missing-star" '- -1 -1'

echo "=== case 3: bad config, missing offscreen rule '-' ==="
run_bad_config_case "missing-dash" '* 60 120'

echo "=== case 4: bad config, malformed rule ==="
run_bad_config_case "malformed-rule" '- -1 -1
* 60 120
com.broken.app 60'

echo "=== case 5: bad config, unknown tunable ==="
run_bad_config_case "unknown-tunable" '/noSuchTunable 1
- -1 -1
* 60 120'

echo "=== case 6: bad config, invalid refresh rate values ==="
run_bad_config_case "invalid-values" '/useSfBackdoor 0
- -1 -1
* 2 0'

echo "=== case 7: good config again, instance is reloaded ==="
before="$(app_pid "$(daemon_pid)")"
write_good_config
sleep "$RELOAD_WAIT"
after="$(app_pid "$(daemon_pid)")"
check_ne "app instance reloaded with new pid" "$after" "$before"
check_ne "new app instance is running" "$after" ""
check_eq "dfps process count" "$(dfps_count)" "2"

echo "=== case 8: start with a bad config, then fix it ==="
stop_all_dfps
printf '%s\n' '- -1 -1' > "$CONFIG"
start_daemon
check_eq "only daemon survives bad initial config" "$(dfps_count)" "1"
write_good_config
sleep "$RELOAD_WAIT"
check_eq "app instance starts after config fixed" "$(dfps_count)" "2"
check_log_has "app loaded fixed config" "Dfps is running"

echo
echo "=== summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
