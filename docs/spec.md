## 1. Product overview

**VibeCaption** is a native macOS menu bar app that captures **system audio** (Zoom / Google Meet in Chrome / Teams / Slack Huddles / Discord / YouTube, etc.) via a **virtual audio device** (e.g., BlackHole), performs **on-device Japanese speech recognition** (optional speaker labeling), translates **Japanese → English on-device**, and displays a **floating always-on-top captions overlay** with both Japanese + English.

### Primary goal (v1)

* Real-time-ish captions for **Japanese audio → English translation**, robust in noisy conditions, **fully on-device** for ASR + translation.
* Internal distribution only, **signed & notarized**, **auto-update enabled**.

### Key user workflow

1. Install VibeCaption.
2. Setup wizard guides installing/configuring BlackHole + routing (generic instructions).
3. User opens overlay, clicks it to focus.
4. Press **Space** on the overlay to start (toggle).
5. Overlay shows Japanese first, then English below; basic speaker badges; timestamps (wall-clock) per block.
6. User can pause (button), clear captions (popup choice), and save transcript automatically at end of session (per session file).

---

## 2. Target platform & constraints

* **Hardware:** Apple Silicon (M1/M2/M3), assume **≥16GB RAM**.
* **OS:** macOS **Ventura 13+**.
* **Network:** Online is allowed, but **ASR + translation must run on-device** (no external inference calls).
* **Audio capture:** System audio capture requires a **virtual loopback driver**. V1 supports **BlackHole** (user installs; app detects + guides). BlackHole is a macOS loopback driver. ([GitHub][1])
* **ASR engine:** **Whisper** (open-source) for on-device transcription with timestamps; diarization is not built-in and is optional/out-of-scope for v1. ([GitHub][2])
* **Translation engine:** Use an on-device **Core ML** MT model (recommended: **NLLB-200 distilled** CoreML conversion with ANE/GPU acceleration). ([Hugging Face][3])
* **Acceleration:** Prefer Apple Neural Engine via **Core ML** where possible. ([Apple Developer][4])

> Important note on latency: earlier “ultra-low (0.5–1s)” conflicts with “final-only” captions. V1 should be implemented as **best-effort near-realtime** by chunking/streaming audio into the ASR pipeline (Whisper) while only emitting **finalized segments** (no partials).

---

## 3. UX requirements

### 3.1 Menu bar app

* App is primarily a **menu bar** app (NSStatusItem).
* Menu items:

  * Show/Hide Overlay
  * Start/Stop (mirrors overlay Space toggle)
  * Open Settings…
  * Run Setup Wizard…
  * Open Transcript Folder
  * Quit

### 3.2 Floating overlay window

* **Always-on-top**, draggable, resizable.
* **Click-through when not focused**; becomes interactive when clicked (can receive focus). (Implement with an NSWindow + appropriate style masks + hit-testing logic.)
* **Idle state:** overlay auto-hides after **30 seconds** of inactivity; when idle and visible, shows only a small hint: “Press Space to translate”.
* **Bring back overlay:** via **menu bar icon**.
* Works in **windowed mode only** (no requirement to overlay over full-screen apps).

### 3.3 Start/stop behavior

* **Space** toggles listening:

  * Press Space (overlay focused) → start
  * Press Space again → stop
* No global hotkey required.

### 3.4 Captions display

* Continuous scrolling transcript with line breaks.
* Default visible lines: **10**, but overlay supports **scrolling** to view more.
* Show both languages:

  * **Japanese transcript** (top line)
  * **English translation** (line below)
  * Japanese appears first; English follows shortly after.
* **Speaker labeling:** “basic speaker detection/labels if possible” (no built-in diarization in Whisper). Display as a **small badge above the block** (“Speaker 1”, “Speaker 2”, …) if enabled/available.
* **Timestamps on-screen:** show **wall-clock** timestamps (e.g., `14:03:12`) **once per block** (not every line).

### 3.5 Status indicators

* Overlay shows:

  * Top-left cluster:

    * **Status dot** (Idle/Listening/Translating) with tooltip (dot + tooltip only; no words).
    * **Pause button** next to status cluster.
* Audio level meter is **settings-only**, not on overlay.

### 3.6 Pause feature

* Pause button on overlay (top-left cluster).
* When paused:

  * **Stop all processing** (save CPU).
  * Overlay shows a small “Paused” label.
* Transcript should include a marker when pause occurs:

  * `[PAUSED]` marker with **timestamp only**.
  * No `[RESUMED]` marker when unpausing.

