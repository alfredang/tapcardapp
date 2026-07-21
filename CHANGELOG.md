# Changelog

All notable changes to Tapcard (iOS) are documented here.
Format: [Keep a Changelog](https://keepachangelog.com).

## [1.1] — 2026-07-21 · build 3

### Added
- Sign in / sign up with email (one-time code or password); session token in the Keychain.
- Five-tab navigation: Cards, Contacts, Planner, Analytics, Settings.
- Contacts hub: leads inbox (save as contact / dismiss) + full contact CRUD, synced to the web CRM.
- Planner: follow-up tasks (toggle done) and appointments, synced to the backend.
- Analytics: totals, last-30-day views, per-card and per-event breakdowns.
- QR scanning (AVFoundation): reads vCard / MECARD / URL codes into a prefilled contact.
- Share tools per card: email-signature copy and a 1920×1080 virtual meeting background with QR.
- Sign out and account name in Settings.

### Notes
- NFC card emulation (Android HCE) has no iOS equivalent — share via QR instead.
- Home-screen widget deferred (needs a WidgetKit extension + separate provisioning).

### App Store submission
- 2026-07-21: uploaded build 3, created version 1.1, set metadata + what's-new, review
  demo account playreview@tertiaryinfotech.com (app now requires sign-in), submitted for review.

## [1.0] — 2026-06 · build 2

### Added
- Initial release: scan a paper business card (VisionKit + Vision OCR), review the parsed
  fields, publish a shareable digital card with QR via /api/mobile/onboard.
