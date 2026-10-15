# Tapcard 1.5 (build 8)

## Features

- Twenty illustrated designs with live miniature previews, varied typography and corner shapes. Existing theme identifiers remain compatible with saved cards and the backend.
- Centered 116-point profile image. In **Cards → Edit**, tap the camera on the profile image to choose a photo, paste an image URL, or remove it. Selected photos are resized and compressed before publishing.
- Separate **LinkedIn** and **Card / WhatsApp** QR targets. Add a LinkedIn profile in Edit → Social to enable LinkedIn QR. Enlarged QR screens can share the selected URL or QR image. WhatsApp routing is preserved.
- Google login uses the registered iOS OAuth client, the live backend's web/server client ID, and the SwiftUI URL callback. OAuth client secrets are never packaged in the app.
- Opt-in **Settings → Security → Log in with Face ID / Touch ID** after normal account login. The saved session moves into a device-only Keychain item protected by the current enrolled biometrics. Backgrounding locks the session; sign-out and account deletion remove the protected token. Another account login remains available if biometrics become unavailable.

## Validation

Simulator and signed Release archive builds passed. Apple validated and uploaded the final IPA without errors. Apple processed build 8 as VALID and the build is attached to version 1.5. Unit checks cover LinkedIn normalization, unrelated-host rejection, retained WhatsApp query routing and older saved-card decoding. UI checks cover template selection, profile photo picker, QR switching, Google login visibility/cancellation and the biometric setting. Face ID matching still requires a device with enrolled biometrics.

The backend renderer was deployed from `alfredang/tapcard` commit `7e364ae`; authenticated photo/design persistence and the live public card's illustrated header and larger centered avatar were read back successfully.

Final IPA SHA-256: `b628afab44033beb74a36c676db11a863c560583dca401a1c5a95e7da2cb3262`.

## App Store Connect

App ID: `6780261599` (Tertiary Tapcard), bundle ID: `com.tertiaryinfotech.tapcard`.
Version ID: `95394d9c-6884-4284-823d-92cbd835fd67`.
Build ID: `469563a3-0204-4d00-9acf-309f884c040a`.
Prepared review submission: `dfe412a9-08c2-48f1-a717-40a494078a02`.

Release notes, description, reviewer instructions and the existing review credentials have been updated. A sample card was added to the designated reviewer account. Four iPhone screenshots and three iPad screenshots were uploaded, ordered, and read back with COMPLETE delivery state. Both iPhone and iPad design-gallery checks passed. Version and prepared submission both report READY_FOR_REVIEW; submittedDate is null.

**Final submission is pending the App Privacy web-only update:** Photos or Videos and User ID, linked to the user, used for App Functionality, no tracking. The privacy manifest in this build includes those categories; the public Apple privacy label still lists Contact Info only. Browser/computer access is unavailable in this session. The review item is staged, but `submitted=true` has not been sent. Do not call this version submitted until Apple reports WAITING_FOR_REVIEW (or a later review state).

## Build configuration

XcodeGen remains the source of the project. Load `.env` before `xcodegen generate` so the public Google identifiers are substituted. The generated Xcode project and credentials remain untracked. Release signing is scoped to the Tapcard target using **Tapcard App Store v3**, which includes Sign in with Apple; do not pass a provisioning profile globally to Swift Package resource bundles.
