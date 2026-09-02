# Omarchy Gaming Display

[![CI](https://github.com/AstralDrift/omarchy-gaming-display/actions/workflows/ci.yml/badge.svg)](https://github.com/AstralDrift/omarchy-gaming-display/actions/workflows/ci.yml)
[![CodeQL](https://github.com/AstralDrift/omarchy-gaming-display/actions/workflows/codeql.yml/badge.svg)](https://github.com/AstralDrift/omarchy-gaming-display/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/AstralDrift/omarchy-gaming-display/badge)](https://scorecard.dev/viewer/?uri=github.com/AstralDrift/omarchy-gaming-display)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

An Omarchy shell plugin for gaming on super-ultrawide monitors. Switch the
whole desktop to a centered, monitor-supported 16:9 mode, or keep the desktop
native and launch an individual Steam game in a centered 21:9 or 16:9
Gamescope session.

The plugin was built and hardware-tested with a 5120×1440 / 240 Hz MSI MPG
491CQPX. Its safety model is intentionally conservative: it never submits a
custom monitor modeline.

## Quick start

### 1. Install

```bash
omarchy plugin add https://github.com/AstralDrift/omarchy-gaming-display.git --enable --yes
~/.config/omarchy/plugins/astraldrift.gaming-display/bin/omarchy-gaming-display setup
```

The second command adds the short `omarchy-gaming-display` command to
`~/.local/bin`. It refuses to overwrite an unrelated command.

### 2. Pick the workflow you want

Click the **32:9** widget on the right side of the Omarchy bar.

- To resize the entire desktop, choose a profile under **Desktop · Whole
  Screen**. The first use of a reduced mode is a timed safety test; click
  **Keep** if the picture is correct.
- To resize only a game, click **Copy Steam 21:9** or **Copy Steam 16:9**.
  Open that game in Steam, choose **Properties**, and paste into **Launch
  Options**. Then launch the game normally.
- To return the desktop to full width, choose **32:9**.

For this specific 5120×1440 MSI monitor, desktop 16:9 is available and tested,
while the monitor does not offer a 3440×1440 input mode. The 21:9 profile
therefore remains Gamescope-only.

## Profiles

| Profile | Default size on a 1440p panel | Whole desktop | One Steam game |
| --- | ---: | --- | --- |
| Native / 32:9 | 5120×1440 | Yes | Launches without Gamescope |
| 21:9 | 3440×1440 | Only when advertised by the monitor | Yes |
| 16:9 | 2560×1440 | Yes when advertised; verified on the test monitor | Yes |

The panel labels each desktop profile:

- **Native output** — the panel's widest, highest-refresh advertised mode.
- **Ready** — this exact monitor and mode already passed its safety test.
- **Test once** — the monitor advertises the mode, but it still needs a timed
  confirmation.
- **Gamescope only** — the monitor does not advertise that desktop mode; the
  Steam button remains available.

### Why a 5120×1440 panel may not offer 3440×1440

The panel's physical pixel count and its accepted input modes are different
things. A monitor tells the graphics stack which timings its scaler and
firmware support through EDID. This monitor offers 5120×1440 and 2560×1440 to
Hyprland, but not 3440×1440, so there is no safe 21:9 desktop timing for the
plugin to test or mark as verified.

Gamescope avoids that restriction. It keeps the DisplayPort signal at the
monitor-approved native mode, renders the game at 3440×1440, and centers that
game surface with 840-pixel black bars on each side. The plugin intentionally
does not inject a custom monitor modeline.

## Getting real black side bars

For desktop switching, set the monitor's hardware scaler to a centered,
unscaled mode. On the MSI MPG 491CQPX QD-OLED:

**Image → Screen Size → 1:1**

Other monitors may call the setting **1:1**, **Center**, **No scaling**, or
**Aspect**. Without it, the monitor may stretch a lower-width desktop mode
across the panel. The plugin does not send vendor-specific DDC/CI commands or
change the monitor's OSD settings.

Gamescope renders the game inside a native-size surface, so its side bars do
not depend on the monitor's hardware scaler.

## Desktop workflow

Desktop mode changes apply to the live Hyprland session only. The plugin does
not edit `~/.config/hypr/monitors.lua`, so a new login starts with your normal
configured layout.

On first use of a reduced desktop profile:

1. The helper saves the current native geometry.
2. It chooses the highest suitable refresh rate from the modes advertised by
   the monitor.
3. It centers the narrower output around the native output's midpoint.
4. A separate watchdog starts the rollback countdown (15 seconds by default).
5. **Keep** records that exact mode against the monitor's EDID fingerprint.
   If you do nothing, the watchdog restores the previous mode.

After successful verification, selecting that profile applies it directly.
A mode must be verified again if its timing or monitor fingerprint changes.

Keyboard shortcuts while the panel is open:

| Key | Action |
| --- | --- |
| `1` | Native / 32:9 desktop |
| `2` | 21:9 desktop, when advertised |
| `3` | 16:9 desktop, when advertised |
| `K` | Keep the active safety test |
| `R` | Revert the active safety test |

## Steam and Gamescope workflow

The easiest path for most games is:

1. Leave the desktop at native 32:9.
2. Open the plugin and click **Copy Steam 21:9** or **Copy Steam 16:9**.
3. In Steam, right-click the game and choose **Properties**.
4. Paste into **General → Launch Options**.
5. Launch the game. If it has its own resolution selector, choose the matching
   3440×1440 or 2560×1440 resolution.

The generated option looks like this:

```text
omarchy-gaming-display game 21:9 -- %command%
```

The wrapper focuses the selected monitor and gives Gamescope separate game and
output dimensions. Gamescope uses fit scaling and opens fullscreen, producing
a centered game with side bars while Hyprland remains at 5120×1440. The game
command is passed as an argument array; it is never evaluated as a shell
string.

Some anti-cheat systems, launchers, overlays, or HDR paths may not work through
Gamescope. Remove the Steam launch option to return that game to its normal
launch behavior.

## Command line reference

```bash
# Inspect the detected monitor, live profile, and availability
omarchy-gaming-display status
omarchy-gaming-display profiles

# Test an advertised desktop mode with automatic rollback
omarchy-gaming-display desktop test 16:9
omarchy-gaming-display desktop confirm
omarchy-gaming-display desktop revert

# Apply a previously verified profile or restore native
omarchy-gaming-display desktop set 16:9
omarchy-gaming-display desktop set native

# Print or copy a Steam launch option
omarchy-gaming-display steam-option 21:9
omarchy-gaming-display steam-option 21:9 --copy

# Run a command directly through the selected Gamescope profile
omarchy-gaming-display game 16:9 -- /path/to/game

# Manage the optional ~/.local/bin symlink
omarchy-gaming-display setup
omarchy-gaming-display teardown

omarchy-gaming-display --version
```

Display commands accept `--json` where shown by `--help`; the panel uses these
machine-readable responses internally.

## Configuration

The helper creates `~/.config/omarchy/gaming-display.json` on first operational
use:

```json
{
  "version": 1,
  "monitor": {
    "connector": "",
    "fingerprint": ""
  },
  "rollbackSeconds": 15,
  "profiles": {
    "21:9": {"width": 0, "height": 0, "maxRefreshHz": 0},
    "16:9": {"width": 0, "height": 0, "maxRefreshHz": 0}
  },
  "gamescope": {
    "fullscreen": true,
    "scaler": "fit",
    "forceGrabCursor": false
  }
}
```

Empty connector and fingerprint values enable automatic detection of the
widest enabled output whose aspect ratio is at least 2.5. To pin a connector,
set (for example) `"connector": "DP-1"`.

Zero profile dimensions derive common sizes from the native vertical
resolution: 3440×1440 for 21:9 and 2560×1440 for 16:9. A zero maximum refresh
inherits the native refresh cap. Supported Gamescope scalers are `auto`, `fit`,
`fill`, `stretch`, and `integer`.

Runtime snapshots, pending tests, and verification records live in
`~/.local/state/omarchy-gaming-display/`.

## Requirements

- Omarchy 4 with its Quickshell plugin host
- Hyprland and `hyprctl`
- `jq`, `sha256sum`, `awk`, and `flock`
- Gamescope for per-game profiles
- `wl-copy` (from `wl-clipboard`) for panel copy buttons
- A super-ultrawide output, or an explicit connector in the configuration

The core desktop path has no downloaded runtime library dependencies. It uses
the commands already present on the system and the live Hyprland API.

## Update or remove

```bash
# Pull and activate the latest plugin revision
omarchy plugin update astraldrift.gaming-display --yes

# Remove the optional CLI link first, then remove the plugin
omarchy-gaming-display teardown
omarchy plugin remove astraldrift.gaming-display --yes
```

Configuration and verification data are intentionally retained so an update
or reinstall does not forget a tested mode.

## Recovery and troubleshooting

If a first-time desktop test is wrong, wait for the countdown or press **R**.
The watchdog is a separate process and should restore the prior mode even if
the panel is closed.

If a terminal is usable:

```bash
omarchy-gaming-display desktop set native
```

If the plugin cannot restore the saved state, reload the normal Omarchy
Hyprland configuration and shell:

```bash
omarchy restart hyprctl
omarchy restart shell
```

Common issues:

- **The image stretches instead of showing black bars:** enable 1:1 or centered
  scaling in the monitor OSD.
- **A desktop profile says Gamescope only:** the monitor does not expose that
  resolution through EDID. Use the matching Steam button; do not add a custom
  modeline.
- **Steam starts the game normally:** rerun `setup`, verify the full launch
  option includes `%command%`, and confirm `gamescope` is available in `PATH`.
- **The wrong output is selected:** set `monitor.connector` in the JSON config.
- **Copy does nothing:** install `wl-clipboard`, or print the option with
  `steam-option` and copy it manually.

When sharing diagnostic output, review and redact monitor serial numbers or
other identifiers first.

## Development and automation

```bash
bash -n bin/omarchy-gaming-display tests/*.sh tests/mocks/*
tests/test-cli.sh
tests/test-manifest.sh
tests/test-workflows.sh
omarchy plugin validate .
```

The CLI suite provides mock Hyprland, Gamescope, DRM, and clipboard commands;
it never changes a real display.

The public repository automation includes:

- CI syntax checks, ShellCheck, manifest checks, workflow pin checks, and the
  full mock CLI suite on every push and pull request.
- CodeQL scanning for GitHub Actions workflow code.
- Dependency Review on pull requests and weekly Dependabot updates for Actions.
- Weekly OpenSSF Scorecard analysis uploaded to GitHub code scanning.
- Reproducible plugin archives, SHA-256 checksums, and build-provenance
  attestations for version tags.

All external Actions are pinned to immutable commit SHAs and annotated with
their release versions. See [CONTRIBUTING.md](CONTRIBUTING.md) for the safety
invariants expected from changes and [SECURITY.md](SECURITY.md) for private
vulnerability reporting.

## License

[MIT](LICENSE)
