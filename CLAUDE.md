# CLAUDE.md

Context for Claude Code working in this repo.

## What this is

**Chronology** — macOS menu bar schedule viewer for TimeEdit iCal feeds. Native SwiftUI app, no third-party deps.

- Platform: macOS 14+ (Sonoma)
- Language: Swift 5.9, SwiftUI, MVVM
- Current version: **3.0.0**
- Default branch: `main`
- Remote: https://github.com/js-surya/Chronology (public)

## Layout

```
Sources/Chronology/
  ChronologyApp.swift          # @main + NSApplicationDelegateAdaptor, menu bar setup
  Model/                       # Event, ScheduleProfile, ColorPalettes, EmojiOptions, CodableColor
  ViewModel/
    AppViewModel.swift         # Global @EnvironmentObject — profiles, theme, accent, important events, notes, custom colors
    ScheduleViewModel.swift    # Per-profile ICS fetch + parse + filtered events
  Services/
    NotificationManager.swift  # UserNotifications wrapper (deprecated NSUserNotification also present — legacy)
    ICalParser.swift
  Views/
    ContentView.swift          # Root — profile gate, toolbar, search, sheet for settings
    WeekGridView.swift         # Week layout, event cards, current-time indicator
    DayView.swift              # Single-day list with hour grid
    MenuBarView.swift          # Menu bar dropdown popover
    SettingsView.swift         # NavigationSplitView settings (7 panes)
    SettingsComponents.swift   # Shared Settings building blocks (SettingsSection, SettingsRow, InlineCallout, LiveEventPreview, GridPreviewSwatch)
    ProfileSelectionView.swift # Welcome / profile picker + AddProfileSheet
    EventDetailPopover.swift   # Per-event detail + notes + color palette
Package.swift                  # SPM executable, macOS 14
package_app.sh                 # Build release, bundle .app, codesign ad-hoc, create DMG
Chronology.entitlements        # Ad-hoc sandbox entitlements
```

## Build / package

```bash
swift build -c release     # sanity compile
sh package_app.sh          # full: build → .app bundle → ad-hoc sign → Chronology.dmg
```

Output: `Chronology.dmg` in repo root (git-ignored).

Version bump lives in **two** places — keep in sync:
- `package_app.sh` → `CFBundleShortVersionString`
- `Sources/Chronology/Views/SettingsView.swift` → About pane `Text("Version X.Y.Z")`

## Git workflow

- Commit directly to `main` for releases (solo project).
- Tag releases `vX.Y.Z` with annotated tag, push tag.
- Don't commit: `*.dmg`, `.build/`, `.swiftpm/`, `.DS_Store`, `test_notification.swift` (dev scratch).
- `test_notification.swift` in repo root is a local UNUserNotificationCenter probe script — leave unstaged.

Commit message style: short subject, blank line, bullet body. Example: see `git log a4315ed`.

## GitHub release flow

After tag push:
```bash
gh release create v3.0.0 Chronology.dmg --title "v3.0.0" --notes-file -
```
Or web: https://github.com/js-surya/Chronology/releases/new

`gh` auth: `gh auth login` → GitHub.com → HTTPS → browser. Config lands in `~/.config/gh/hosts.yml`.

## Conventions

- **Caveman mode active** for my responses (terse, drop articles). Code stays normal.
- No emojis in code/README unless user asks.
- Prefer Edit over Write for existing files.
- No DEBUG prints — all stripped in v3.0.
- `isAmoledTheme` is duplicated across 5 views (known tech debt — extract to AppViewModel computed prop when touching these).
- AppViewModel is `@ObservedObject`/`@EnvironmentObject` singleton; don't re-instantiate.
- Event colors: `appViewModel.getCustomColor(for: title)` first, fallback to `event.color(from: title)`.

## Known issues / deferred

- `NotificationManager.swift` + `ChronologyApp.swift` still reference deprecated `NSUserNotification` alongside modern `UNUserNotificationCenter` — migration pending.
- `AppViewModel.swift:213` has `for profile in profiles {}` empty loop — lint warning, safe to delete.
- No tests. No CI.
- iCal auth unsupported (URL must be public).

## Quick commands reference

```bash
# rebuild DMG
sh package_app.sh

# check what changed since last tag
git diff v3.0.0..HEAD --stat

# tag + push release
git tag -a vX.Y.Z -m "vX.Y.Z — short desc"
git push origin main && git push origin vX.Y.Z

# open settings pane while running
# (app exposes ⌘, keyboard shortcut)
```
