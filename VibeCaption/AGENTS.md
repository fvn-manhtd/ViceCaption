# Repository Guidelines

## Project Structure & Module Organization
- `Sources/App`: Entry point (`VibeCaptionApp.swift`), `AppDelegate`, menu bar bootstrap.
- `Sources/Core`: App state, settings, audio buffers, transcript utilities.
- `Sources/Models`: Plain data models (e.g., `AppSettings`, `AudioSegment`).
- `Sources/Services`: Audio capture, VAD, segmentation, ASR/translation (`CaptionPipeline`, `ModelManager`).
- `Sources/UI`: Menu bar, overlay window, view models (`MenuBarController`, `OverlayWindow`).
- `Resources`: `Info.plist`, entitlements, `model-catalog.json`.
- `Tests`: `UnitTests/` plus optional `IntegrationTests/` using XCTest.
- `Build/`, `DerivedData/`: Local artifacts; do not commit.

## Build, Test, and Development Commands
- Open in Xcode: `open VibeCaption.xcodeproj`
- Build (Debug): `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -configuration Debug build`
- Test (macOS): `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -destination "platform=macOS" test`
- Run locally: Use Xcode (Cmd+R) with valid signing. Ensure microphone permission.

## Coding Style & Naming Conventions
- Swift 5+, 4‑space indentation, 120‑char soft wrap, trailing newline.
- Types `UpperCamelCase`; methods/properties `lowerCamelCase`; files match primary type.
- Prefer `struct`/`final class` where appropriate; use `private`/`internal` thoughtfully.
- Early‑exit with `guard`, avoid force‑unwraps; use `Logger` (os.log) for diagnostics.
- Optional (not enforced): format with `swiftformat .`; lint with `swiftlint`.

## Testing Guidelines
- Framework: XCTest. Place tests under `Tests/UnitTests/` mirroring source folder names.
- Naming: `ThingTests.swift`, methods like `test_method_behavesWhen_condition`.
- Mocks/stubs: prefer protocol‑based seams (e.g., `ASRServiceProtocol`, `TranslationServiceProtocol`).
- Coverage: target ≥80% for changed areas; include regression tests for bugs.
- Run: see "Test (macOS)" command above.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Example: `feat(ui): add opacity slider to overlay`.
- PRs: include summary, screenshots/GIFs for UI, linked issues, and test updates. Keep scope focused.
- Do not include `Build/` or `DerivedData/`. Update `Info.plist`/entitlements when behavior changes.

## Security & Configuration Tips
- Permissions: microphone usage string in `Resources/Info.plist`; entitlements in `Resources/VibeCaption.entitlements`.
- Models/config: extend `Resources/model-catalog.json` for new models; avoid committing large binaries or secrets.

## Agent‑Specific Instructions
- Scope: entire repo. Keep patches minimal and style‑consistent.
- Place new code under the correct `Sources/*` module and tests under `Tests/UnitTests/`.
- Never touch `Build/` or `DerivedData/`; avoid adding licenses/headers unless asked.