### 3.7 “Clear captions” action

* Overlay includes a “Clear captions” action (most important quick action).
* When triggered, show a **small popup** asking:

  * “Clear display only” OR “Clear + discard”
* Popup is required each time (no shortcut-only flow).

---

## 4. Setup wizard requirements

Wizard runs on first launch and is accessible from menu.

### Steps (generic guidance only)

1. Detect whether BlackHole exists as an audio device:

   * If missing: show instructions + link out; do not auto-install. (Detect + guide user.) ([GitHub][1])
2. Explain routing:

   * Set Zoom/Chrome/Teams/etc. **output device → BlackHole**
   * In VibeCaption settings: choose input device = BlackHole, choose monitoring output = speakers/headphones.
3. Provide “Test audio” screen:

   * Real-time level meter showing whether frames are arriving.
   * Device selector to confirm correct devices.

---

## 5. Settings panel (menu bar → Settings…)

Single global settings set (no profiles).

### Required settings

* Audio Input Device:

  * Auto-pick default but allow override (**default + override**)
* Monitoring Output Device:

  * Allow selecting output for passthrough monitoring
* Overlay:

  * Font size: small/medium/large (default **Medium**)
  * Max width: fixed with wrapping (default **480px**)
  * Auto-hide: **30s**
* Models:

  * Download after install (required)
  * Model management: list installed versions, download/update, disk usage
  * Store models in user-selected path (v1 fixed path chosen below)
* Diagnostics screen:

  * Selected input/output devices
  * Audio frames arriving (yes/no + meter)
  * Model loaded status
  * Current CPU/RAM usage
* Performance mode:

  * Exists; lowers quality/model size for speed
  * Enablement: **manual only**
* Updates:

  * Auto-update enabled
  * Model update prompts appear **only in settings** (no proactive prompts)

---

## 6. File storage & data handling

### 6.1 Model storage

* Models are downloaded post-install.
* Store under:

  * `~/Documents/VibeCaption/Models/` (user-specified preference)
* Maintain versioned subfolders, e.g.:

  * `.../Models/whisper-asr/<version>/`
  * `.../Models/nllb-coreml/<version>/`

### 6.2 Transcript storage

* User wants saving enabled.
* One transcript file **per session** (each start/stop cycle).
* Default folder:

  * `~/Documents/VibeCaption/Transcripts/`
* Filename pattern:

  * `YYYY-MM-DD_HHMM_VibeCaption.txt`
* Timestamp format:

  * **Wall-clock** time in each entry.
* Content format:

  * Per block:

    * `[HH:MM:SS] (Speaker X)` header line
    * Japanese line
    * English line
  * Pause marker:

    * `[HH:MM:SS] [PAUSED]`
* “Clear + discard” should remove the cleared portion from the in-memory transcript, so it won’t be saved.

### 6.3 Privacy

* No special requirements beyond standard handling:

  * No analytics
  * No crash reporting
  * On-device ASR + translation (no external inference calls)

---

## 7. Architecture & implementation plan

### 7.1 High-level components

1. **Audio Capture & Routing (CoreAudio)**

   * AVAudioEngine / AudioUnits to capture from selected input device (BlackHole).
   * Implement monitoring passthrough: route captured audio to selected output device (allow small delay).
2. **Audio Preprocessing**

   * Optional noise suppression / voice enhancement:

     * Default ON
     * CPU increase acceptable
   * Suggested approach: use Apple Voice Processing I/O (where applicable) or integrate an on-device denoiser. (Developer choice; must be toggleable.)
3. **VAD + Segmentation**

   * Since UI wants “final only”, implement segmentation:

     * Voice activity detection → form utterance chunks.
     * Chunk policy: short rolling window with overlap for robustness.
4. **ASR: Whisper**

   * Use Whisper for transcription with timestamps. No built-in diarization; speaker labeling is optional/out-of-scope for v1. ([GitHub][2])
   * For v1 near-realtime, implement micro-batching/chunking and set language to Japanese (or enable detection as needed).
5. **Translation: Core ML MT**

   * Use NLLB-200 distilled CoreML conversion optimized for macOS/Apple devices. ([Hugging Face][3])
   * Run via Core ML to leverage ANE/GPU where available. ([Apple Developer][4])
6. **Confidence estimation**

   * Show text always, but mark low confidence (e.g., “Low confidence” indicator per block, or subtle styling).
