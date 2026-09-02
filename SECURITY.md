# Security Policy

## Supported versions

Security fixes are applied to the latest release and the `main` branch. Users
should update with:

```bash
omarchy plugin update astraldrift.gaming-display --yes
```

## Report a vulnerability privately

Please use
[GitHub private vulnerability reporting](https://github.com/AstralDrift/omarchy-gaming-display/security/advisories/new)
instead of opening a public issue. Include the affected version, impact,
reproduction details, and any proposed mitigation. Do not include monitor
serial numbers, access tokens, or unrelated system logs.

You should receive an acknowledgement within seven days. Confirmed issues will
be coordinated privately until a fix and disclosure timeline are ready.

## What belongs in a normal bug report

A display mode that fails, stretches, or triggers a compositor crash is a
functional or compatibility bug unless it crosses a security boundary. Report
those through the bug form, but redact device identifiers. Never retry a crash
with a custom modeline; restore the native configuration and use the Gamescope
path while the issue is investigated.
