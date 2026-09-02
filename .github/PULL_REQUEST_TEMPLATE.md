## Summary

Describe the user-visible outcome and why the change is needed.

## Validation

- [ ] `tests/test-cli.sh`
- [ ] `tests/test-manifest.sh`
- [ ] `tests/test-workflows.sh`
- [ ] `omarchy plugin validate .`
- [ ] UI or hardware testing described below, when applicable

## Display safety

- [ ] Desktop modes remain restricted to live EDID-advertised modes.
- [ ] First-time reduced modes retain independent automatic rollback.
- [ ] No persistent Hyprland monitor configuration or custom modeline is added.
- [ ] Diagnostic output is free of monitor serials or other personal data.

## Test environment

Monitor, connector, native mode, Omarchy version, and any other relevant notes.
