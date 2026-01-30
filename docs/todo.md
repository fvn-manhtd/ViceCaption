# VibeCaption Implementation Checklist

This checklist tracks the implementation progress of VibeCaption, following the roadmap defined in `docs/prompt_plan.md`.

## Phase 1: Foundation

- [x] **1. Project Setup & Basic Structure** ✅
  - [x] Initialize Xcode project (macOS 13+, Swift 5.9+, SwiftUI/AppKit)
  - [x] Create folder structure (`/App`, `/Core`, `/UI`, `/Services`, `/Models`, `/Utilities`)
  - [x] Implement minimal menu bar app (Icon + Quit menu item)
  - [x] implementation: Verify app launches and quits correctly
  - [x] test: Verify bundle identifier and deployment target

- [ ] **2. App State Machine Foundation**
  - [ ] Create `AppState` enum (idle, listening, translating, paused)
  - [ ] Implement `AppStateManager` (transitions, validation, overlay tracking)
  - [ ] Implement `toggleListening()` logic
  - [ ] test: Verify all valid/invalid state transitions
  - [ ] test: Verify state preservation

- [ ] **3. Settings & Persistence Layer**
  - [ ] Create `AppSettings` model
  - [ ] Implement `SettingsManager` with UserDefaults persistence
  - [ ] Implement `FontSize` enum and default values
  - [ ] test: Verify persistence survives app restart
  - [ ] test: Verify path validation

- [ ] **4. Transcript Data Model & Formatting**
  - [ ] Create data models: `TranscriptBlock`, `TranscriptSession`, `PauseMarker`
  - [ ] Implement `TranscriptFormatter` (display vs file format)
  - [ ] Implement `TranscriptManager`
  - [ ] test: Verify timestamp and file formatting matches spec
  - [ ] test: Verify clear/discard behavior

- [ ] **5. Error Handling Infrastructure**
  - [ ] Define `VibeCaptionError` types and `RecoveryAction` enum
  - [ ] Implement singleton `ErrorHandler`
  - [ ] Create `ErrorModalView` for UI
  - [ ] test: Verify recovery action mapping
  - [ ] test: Verify error logging

## Phase 2: Audio Pipeline

- [ ] **6. Audio Device Detection & Management**
  - [ ] Create `AudioDevice` model
  - [ ] Implement `AudioDeviceManager` (CoreAudio enumeration)
  - [ ] Implement BlackHole detection logic
  - [ ] test: Verify device enumeration and detection
  - [ ] test: Verify device change handling

- [ ] **7. Audio Capture Engine**
  - [ ] Implement `AudioCaptureEngine` (AVAudioEngine)
  - [ ] Implement `AudioRingBuffer` (Thread-safe)
  - [ ] Implement RMS level calculation for meter
  - [ ] test: Verify ring buffer read/write/overflow
  - [ ] test: Verify engine configuration

- [ ] **8. Audio Monitoring Passthrough**
  - [ ] Add monitoring support to `AudioCaptureEngine`
  - [ ] Implement passthrough to output device
  - [ ] Handle feedback loops checks
  - [ ] test: Verify monitoring enable/disable
  - [ ] test: Verify output volume control

- [ ] **9. Audio Preprocessing & Noise Suppression**
  - [ ] Implement `AudioPreprocessor`
  - [ ] Integrate Apple Voice Processing I/O (or swappable denoiser)
  - [ ] Implement sample rate conversion (to 16kHz)
  - [ ] test: Verify noise suppression toggle
  - [ ] test: Verify sample rate conversion

- [ ] **10. Voice Activity Detection & Segmentation**
  - [ ] Implement `VoiceActivityDetector` (Speech/Silence/Uncertain)
  - [ ] Implement `AudioSegmenter` (Chunking logic)
  - [ ] Define `AudioSegment` model
  - [ ] test: Verify speech vs silence detection
  - [ ] test: Verify segment boundaries and overlap

## Phase 3: AI Services

- [ ] **11. Model Manager Foundation**
  - [ ] Create `ModelInfo` and `ModelStatus` models
  - [ ] Implement `ModelManager` (Download, storage paths, checksums)
  - [ ] Create bundled `model-catalog.json`
  - [ ] test: Verify model path generation
  - [ ] test: Verify checksum validation

- [ ] **12. ASR Service Interface & Mock**
  - [ ] Define `ASRServiceProtocol` and `ASRResult`
  - [ ] Implement `MockASRService` (Configurable delays/errors)
  - [ ] Implement `ASRServiceFactory`
  - [ ] test: Verify mock returns expected segments
  - [ ] test: Verify factory switching

- [ ] **13. Translation Service Interface & Mock**
  - [ ] Define `TranslationServiceProtocol` and `TranslationResult`
  - [ ] Implement `MockTranslationService`
  - [ ] Implement `TranslationServiceFactory`
  - [ ] test: Verify mock returns expected translations

- [ ] **14. Real VibeVoice-ASR Integration**
  - [ ] Implement `VibeVoiceASRService`
  - [ ] Integrate VibeVoice runtime dependencies
  - [ ] Implement micro-batching for near-realtime
  - [ ] test: Verify transcribing sample audio
  - [ ] test: Verify speaker diarization labels

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
