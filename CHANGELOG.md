# Changelog

All notable changes to Tapcard (iOS) are documented here.
Format: [Keep a Changelog](https://keepachangelog.com).

## [1.6.4] — 2026-10-19 · build 13

Includes everything in 1.6.3, which was withdrawn from review before release.

### Added
- Apple Intelligence images (Image Playground, on-device). Settings → Card design
  → **Create banner** / **Create photo**, and "Create with Apple Intelligence" in
  the card editor's photo and banner menus. Ideas start from the card's design,
  job title and company and can be edited; the photo can start from your current
  one to draw your likeness. Shown only on iPhones with Apple Intelligence.
- Card design: "Use the design's banner instead" removes a custom banner.

### App Store
- 2026-10-19: 1.6.4 (13) submitted for review.

## [1.6.3] — 2026-10-19 · build 12

### Added
- Settings → Sharing → WhatsApp QR: add your own WhatsApp QR (read from a
  screenshot of WhatsApp → QR code, or paste its wa.me/qr link). The WhatsApp QR
  on the Cards tab is then the same code WhatsApp shows, so scanning adds you as
  a WhatsApp contact. Without it, the QR still opens a chat with an intro message.
  Synced with your account and tapcard.tertiaryinfotech.com/settings.

### Changed
- The WhatsApp QR has WhatsApp's look: the WhatsApp mark in the middle of a
  rounded white tile, encoded at high error correction so it still scans. The
  shared QR image matches.

### App Store
- 2026-10-19: 1.6.3 (12) submitted for review, then withdrawn and replaced by 1.6.4.

## [1.6.2] — 2026-10-18 · build 11

### Changed
- Cards tab: the "Tapcard" title is gone and your card fills the screen. It runs
  edge to edge, and its banner reaches up under the status bar, with the scan and
  settings buttons floating on it.
- "My other cards": long-press a card to edit or delete it (this was swipe).

### App Store
- 2026-10-18: 1.6.2 (11) submitted for review.

## [1.6.1] — 2026-10-16 · build 10

### Fixed
- Settings → Card design: picking a design no longer snaps back. Cards published
  while signed in now go to the signed-in account (the publish call sends the
  session token), and a card that was filed under another account (e.g. its own
  email, after an Apple sign-in) is re-published to this account on the first
  design or detail save instead of failing with "Not found".
- A failed design save now shows an alert, not a note scrolled out of view.

### Changed
- Settings no longer shows the account header (initial avatar + Apple relay email).

### App Store
- 2026-10-16: 1.6.1 (10) submitted for review.

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
