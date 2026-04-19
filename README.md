# Chronology

Menu bar schedule viewer for macOS. Subscribe to a TimeEdit iCal URL, see your next class in the menu bar, browse week/day views in a native SwiftUI window.

![Chronology](chronology_app_icon.svg)

## Features

- **Menu bar countdown** — next class + time remaining ("In 15m", "Ends in 45m")
- **Week & Day views** — custom visible hour range
- **Multiple profiles** — unlimited iCal URLs, per-profile icon & color
- **Notifications** — configurable lead time (5m / 15m / 30m / 1h), mark events important
- **Per-course colors** — pick from curated palettes or custom
- **Personal notes** — attach notes to any event
- **Themes** — Light / Dark / AMOLED black, 7 accent presets + custom color, 12/24h time
- **Privacy** — all data stored locally, no cloud sync
- **Launch at login**, menu-bar-only mode

## Requirements

- macOS 14.0 (Sonoma)+
- Xcode 15 / Swift 5.9 (only if building from source)

## Install

Download `Chronology.dmg` from [Releases](https://github.com/js-surya/Chronology/releases) → open → drag to `/Applications`.

## Build from source

```bash
git clone https://github.com/js-surya/Chronology.git
cd Chronology
sh package_app.sh
```

Output: `Chronology.dmg` in project root.

## Usage

1. Launch → **Create Profile** → paste TimeEdit iCal URL → pick icon + color.
2. Menu bar shows next class. Click icon for today's schedule.
3. `⌘,` for settings: appearance, hours, notifications, reminders.

Find your iCal URL on your TimeEdit schedule page → **Subscribe / Export** → copy the `.ics` link.

## Limitations

- iCal URL must be public (no auth)
- TimeEdit format only (other providers untested)

## Stack

Swift 5.9 · SwiftUI · MVVM · UserNotifications · AppKit (menu bar). No third-party dependencies.

## License

MIT — see [LICENSE](LICENSE).

---

v3.0.0 — Made by Surya with AI assistance.
