# Changelog

All notable changes to Chronology are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). Mac and iOS releases are versioned
separately: Mac tags are `vX.Y.Z`, iOS tags are `ios-vX.Y.Z`.

## [Unreleased]

### Changed
- iPhone Week view scrolls sideways through days, three to a screen, instead of squeezing seven narrow columns; swipe past Sunday into the next week. iPad keeps the seven-day grid.

## [ios-1.0.1] - 2026-10-20 (iPhone & iPad)

### Fixed
- Week view on iPhone: class titles in narrow columns wrap between words (or at a hyphen) instead of breaking mid-word

## [4.0.0] - 2026-10-20 (Mac)

Requires macOS 26 (Tahoe) or later.

### Added
- Liquid Glass design for macOS 26: native glass toolbar, Calendar-style title, Day/Week switch, Today navigation, search
- Keyboard shortcuts: ⌘1 Day, ⌘2 Week, ⌘T Today, ⌘← / ⌘→ previous/next, ⌘R refresh
- New app icon made in Icon Composer
- Auto theme, with a choice of Glass, Solid or AMOLED for dark mode
- About pane with credits and a link to the source
- iCloud sync between Mac, iPhone and iPad (off until built with a paid developer team, see `docs/ICLOUD_SETUP.md`)

### Fixed
- Reminders no longer duplicate after reloading, and turning notifications off cancels them
- Course colors stay the same between launches
- Calendar parsing: long wrapped titles, time zones, all-day events, commas and semicolons in names
- Menu bar countdown updates instead of sticking on ✓; showing/hiding the icon applies immediately
- Window reopens after being closed, from the menu bar, the Dock or a notification
- Overlapping classes sit side by side, and cards line up with their hour lines
- Schedule is downloaded at most every 15 minutes instead of every minute
- Readable error messages (e.g. "Calendar not found (HTTP 404)…")
- Valid app bundle code signature; release builds no longer allow debugger attachment

## [ios-1.0.0] - 2026-10-20 (iPhone & iPad)

First iPhone and iPad release, distributed as an unsigned `.ipa` for sideloading. Requires iOS / iPadOS 26.

### Added
- Up Next: countdown to the next class, Important classes, and the next two weeks grouped by day
- Calendar: Day and Week views; tap a day in Week to open it
- Search by course, room or teacher
- Class details: notes, custom course colors, Important classes with an extra reminder
- Reminders before class, plus optional alerts when a class starts or ends
- Next Up widget for the Home Screen and Lock Screen
- Live Activity in the Dynamic Island and on the Lock Screen
- System, Light or Dark theme, accent colors, 12/24-hour time, haptics

### Known issues
- Live Activity may stay on "Starts in 0:00" at class start until the app is opened
- iCloud sync is not included in the unsigned build

[Unreleased]: https://github.com/js-surya/Chronology/compare/v4.0.0...HEAD
[4.0.0]: https://github.com/js-surya/Chronology/releases/tag/v4.0.0
[ios-1.0.1]: https://github.com/js-surya/Chronology/compare/ios-v1.0.0...ios-v1.0.1
[ios-1.0.0]: https://github.com/js-surya/Chronology/releases/tag/ios-v1.0.0
