# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## [1.1.2] - 2026-09-01

### Fixed

- Reworded unavailable desktop modes so they cannot be confused with modes
  that merely await verification.
- Made unavailable desktop rows explain the safe Steam/Gamescope alternative
  when clicked.

## [1.1.1] - 2026-09-01

### Fixed

- Anchored the panel beside the bar widget that opened it instead of centering
  it on the screen.
- Replaced ambiguous aspect-ratio buttons with explicit whole-desktop actions
  and added plain-language explanations for desktop versus Steam behavior.

## [1.1.0] - 2026-09-01

### Added

- Clear whole-desktop versus one-game guidance in the panel.
- Per-profile resolution and availability labels: Native output, Ready, Test
  once, and Gamescope only.
- Safe CLI `teardown` and `--version` commands.
- CI, CodeQL workflow scanning, Dependency Review, Dependabot, OpenSSF
  Scorecard, pinned-Action checks, and attested automated tagged releases.
- Contributor guidance, issue forms, private security reporting guidance, and
  expanded installation, usage, configuration, and recovery documentation.

### Changed

- Steam copy buttons now state where the profile will be used.
- Help and version output no longer create a configuration file.

## [1.0.1] - 2026-08-31

### Changed

- Restricted desktop switching to modes advertised by the monitor.
- Routed unadvertised 3440×1440 profiles through Gamescope to prevent
  compositor or graphics-driver failures from rejected custom modelines.

## [1.0.0] - 2026-08-31

### Added

- Initial Omarchy bar widget and panel.
- Native, centered 21:9, and centered 16:9 profiles.
- Rollback-protected desktop testing and monitor-specific verification.
- Steam launch-option generation and Gamescope wrapper.

[1.1.2]: https://github.com/AstralDrift/omarchy-gaming-display/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/AstralDrift/omarchy-gaming-display/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/AstralDrift/omarchy-gaming-display/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/AstralDrift/omarchy-gaming-display/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AstralDrift/omarchy-gaming-display/releases/tag/v1.0.0
