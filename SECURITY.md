# Security Policy

## Supported versions

Only the latest release of each app receives fixes.

| App | Version | Supported |
| --- | --- | --- |
| Mac | 4.x | Yes |
| iPhone & iPad | 1.x | Yes |

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Report them privately via
[GitHub private vulnerability reporting](https://github.com/js-surya/Chronology/security/advisories/new).

Include what you found, how to reproduce it, and the app version. You should get a
reply within a week. Once a fix is released, the advisory will be published with credit
to you unless you'd rather stay anonymous.

## Scope notes

- Chronology fetches a user-supplied iCal URL over the network and stores the schedule,
  notes and settings locally (and in the user's iCloud when sync is enabled). There is
  no Chronology server.
- TimeEdit iCal URLs act as secrets: anyone who has one can read that schedule. Treat
  leaks of feed URLs (logs, crash reports, widgets) as security issues.
- Release DMGs are ad-hoc signed and the iOS `.ipa` is unsigned; verify downloads
  against the checksums published with each release.
