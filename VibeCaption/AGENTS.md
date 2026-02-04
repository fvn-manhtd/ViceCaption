# Repository Guidelines

This guide summarizes where code lives and how to contribute safely to VibeCaption.

## Project Structure & Module Organization
- `Sources/App`: Entry point (`VibeCaptionApp.swift`), `AppDelegate`, menu bar bootstrap.
- `Sources/Core`: Shared state, settings, audio buffers, transcript utilities.
- `Sources/Models`: Plain data models (e.g., `AppSettings`, `AudioSegment`).
- `Sources/Services`: Audio capture, VAD, segmentation, ASR/translation (`CaptionPipeline`, `ModelManager`).
- `Sources/UI`: Menu bar, overlay window, view models (`MenuBarController`, `OverlayWindow`).
- `Resources`: `Info.plist`, entitlements, `model-catalog.json`.
- `Tests`: `UnitTests/` plus optional `IntegrationTests/` using XCTest.
- `Build/`, `DerivedData/`: Local artifacts; never commit.

## Build, Test, and Development Commands
- `open VibeCaption.xcodeproj`: Open the project in Xcode.
- `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -configuration Debug build`: Debug build.
- `xcodebuild -project VibeCaption.xcodeproj -scheme VibeCaption -destination "platform=macOS" test`: Run tests.
- Run locally via Xcode (Cmd+R) with valid signing and microphone permission.

## Coding Style & Naming Conventions
- Swift 5+, 4-space indentation, 120-character soft wrap, trailing newline.
- Types use `UpperCamelCase`; methods/properties use `lowerCamelCase`; files match primary type.
- Prefer `struct`/`final class`; use `private`/`internal` thoughtfully.
- Guard early, avoid force unwraps, and use `Logger` (os.log) for diagnostics.
- Optional: format with `swiftformat .`; lint with `swiftlint`.

## Testing Guidelines
- Framework: XCTest. Tests live under `Tests/UnitTests/` mirroring source folders.
- Naming: `ThingTests.swift`, methods like `test_method_behavesWhen_condition`.
- Favor protocol-based seams for mocks (e.g., `ASRServiceProtocol`).
- Target ≥80% coverage for changed areas and add regression tests for bugs.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Example: `feat(ui): add opacity slider to overlay`.
- PRs include summary, linked issues, UI screenshots/GIFs, and test updates. Keep scope focused.

## Security & Configuration Tips
- Microphone usage string lives in `Resources/Info.plist`.
- Entitlements are in `Resources/VibeCaption.entitlements`.
- Update `Resources/model-catalog.json` for model changes; avoid committing binaries or secrets.

## Agent-Specific Instructions
- Keep patches minimal and style-consistent.
- Place new code under `Sources/*` and tests under `Tests/UnitTests/`.
- Never touch `Build/` or `DerivedData/`; avoid adding licenses/headers unless asked.
