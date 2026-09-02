#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORKFLOWS="$ROOT/.github/workflows"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mapfile -t uses_lines < <(rg --no-heading --no-line-number '^\s*uses:\s*\S+' "$WORKFLOWS")
((${#uses_lines[@]} > 0)) || fail "no external Actions were found"

external_count=0
for line in "${uses_lines[@]}"; do
  reference=${line#*uses:}
  reference=${reference#"${reference%%[![:space:]]*}"}
  [[ $reference == ./* ]] && continue
  ((external_count += 1))
  revision=${reference##*@}
  revision=${revision%%[[:space:]#]*}
  [[ $revision =~ ^[0-9a-f]{40}$ ]] || fail "Action is not pinned to a full commit SHA: $reference"
  [[ $reference == *" # v"* ]] || fail "Action pin is missing a release-version comment: $reference"
done

((external_count > 0)) || fail "no external Actions were checked"

if rg --quiet '^\s*pull_request_target:' "$WORKFLOWS"; then
  fail "pull_request_target is prohibited for these workflows"
fi

while IFS= read -r workflow; do
  rg --quiet '^permissions:' "$workflow" || fail "workflow has no explicit top-level permissions: $workflow"
done < <(find "$WORKFLOWS" -maxdepth 1 -type f -name '*.yml' -print)

printf 'Workflow pin checks passed.\n'
