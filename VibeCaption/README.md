# VibeCaption

VibeCaption is a macOS menu bar app that captures meeting audio, transcribes Japanese speech, translates it to English, and renders live overlay captions.

## What is Included
- Real-time caption pipeline (capture -> VAD -> segmentation -> ASR -> translation).
- Floating overlay with speaker labels, timestamps, and keyboard controls.
- Setup wizard for first-run audio routing.
- Settings for audio, overlay, models, diagnostics, and updates.
- Transcript session saving with autosave support.
- Performance mode that reduces runtime load by capping translation concurrency and shrinking queue pressure.

## Requirements
- macOS 13.0+
- Xcode 15+
- Apple Developer signing identity (for local run with entitlements)

## Quick Start
1. Open the project:
   - `open VibeCaption.xcodeproj`
2. Build:
   - `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -configuration Debug build`
3. Run tests:
   - `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -destination "platform=macOS" test`
4. Launch in Xcode (`Cmd+R`), grant microphone permission, then run the setup wizard from the menu bar.

## Testing
The suite includes:
- Unit tests for core state, audio utilities, formatting, persistence, and error handling.
- Integration-style pipeline tests for Japanese->English ordering, speaker labels, noisy input, save correctness, and performance-mode behavior.
- Edge-case tests for model download network failures, disk-full error mapping, capture startup failures, and long-session transcript persistence.

## Performance Profiling
Use the built-in sampling script for long sessions:
- `bash Scripts/profile_performance.sh --process-name VibeCaption --minutes 60 --interval 1 --output Docs/perf-reports/normal-mode.csv`
- Enable Performance Mode, then run again and compare:
- `bash Scripts/profile_performance.sh --process-name VibeCaption --minutes 60 --interval 1 --output Docs/perf-reports/performance-mode.csv`

The script prints min/avg/max CPU and memory, and checks the `< 30%` average CPU target.

## Documentation
- User guide: `Docs/UserGuide.md`
- Developer guide: `Docs/DeveloperGuide.md`
- Known issues: `Docs/KnownIssues.md`
- Performance validation runbook: `Docs/PerformanceValidation.md`
- Build/signing/update notes: `Docs/BuildSigningAndUpdates.md`
- App icon design: `Docs/AppIconDesign.md`

