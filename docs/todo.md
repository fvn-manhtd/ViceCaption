# VibeCaption Implementation Checklist

This checklist tracks the implementation progress of VibeCaption, following the roadmap defined in `docs/prompt_plan.md`.

## Phase 1: Foundation

- [x] **1. Project Setup & Basic Structure** ✅
  - [x] Initialize Xcode project (macOS 13+, Swift 5.9+, SwiftUI/AppKit)
  - [x] Create folder structure (`/App`, `/Core`, `/UI`, `/Services`, `/Models`, `/Utilities`)
  - [x] Implement minimal menu bar app (Icon + Quit menu item)
  - [x] implementation: Verify app launches and quits correctly
  - [x] test: Verify bundle identifier and deployment target

- [x] **2. App State Machine Foundation** ✅
  - [x] Create `AppState` enum (idle, listening, translating, paused)
  - [x] Implement `AppStateManager` (transitions, validation, overlay tracking)
  - [x] Implement `toggleListening()` logic
  - [x] test: Verify all valid/invalid state transitions
  - [x] test: Verify state preservation

- [x] **3. Settings & Persistence Layer** ✅
  - [x] Create `AppSettings` model
  - [x] Implement `SettingsManager` with UserDefaults persistence
  - [x] Implement `FontSize` enum and default values
  - [x] test: Verify persistence survives app restart
  - [x] test: Verify path validation

- [x] **4. Transcript Data Model & Formatting** ✅
  - [x] Create data models: `TranscriptBlock`, `TranscriptSession`, `PauseMarker`
  - [x] Implement `TranscriptFormatter` (display vs file format)
  - [x] Implement `TranscriptManager`
  - [x] test: Verify timestamp and file formatting matches spec
  - [x] test: Verify clear/discard behavior

- [x] **5. Error Handling Infrastructure** ✅
  - [x] Define `VibeCaptionError` types and `RecoveryAction` enum
  - [x] Implement singleton `ErrorHandler`
  - [x] Create `ErrorModalView` for UI
  - [x] test: Verify recovery action mapping
  - [x] test: Verify error logging

## Phase 2: Audio Pipeline

- [x] **6. Audio Device Detection & Management** ✅
  - [x] Create `AudioDevice` model
  - [x] Implement `AudioDeviceManager` (CoreAudio enumeration)
  - [x] Implement BlackHole detection logic
  - [x] test: Verify device enumeration and detection
  - [x] test: Verify device change handling

- [x] **7. Audio Capture Engine** ✅
  - [x] Implement `AudioCaptureEngine` (AVAudioEngine)
  - [x] Implement `AudioRingBuffer` (Thread-safe)
  - [x] Implement RMS level calculation for meter
  - [x] test: Verify ring buffer read/write/overflow
  - [x] test: Verify engine configuration

- [x] **8. Audio Monitoring Passthrough** ✅
  - [x] Add monitoring support to `AudioCaptureEngine`
  - [x] Implement passthrough to output device
  - [x] Handle feedback loops checks
  - [x] test: Verify monitoring enable/disable
  - [x] test: Verify output volume control

- [x] **9. Audio Preprocessing & Noise Suppression** ✅
  - [x] Implement `AudioPreprocessor`
  - [x] Integrate Apple Voice Processing I/O (or swappable denoiser)
  - [x] Implement sample rate conversion (to 16kHz)
  - [x] test: Verify noise suppression toggle
  - [x] test: Verify sample rate conversion

- [x] **10. Voice Activity Detection & Segmentation** ✅
  - [x] Implement `VoiceActivityDetector` (Speech/Silence/Uncertain)
  - [x] Implement `AudioSegmenter` (Chunking logic)
  - [x] Define `AudioSegment` model
  - [x] test: Verify speech vs silence detection
  - [x] test: Verify segment boundaries and overlap

## Phase 3: AI Services

- [x] **11. Model Manager Foundation** ✅
  - [x] Create `ModelInfo` and `ModelStatus` models
  - [x] Implement `ModelManager` (Download, storage paths, checksums)
  - [x] Create bundled `model-catalog.json`
  - [x] test: Verify model path generation
  - [x] test: Verify checksum validation

- [x] **12. ASR Service Interface & Mock** ✅
  - [x] Define `ASRServiceProtocol`, `ASRResult`, `ASRSegment`
  - [x] Implement `MockASRService` (configurable delays/errors/empty + speaker IDs)
  - [x] Implement `ASRServiceFactory` (mock in debug/tests)
  - [x] test: Verify mock returns expected segments and delays
  - [x] test: Verify failure simulation and speaker consistency
  - [x] test: Verify factory switching
  - [x] Integration: pipeline now calls ASR and logs results; conversion to `TranscriptBlock` added

