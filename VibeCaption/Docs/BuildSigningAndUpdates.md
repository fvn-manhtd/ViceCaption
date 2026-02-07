# VibeCaption Updates, Signing, and Distribution

## Sparkle app updates

- Sparkle is integrated through Swift Package Manager (`Sparkle` 2.x).
- Appcast URL is configured in `/Users/tranmanh/Desktop/LEARN/code/VibeCaption/VibeCaption/Resources/Info.plist` under `SUFeedURL`.
- Automatic checks are enabled by default with:
  - `SUEnableAutomaticChecks = true`
  - `SUScheduledCheckInterval = 86400` (24h)
- EdDSA appcast signature verification uses `SUPublicEDKey` in `/Users/tranmanh/Desktop/LEARN/code/VibeCaption/VibeCaption/Resources/Info.plist`.

## Critical security updates

- Sparkle handles update UI, user postponement, and install prompts.
- To mark an update as mandatory/critical, set the appcast item as critical:
  - `<sparkle:criticalUpdate>true</sparkle:criticalUpdate>`
- VibeCaption exposes a local policy toggle (`Force Critical Security Updates`) in Settings and persists it via `SettingsManager.enforceCriticalAppUpdates`.

## Model updates

- Model updates are intentionally manual (Settings-only trigger).
- Configure `Model Catalog URL` in the Updates tab.
- `ModelManager` performs version comparison and detects updates only for installed models.
- Download/install is user-triggered from Settings.

## Code signing and hardened runtime

- App target settings include:
  - `ENABLE_HARDENED_RUNTIME = YES`
  - `OTHER_CODE_SIGN_FLAGS = --timestamp --options runtime`
  - `CODE_SIGN_ENTITLEMENTS = Resources/VibeCaption.entitlements`
- Required entitlements for update/model networking:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - `com.apple.security.device.audio-input`
- Keep release signing with a Developer ID Application identity and your team.

## Notarization workflow

1. Archive/build signed release artifact (`.app` or zipped `.app`).
2. Run:
   - `/Users/tranmanh/Desktop/LEARN/code/VibeCaption/VibeCaption/Scripts/notarize_release.sh <artifact> <bundle-id>`
3. Script uses:
   - `APPLE_ID`
   - `APPLE_TEAM_ID`
   - `APPLE_APP_SPECIFIC_PASSWORD`
4. For `.app`, script staples the ticket automatically.

## Distribution profile setup

- Internal distribution should use a Developer ID signed/notarized build.
- Ensure the bundle identifier (`com.project.vibecaption`) matches your signing profile and appcast channels.
- Keep appcast hosted on internal HTTPS infrastructure and restrict publish access.
