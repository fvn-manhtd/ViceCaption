# Developer Guide

## Architecture
- `Sources/App`: app entry and lifecycle wiring.
- `Sources/Core`: state, settings, transcript, formatting, errors.
- `Sources/Services`: capture, VAD, segmentation, ASR/translation, updates.
- `Sources/UI`: menu bar, overlay, settings, wizard views.

## Caption Pipeline
`CaptionPipeline` orchestrates:
1. Capture frames from `AudioCaptureEngine`.
2. Preprocess and detect speech.
3. Segment utterances.
4. Run ASR.
5. Insert Japanese transcript blocks.
6. Spawn translation tasks for English backfill.

### Performance Mode Behavior
When `SettingsManager.performanceModeEnabled == true`:
- Translation block submission is capped (latest blocks prioritized).
- Translation in-flight limit is lower.
- Segment queue limit is reduced.
- Noise suppression is disabled to reduce CPU overhead.

## Tests
Primary command:
- `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -destination "platform=macOS" test`

Notable test coverage:
- `CaptionPipelineTests`: end-to-end flow, noisy input, speaker labels, save validation, performance-mode throttling, capture failures.
- `ModelManagerTests`: download success, checksum mismatch, network-loss behavior.
- `TranscriptManagerTests` and `TranscriptFileTests`: persistence correctness, extended sessions, disk-full mapping.
- UI behavior tests: overlay focus tracking, menu wiring, setup completion persistence.

## Release Checklist
1. Run full test suite (must pass).
2. Run 60+ minute normal-mode profile.
3. Run 60+ minute performance-mode profile and compare.
4. Validate transcript output format manually from a real meeting sample.
5. Confirm signing/notarization workflow in `Docs/BuildSigningAndUpdates.md`.

