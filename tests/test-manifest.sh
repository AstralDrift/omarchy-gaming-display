#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST="$ROOT/manifest.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

jq -e '
  .schemaVersion == 1
  and .id == "astraldrift.gaming-display"
  and (.name | type == "string" and length > 0)
  and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
  and .license == "MIT"
  and (.kinds | index("bar-widget") != null)
  and (.entryPoints.barWidget | type == "string" and length > 0)
  and .barWidget.allowMultiple == false
  and (.barWidget.defaultSection | IN("left", "center", "right"))
' "$MANIFEST" >/dev/null || fail "manifest fields are invalid"

entry_point=$(jq -r '.entryPoints.barWidget' "$MANIFEST")
[[ $entry_point != /* && $entry_point != *..* ]] || fail "entry point must remain inside the plugin"
[[ -f $ROOT/$entry_point ]] || fail "bar widget entry point does not exist"
[[ -f $ROOT/Panel.qml ]] || fail "panel entry point does not exist"
[[ -x $ROOT/bin/omarchy-gaming-display ]] || fail "CLI helper is not executable"

manifest_version=$(jq -r '.version' "$MANIFEST")
cli_version=$("$ROOT/bin/omarchy-gaming-display" --version)
[[ $cli_version == "omarchy-gaming-display $manifest_version" ]] || fail "CLI and manifest versions differ"

printf 'Manifest checks passed.\n'
