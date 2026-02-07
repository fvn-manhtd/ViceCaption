# User Guide

## First Launch
1. Open VibeCaption from Xcode or your signed app build.
2. Click the menu bar icon.
3. Run **Setup Wizard** if prompted.
4. In the wizard:
   - Confirm BlackHole (or your routing setup).
   - Configure input/output routing.
   - Validate audio activity in the test step.

## Daily Use
1. Open overlay from menu bar: **Show Overlay**.
2. Start listening from menu bar: **Start Listening**.
3. Speak in Japanese during your meeting.
4. Overlay shows:
   - Japanese line first.
   - English translation after processing.
   - Speaker label and timestamp.
5. Stop listening to end session and save transcript.

## Keyboard Shortcuts
- `Space` (when overlay focused): Toggle listening state.
- `O` from menu bar menu: Show/Hide overlay.
- `,` from menu bar menu: Open settings.

## Managing Captions
- Use the overlay trash icon to:
  - **Clear display only** (keeps saved-session data).
  - **Clear + discard** (removes unsaved content).

## Settings Highlights
- **General**:
  - Performance Mode: lowers CPU by reducing translation concurrency.
  - Noise Suppression: enables audio cleanup.
- **Overlay**: font size, max width, auto-hide behavior.
- **Diagnostics**: current CPU %, memory use, model status, app state.

