# Changelog

All notable changes to Tapcard (iOS) are documented here.
Format: [Keep a Changelog](https://keepachangelog.com).

## [1.6] — 2026-10-15 · build 9

### Added
- Settings → Card design: 20 designs and an accent colour with a live preview,
  saved instantly to the web card.
- Settings → Sharing: default country code, what the QR opens (WhatsApp / LinkedIn /
  Card) and the WhatsApp number — synced with the web via `/api/mobile/settings`.
- QR panel switcher (WhatsApp / LinkedIn / Card link); a missing LinkedIn profile or
  number can be added inline.
- Cards tab leads with your digital card and WhatsApp QR once a card exists.
- Includes the 1.5 (build 8) work: card designs, profile photo, Google sign-in,
  Face ID lock.

### Fixed
- WhatsApp QR no longer fails with "phone number shared via url is invalid": local
  numbers get the account's country code ("96983731" → +65 9698 3731); `tel:` links
  and vCards are international.
- Custom accents render the same as on the web; the legacy default violets mean
  "match design".

### App Store
- 2026-10-15: 1.6 (9) submitted for review.

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
