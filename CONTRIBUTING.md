# Contributing to Chronology

Thanks for your interest! Bug reports, feature ideas and pull requests are all welcome.

## Reporting bugs and requesting features

Open an [issue](https://github.com/js-surya/Chronology/issues/new/choose) using the
bug report or feature request template. For bugs, please include your macOS / iOS
version, the Chronology version (Settings → About) and steps to reproduce.

**Don't paste your TimeEdit iCal URL in a public issue** — anyone with the link can
read your schedule. If a bug depends on a specific feed, describe it or share a
trimmed `.ics` file with personal details removed.

Security problems: see [SECURITY.md](SECURITY.md) instead of opening an issue.

## Development setup

Requirements: macOS 26 (Tahoe) and Xcode 26 or later. No third-party dependencies.

```bash
git clone https://github.com/js-surya/Chronology.git
cd Chronology
swift build          # compile the Mac app
swift test           # run ChronologyCore unit tests
sh package_app.sh    # build Chronology.app + Chronology.dmg
```

Notifications only work from the packaged `.app` (they need a bundle identifier), so
use `package_app.sh` when testing reminders.

iPhone & iPad: open `iOS/ChronologyMobile.xcodeproj` and run the **ChronologyMobile**
scheme. The project is generated from `iOS/project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen); run `xcodegen generate` in `iOS/`
after adding or removing files.

## Project layout

| Path | What lives there |
| --- | --- |
| `Sources/ChronologyCore/` | Platform-neutral code shared by Mac and iOS: models, iCal parser, schedule service, layout, reminders |
| `Sources/Chronology/` | Mac app (SwiftUI, MVVM, menu bar) |
| `iOS/` | iPhone/iPad app, widget and Live Activity |
| `Tests/ChronologyCoreTests/` | XCTest suite for the core |

Logic that doesn't depend on AppKit/UIKit belongs in `ChronologyCore`, with tests.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep the change focused; one fix or feature per PR.
3. Add or update tests in `Tests/ChronologyCoreTests/` for core logic changes.
4. Make sure `swift build` and `swift test` pass (CI runs both).
5. For UI changes, include before/after screenshots in the PR description.
6. Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

### Code style

- Match the surrounding code: SwiftUI, MVVM, Swift concurrency.
- macOS 26 APIs are used directly (no availability fallbacks). Use native controls and
  the system's Liquid Glass styles; don't put glass on content cards.
- Event colors go through `AppViewModel.eventColor(for:)`, times through
  `AppViewModel.timeString` / `timeRange` so the 12/24-hour setting is honored.
- No debug `print` statements in committed code.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
