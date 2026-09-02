#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$ROOT/bin/omarchy-gaming-display"
TEMP=$(mktemp -d)
trap 'rm -rf -- "$TEMP"' EXIT

mkdir -p "$TEMP/config" "$TEMP/state" "$TEMP/bin" "$TEMP/sys/class/drm/card1-DP-1"
cp "$ROOT/tests/fixtures/monitors.json" "$TEMP/monitors.initial.json"
cp "$TEMP/monitors.initial.json" "$TEMP/monitors.json"
printf 'fake-edid-for-gaming-display-tests\n' >"$TEMP/sys/class/drm/card1-DP-1/edid"
cp "$ROOT/tests/mocks/hyprctl" "$ROOT/tests/mocks/gamescope" "$ROOT/tests/mocks/wl-copy" "$TEMP/bin/"
chmod +x "$TEMP/bin/"*

export OGD_CONFIG_HOME="$TEMP/config"
export OGD_STATE_HOME="$TEMP/state"
export OGD_SYS_CLASS_DRM="$TEMP/sys/class/drm"
export OGD_HYPRCTL="$TEMP/bin/hyprctl"
export OGD_GAMESCOPE="$TEMP/bin/gamescope"
export OGD_BIN_HOME="$TEMP/local-bin"
export OGD_DISABLE_WATCHDOG=1
export MOCK_MONITORS="$TEMP/monitors.json"
export MOCK_MONITORS_INITIAL="$TEMP/monitors.initial.json"
export MOCK_HYPR_LOG="$TEMP/hyprctl.log"
export MOCK_GAMESCOPE_LOG="$TEMP/gamescope.log"
export MOCK_CLIPBOARD="$TEMP/clipboard.txt"
export PATH="$TEMP/bin:$PATH"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_jq() {
  local json=$1 expression=$2 message=$3
  jq -e "$expression" <<<"$json" >/dev/null || fail "$message"
}

status=$($CLI status --json)
assert_jq "$status" '.ok and .target.connector == "DP-1"' "autodetects the super-ultrawide target"
assert_jq "$status" '.native.width == 5120 and .native.height == 1440 and .activeProfile == "native"' "reports native state"
assert_jq "$status" '(.profiles[] | select(.id == "21:9") | .width == 3440 and .height == 1440 and (.available | not))' "keeps unadvertised 21:9 desktop modes unavailable"
assert_jq "$status" '(.profiles[] | select(.id == "16:9") | .width == 2560 and .available and (.verified | not))' "finds the unverified advertised 16:9 mode"

set +e
unsupported_result=$($CLI desktop test 21:9 --timeout 30 --json 2>/dev/null)
unsupported_code=$?
set -e
((unsupported_code != 0)) || fail "unadvertised 21:9 desktop mode must be rejected"
assert_jq "$unsupported_result" '(.ok | not) and (.error | contains("not advertised")) and (.error | contains("Gamescope"))' "routes unsupported desktop modes to Gamescope"
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 5120 and .x == 0)' "does not submit an unadvertised monitor rule"

test_result=$($CLI desktop test 16:9 --timeout 30 --json)
token=$(jq -r '.token' <<<"$test_result")
assert_jq "$test_result" '.ok and .testing and .profile == "16:9" and .kind == "advertised" and .refreshHz == 240.25' "starts an advertised 16:9 test"
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 2560 and .height == 1440 and .x == 1280)' "centers the 16:9 output"

confirm_result=$($CLI desktop confirm "$token" --json)
assert_jq "$confirm_result" '.ok and .confirmed and .profile == "16:9"' "confirms the test"
status=$($CLI status --json)
assert_jq "$status" '.activeProfile == "16:9" and (.profiles[] | select(.id == "16:9") | .verified)' "persists exact-mode verification"

$CLI desktop set native --json >/dev/null
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 5120 and .x == 0)' "restores the native baseline"

$CLI desktop set 16:9 --json >/dev/null
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 2560 and .x == 1280)' "reapplies a verified profile"
$CLI desktop set native --json >/dev/null

test_16=$($CLI desktop test 16:9 --timeout 30 --json)
token_16=$(jq -r '.token' <<<"$test_16")
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 2560 and .x == 1280)' "centers the 16:9 output"
$CLI desktop revert "$token_16" --json >/dev/null
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 5120 and .x == 0)' "reverts to the previous native mode"

watchdog_test=$($CLI desktop test 16:9 --timeout 30 --json)
watchdog_token=$(jq -r '.token' <<<"$watchdog_test")
$CLI _watchdog "$watchdog_token" 0
assert_jq "$(<"$TEMP/monitors.json")" '(.[] | select(.name == "DP-1") | .width == 5120)' "watchdog restores the prior mode"

option=$($CLI steam-option 21:9 --copy)
[[ $option == *'game 21:9 -- %command%'* ]] || fail "prints a Steam launch option"
[[ $(<"$TEMP/clipboard.txt") == "$option" ]] || fail "copies the Steam launch option"

$CLI game 16:9 -- /usr/bin/true
rg -F -- '-w 2560 -h 1440 -W 5120 -H 1440 -r 240 -S fit -f -- /usr/bin/true' "$TEMP/gamescope.log" >/dev/null \
  || fail "builds the expected Gamescope argument vector"
$CLI game 21:9 -- /usr/bin/true
rg -F -- '-w 3440 -h 1440 -W 5120 -H 1440 -r 240 -S fit -f -- /usr/bin/true' "$TEMP/gamescope.log" >/dev/null \
  || fail "builds the safe centered 21:9 Gamescope argument vector"
rg -F 'focusmonitor DP-1' "$TEMP/hyprctl.log" >/dev/null || fail "focuses the target monitor before launching Gamescope"
if rg -F 'modeline' "$TEMP/hyprctl.log" >/dev/null; then fail "never submits a custom modeline"; fi

$CLI setup >/dev/null
[[ $(readlink -f "$TEMP/local-bin/omarchy-gaming-display") == "$CLI" ]] || fail "installs the optional CLI symlink"
[[ $($CLI --version) == "omarchy-gaming-display 1.1.0" ]] || fail "reports the plugin version"
$CLI teardown >/dev/null
[[ ! -e $TEMP/local-bin/omarchy-gaming-display && ! -L $TEMP/local-bin/omarchy-gaming-display ]] || fail "removes its own CLI symlink"

jq '[.[] | select(.name == "DP-2")]' "$TEMP/monitors.initial.json" >"$TEMP/monitors.json"
rm -f "$TEMP/state/omarchy-gaming-display/base.json" "$TEMP/state/omarchy-gaming-display/current.json"
set +e
missing_output=$($CLI status --json 2>/dev/null)
missing_code=$?
set -e
((missing_code != 0)) || fail "missing target returns a failure status"
assert_jq "$missing_output" '(.ok | not) and (.error | contains("no enabled super-ultrawide"))' "JSON errors survive helper command substitutions"

config_file="$TEMP/config/omarchy/gaming-display.json"
jq '.gamescope.scaler = "unsafe-value"' "$config_file" >"$config_file.tmp"
mv "$config_file.tmp" "$config_file"
set +e
invalid_output=$($CLI status --json 2>/dev/null)
invalid_code=$?
set -e
((invalid_code != 0)) || fail "invalid configuration returns a failure status"
assert_jq "$invalid_output" '(.ok | not) and (.error | contains("invalid configuration"))' "validates configuration types and enum values"

printf 'All CLI tests passed.\n'