7. **UI**

   * Menu bar: AppKit (NSStatusItem)
   * Overlay: NSWindow hosting SwiftUI view
   * Settings: SwiftUI (with AppKit bridging where needed)
8. **Updater**

   * Auto-update for app builds (Sparkle recommended for notarized internal distribution).
   * Model updates: only visible in Settings.

### 7.2 Suggested runtime pipeline

* Audio frames (input) → ring buffer → preprocessing (optional) → VAD → utterance chunk
* ASR chunk → structured segments (time/text; optional speaker)
* Emit Japanese block (final) → enqueue for translation
* Translation returns → update block with English line
* Persist to session transcript buffer

### 7.3 State machine

* Idle (overlay hidden/visible)
* Listening (capturing + processing)
* Translating (post-ASR translation in progress)
* Paused (no capture, no processing)

Overlay hidden behavior:

* When hidden: stop processing (requirement)
* When shown again: resume previous ON/OFF state

---

## 8. Error handling & recovery

### Modal dialogs (required)

* If audio routing fails / no audio frames detected:

  * Show modal error dialog
  * Include **“Fix now”** button → opens setup wizard directly to audio routing step
* If model missing/corrupt:

  * Modal explaining missing models + button to open Model Management step
* If translation/ASR runtime errors:

  * Modal with “Retry” + “Open Diagnostics”

### Common error cases

* BlackHole not installed / not selectable
* Wrong app output device (not routed to BlackHole)
* Input device mismatch
* Model download interrupted / checksum mismatch
* Out-of-memory / high CPU causing throttling
* Core ML model load failure

Diagnostics screen must show enough information to troubleshoot:

* Device names, sample rate, channels
* Frames/sec arriving
* Current pipeline state
* Model load state and versions
* CPU/RAM usage

---

## 9. Performance requirements

* “Moderate” resource use is acceptable (10–30% CPU typical on M1), with noise suppression default ON.
* Monitoring passthrough delay acceptable (50–200ms+ ok).
* Provide **Performance mode** manual toggle that lowers compute (smaller model, fewer beams, etc.).

---

## 10. Build, signing, distribution

* Internal distribution (not Mac App Store).
* Must be **signed & notarized** to avoid Gatekeeper issues.
* Auto-update enabled (Sparkle).

---

## 11. Testing plan

### 11.1 Unit tests

* Transcript formatting:

  * Timestamp formatting (wall-clock)
  * Block formatting (Speaker badge mapping)
  * Pause marker formatting
  * Clear display vs clear+discard behavior
* Settings persistence:

  * Overlay size/position persistence
  * Device selection persistence
  * Performance mode toggling
* State machine transitions:

  * Start/Stop toggle logic (Space)
  * Hide overlay stops processing; show resumes previous state
  * Pause stops processing

### 11.2 Integration tests

* Audio device routing:

  * Detect BlackHole installed
  * Confirm frames arrive when system output routed to BlackHole
  * Monitoring output selection works (passthrough audible)
* Model management:

  * Download, verify checksum, store in correct folder
  * Load/unload models, version switching
* Core ML translation:

  * Model loads and runs on target devices
  * Translation latency within acceptable bound for chunk sizes

### 11.3 End-to-end tests (golden files)

* Use recorded Japanese meeting audio samples:

  * Clean audio (baseline)
  * Noisy audio (multiple speakers, crosstalk, background music)
* Validate:

  * Speaker labels present if enabled (basic)
  * Timestamps present
  * Japanese appears first, English follows
  * Low-confidence marking appears when expected
  * Transcript file saved with correct filename and contents

### 11.4 UI tests

* Overlay focus behavior:

  * Click-through when not focused
  * Focus enables Space toggle
* Auto-hide after 30s
* Modal dialogs appear with Fix Now path
* Resizing + position remembered

### 11.5 Performance tests

* CPU/RAM profiling on M1 (16GB):

  * Listening mode
  * Listening + translation
  * Noise suppression on/off
  * Performance mode on/off
* Ensure no memory leaks during 60+ minute session.

---

## 12. Open implementation decisions (developer to choose, within constraints)

These weren’t specified by you but must be decided during implementation:

* Exact noise suppression implementation (Apple Voice Processing I/O vs custom denoiser).
* Exact chunking/VAD parameters to balance “final-only” with responsiveness.
* UI styling for low-confidence marking.
* If diarization is implemented, exact mapping from diarization output to “Speaker 1/2/3”.

---
