# Contributing

Thanks for helping improve Omarchy Gaming Display. Bug reports, monitor
compatibility notes, documentation fixes, and focused pull requests are
welcome.

## Safety invariants

Display code can take down a compositor or leave a user without a visible
session. Changes must preserve these rules:

1. Desktop profiles may use only resolutions and refresh rates returned in the
   monitor's live `availableModes` list.
2. Do not submit custom modelines or persistent monitor configuration.
3. A reduced desktop mode must pass a watchdog-protected test before direct
   application on that exact EDID fingerprint and mode.
4. The rollback process must not depend on the QML panel remaining open.
5. Game commands must remain argument arrays and must never be passed to
   `eval` or `sh -c`.
6. Tests must use the mocks under `tests/mocks`; automated tests must never
   change a real display.

If a proposed feature cannot satisfy these constraints, implement it as a
Gamescope-only path or open a design issue first.

## Local checks

```bash
bash -n bin/omarchy-gaming-display tests/*.sh tests/mocks/*
tests/test-cli.sh
tests/test-manifest.sh
tests/test-workflows.sh
omarchy plugin validate .
```

CI additionally runs ShellCheck. Keep external GitHub Actions pinned to a full
40-character commit SHA with a release-version comment; Dependabot maintains
those pins.

## Testing UI changes

Install a development checkout through Omarchy, rescan plugins, and review the
shell logs for QML errors. Test the panel without changing a real output first.
If hardware testing is necessary, begin at native mode and use the built-in
timed test flow.

Include the following in a pull request when relevant:

- Monitor make/model and native resolution/refresh.
- Whether each target resolution appears in `hyprctl -j monitors all`.
- The profile exercised and whether the automatic rollback was tested.
- Screenshots for visual changes.

Redact monitor serials and other personal identifiers from diagnostic output.

## Pull requests

Keep changes scoped, update tests and documentation together, and add a
changelog entry for user-visible behavior. Pull requests should pass CI,
Dependency Review, and CodeQL before merge.
