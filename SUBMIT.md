# Tapcard — App Store submission runbook

Everything is built and signed. Two steps need your accounts; the rest is automated.

## State (done)
- ✅ App built, archived, **signed**, IPA at `/tmp/tapcard-export/Tapcard.ipa`
- ✅ Distribution certificate `3WYD5KP3S3` (`Apple Distribution: Alfred Ang (GU9WTSTX9M)`) created via API + imported to Keychain
- ✅ Bundle ID `com.tertiaryinfotech.tapcard` registered (`QGZXGM5Z5F`)
- ✅ App Store provisioning profile **Tapcard App Store** (`87b6a5d0-…`) created + installed
- ✅ App Store screenshots (6.9") in `screenshots/appstore-6.9/` (1320×2868)
- ✅ Marketing copy + review contact in `.env`

## Step 1 — Create the app record (UI only — Apple forbids this via API)
1. https://appstoreconnect.apple.com → **Apps → + → New App**
2. Platform **iOS**, Name **Tapcard**, Primary language **English (U.S.)**,
   Bundle ID **com.tertiaryinfotech.tapcard**, SKU **TAPCARD2026**, Full access.
3. Set Primary Category **Business**.

## Step 2 — Deploy the backend endpoint to Coolify
The app posts to `POST /api/mobile/onboard` (already pushed to `alfredang/tapcard`, commit on `main`).
Trigger a redeploy in Coolify so the endpoint goes live, then verify:
```bash
curl -i -X POST https://tapcard.tertiaryinfotech.com/api/mobile/onboard \
  -H 'Content-Type: application/json' -d '{"fullName":"Test","email":"t@example.com"}'
# expect HTTP 200 with a card.url
```

## Step 3 — Upload + submit (automated)
```bash
cd ~/projects/mobile/iOS/tapcard
set -a; source .env; set +a

# upload the build
xcrun altool --validate-app -f /tmp/tapcard-export/Tapcard.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app -f /tmp/tapcard-export/Tapcard.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
# wait ~5–30 min for processing, poll:
python3 .claude/skills/app-store-submission/scripts/asc_submit.py status

# metadata + screenshots + submit
python3 .claude/skills/app-store-submission/scripts/asc_submit.py set-metadata
python3 .claude/skills/app-store-submission/scripts/asc_submit.py review-contact
python3 .claude/skills/app-store-submission/scripts/asc_submit.py attach-build --build 1
python3 .claude/skills/app-store-submission/scripts/asc_submit.py screenshots \
  --type APP_IPHONE_67 screenshots/appstore-6.9/1-home.png \
  screenshots/appstore-6.9/2-card-live.png screenshots/appstore-6.9/3-review.png
python3 .claude/skills/app-store-submission/scripts/asc_submit.py submit
```

## Step 4 — App Privacy (UI only, one-time)
App Store Connect → **App Privacy** → Get Started → declare **Contact Info** (Name, Email,
Phone) collected for **App Functionality**, not used for tracking → Publish.
Also set the **Age Rating** (4+) and **Content Rights** in the UI.
