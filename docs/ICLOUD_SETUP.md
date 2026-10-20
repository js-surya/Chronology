# Turning on iCloud sync

iCloud sync (schedules, course colors, notes, Important classes, 24-hour time) is built into the
Mac, iPhone and iPad apps but switched off in the build until the project is signed by a paid
Apple Developer Program team. Free personal teams can't use iCloud, and an app ID registered on
one team can't move to another, so nothing is registered until the paid account exists.

## Once the Apple Developer Program membership is active

1. **Team ID.** In `iOS/Config/Signing.xcconfig`, set `DEVELOPMENT_TEAM` to the paid team's ID
   (developer.apple.com → Membership details).
2. **Turn iCloud on.** In the same file, set `CHRONOLOGY_ICLOUD = YES`.
3. **Regenerate** the project: `cd iOS && xcodegen generate`.
4. **Register the IDs.** Open `iOS/ChronologyMobile.xcodeproj` in Xcode, sign in with the developer
   account (Settings → Accounts), then build **ChronologyMobile** for a device and **ChronologyMac**
   for My Mac. Automatic signing registers:
   - `com.codingpasanga.Chronology` (Mac) and `com.codingpasanga.Chronology.mobile` (iOS)
   - `com.codingpasanga.Chronology.mobile.ChronologyWidgets` (widget extension)
   - App Group `group.com.codingpasanga.chronology`
   - iCloud key-value storage `<TEAMID>.com.codingpasanga.chronology` (shared by both apps)
5. **Check it.** On the Mac and an iPhone signed in to the same Apple ID, Settings → iCloud Sync
   should be switchable and say it syncs. Add a schedule or change a course color on one device;
   it appears on the other within a minute (open the app if it doesn't).

## Builds

| Build | Signed by | iCloud |
|---|---|---|
| `sh package_app.sh` (DMG) | ad-hoc | never — Settings says sync isn't available |
| Xcode **ChronologyMac** | your team | when `CHRONOLOGY_ICLOUD = YES` |
| Xcode **ChronologyMobile** | your team | when `CHRONOLOGY_ICLOUD = YES` |

To hand the Mac app to other people with iCloud, archive **ChronologyMac** in Xcode and export it
with *Developer ID* (notarized) instead of `package_app.sh`.

## How it works

`ChronologyCore/CloudSync.swift`: each section is stored in iCloud key-value storage with the time
it changed; the newest change wins. A device's first sync merges with what's in iCloud instead of
overwriting, so turning sync on never drops existing schedules. The apps read the Info.plist key
`ChronologyICloud` (set from `CHRONOLOGY_ICLOUD`) to know whether the build can sync.
