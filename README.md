# Omarchy Gaming Display

An Omarchy shell plugin for gaming on super-ultrawide monitors. It provides
three centered display profiles from the bar:

- **Native / 32:9** — the widest, highest-refresh mode advertised by the panel.
- **21:9** — `3440×1440` on a 1440p super-ultrawide by default.
- **16:9** — `2560×1440` on a 1440p super-ultrawide by default.

There are two independent ways to use a reduced profile:

1. **Desktop output:** Hyprland changes the output mode at runtime. The display
   is centered by keeping the native output center fixed. Unsupported custom
   modes always have an automatic rollback countdown.
2. **Steam / Gamescope:** the desktop stays native while Gamescope exposes the
   selected resolution to one game and pillarboxes it inside the native output.

## Important monitor setting

For true black side bars in desktop-output mode, set the monitor's hardware
scaler to a centered, unscaled mode. On the MSI MPG 491CQPX QD-OLED this is:

**Image → Screen Size → 1:1**

The plugin deliberately does not send vendor-specific DDC/CI commands. On
other displays the equivalent setting may be called **1:1**, **Center**,
**No scaling**, or **Aspect**. Gamescope profiles do not require this setting.

## Install

The plugin is a Git repository with its Omarchy `manifest.json` at the root.
After publishing or cloning it somewhere reachable by Git:

```bash
omarchy plugin add https://github.com/astraldrift/omarchy-gaming-display.git --enable
```

For a local development checkout, copy the repository into the plugin folder,
rescan, validate, and enable it:

```bash
cp -a ./omarchy-gaming-display ~/.config/omarchy/plugins/astraldrift.gaming-display
omarchy plugin validate ~/.config/omarchy/plugins/astraldrift.gaming-display
omarchy-shell shell rescanPlugins
omarchy plugin enable astraldrift.gaming-display --section right
```

Install the optional short CLI name:

```bash
~/.config/omarchy/plugins/astraldrift.gaming-display/bin/omarchy-gaming-display setup
```

This creates `~/.local/bin/omarchy-gaming-display` without overwriting an
unrelated existing command.

## Desktop profiles

Click the bar widget and choose a profile. The first use of each reduced mode
starts a 15-second safety test. Choose **Keep** while the output is visible and
correct; otherwise the independent watchdog restores the previous mode.

The same workflow is available from the CLI:

```bash
omarchy-gaming-display status
omarchy-gaming-display desktop test 21:9
omarchy-gaming-display desktop confirm
omarchy-gaming-display desktop set 16:9
omarchy-gaming-display desktop set native
```

Desktop changes are runtime-only. The plugin does not edit
`~/.config/hypr/monitors.lua`, so a new login always starts with the configured
native monitor layout.

### Mode selection

The target is the widest enabled output with an aspect ratio of at least 2.5.
For each reduced profile the helper:

1. Uses an EDID-advertised resolution when available.
2. Otherwise generates reduced-blanking modelines with `cvt`.
3. Tests the configured maximum refresh first, followed by the fallback list.
4. Remembers verification by monitor EDID fingerprint, profile, and exact mode.

For the detected 5120×1440 / 240 Hz MSI, this means:

- Native: advertised `5120×1440@240`.
- 16:9: advertised `2560×1440@240.25`.
- 21:9: custom `3440×1440`, testing 240 Hz first, then 120 and 60 Hz.

## Steam launch options

Use the panel's **Copy 21:9** or **Copy 16:9** button and paste the result into
a game's Steam **Properties → Launch Options** field. From the CLI:

```bash
omarchy-gaming-display steam-option 21:9 --copy
omarchy-gaming-display steam-option 16:9 --copy
```

Without the optional CLI symlink, use the installed helper directly:

```bash
~/.config/omarchy/plugins/astraldrift.gaming-display/bin/omarchy-gaming-display game 21:9 -- %command%
```

Gamescope receives separate game and output dimensions, uses fit scaling, and
opens fullscreen on the selected monitor. The wrapper passes the game command
as an argument array rather than evaluating it as a shell string.

## Configuration

The helper creates `~/.config/omarchy/gaming-display.json` on first use:

```json
{
  "version": 1,
  "monitor": {
    "connector": "",
    "fingerprint": ""
  },
  "rollbackSeconds": 15,
  "fallbackRefreshRates": [240, 120, 60],
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

Empty connector/fingerprint values enable automatic target detection. Zero
profile dimensions derive sensible values from the native vertical resolution;
zero maximum refresh inherits the native refresh rate. To lock the plugin to a
connector, set for example `"connector": "DP-1"`.

Runtime snapshots and verification records live under
`~/.local/state/omarchy-gaming-display/`.

## Dependencies

- Omarchy 4 with its Quickshell plugin host
- Hyprland and `hyprctl`
- `jq`, `cvt`, `sha256sum`, `awk`, `flock`
- Gamescope for per-game profiles
- `wl-copy` for the panel's copy buttons

## Development

```bash
bash -n bin/omarchy-gaming-display
tests/test-cli.sh
omarchy plugin validate .
```

The test suite supplies mock Hyprland, CVT, Gamescope, and clipboard commands;
it does not change a real display.

## Recovery

If a terminal remains usable, restore native mode with:

```bash
omarchy-gaming-display desktop set native
```

If the plugin state is unavailable, reload the normal Hyprland configuration:

```bash
hyprctl reload
```

That fallback re-applies the existing `~/.config/hypr/monitors.lua` rules.