- [ ] **13. Translation Service Interface & Mock**
  - [ ] Define `TranslationServiceProtocol` and `TranslationResult`
  - [ ] Implement `MockTranslationService`
  - [ ] Implement `TranslationServiceFactory`
  - [ ] test: Verify mock returns expected translations

- [ ] **14. Real Whisper ASR Integration**
  - [ ] Implement `WhisperASRService`
  - [ ] Integrate Whisper runtime dependencies (e.g., whisper.cpp wrapper)
  - [ ] Implement micro-batching for near-realtime
  - [ ] test: Verify transcribing sample Japanese audio with timestamps
  - [ ] test: Verify error handling and memory usage

- [ ] **15. Real NLLB-200 CoreML Translation Integration**
  - [ ] Implement `NLLBTranslationService`
  - [ ] Integrate CoreML model loading (ANE/GPU)
  - [ ] Implement tokenization
  - [ ] test: Verify Japanese to English translation
  - [ ] test: Verify performance/latency

## Phase 4: UI Components

- [ ] **16. Menu Bar Implementation**
  - [ ] Implement `MenuBarController`
  - [ ] Connect menu items to `AppStateManager`
  - [ ] Implement dynamic icon states (Listening/Paused)
  - [ ] test: Verify menu item state updates

- [ ] **17. Floating Overlay Window Foundation**
  - [ ] Implement `OverlayWindow` (NSWindow subclass, auto-save position)
  - [ ] Implement `OverlayViewModel`
  - [ ] Handle click-through vs focused states
  - [ ] test: Verify persistence of window position/size
  - [ ] test: Verify visibility toggling

- [ ] **18. Overlay Caption Display**
  - [ ] Implement `OverlayContentView` (Scrollable list)
  - [ ] Implement `CaptionBlockView` (Speaker, Timestamp, JA/EN text)
  - [ ] Apply styling preferences (Font size, width)
  - [ ] test: Verify rendering of block components

- [ ] **19. Overlay Controls & Status**
  - [ ] Implement `OverlayControlsView` (Status dot, Pause button)
  - [ ] Implement Space key toggle handler
  - [ ] Implement Auto-hide logic (timer)
  - [ ] test: Verify status dot states and animations
  - [ ] test: Verify auto-hide triggers

- [ ] **20. Clear Captions Action**
  - [ ] Implement `ClearCaptionsPopup` (Display only vs Clear+Discard)
  - [ ] Add Clear button to overlay
  - [ ] Wire actions to `TranscriptManager`
  - [ ] test: Verify correct clear method calls

- [ ] **21. Settings Panel**
  - [ ] Implement `SettingsWindow` with tabs
  - [ ] Build tabs: Audio, Overlay, Models, Diagnostics, Updates
  - [ ] Connect UI controls to `SettingsManager`
  - [ ] test: Verify settings changes persist

- [ ] **22. Setup Wizard**
  - [ ] Implement `SetupWizardWindow` (step-by-step flow)
  - [ ] Build steps: Welcome, BlackHole Check, Routing, Audio Test, Finish
  - [ ] Implement first-launch logic
  - [ ] test: Verify flow navigation and completion flag

## Phase 5: Integration & Polish

- [ ] **23. Full Pipeline Integration**
  - [ ] Implement `CaptionPipeline` (orchestrator)
  - [ ] Wire Audio -> VAD -> ASR -> Translation -> UI
  - [ ] Handle concurrency and backpressure
  - [ ] test: Verify full flow with mock services
  - [ ] test: Verify pause/resume handling

- [ ] **24. Transcript File Saving**
  - [ ] Implement automatic daily file saving in `TranscriptManager`
  - [ ] Handle "Open Transcript Folder" action
  - [ ] test: Verify saved file content exact match

- [ ] **25. Auto-Update with Sparkle**
  - [ ] Integrate Sparkle framework
  - [ ] Implement `UpdateManager`
  - [ ] Add update UI to Settings
  - [ ] Configure signing and notarization

- [ ] **26. Error Modals & Recovery Flows**
  - [ ] Enhance `ErrorModalView` with specific recovery actions
  - [ ] Implement `RecoveryActionHandler`
  - [ ] Wire recovery flows (e.g., Error -> Fix Now -> Wizard)
  - [ ] test: Verify error recovery navigation

- [ ] **27. Final Polish & End-to-End Testing**
  - [ ] UI Polish (Animations, Dark mode, Accessibility)
  - [ ] Performance profiling (Memory/CPU)
  - [ ] Record and verify with "golden file" audio samples
  - [ ] Final bug fixes and documentation
