# VibeCaption Implementation Prompt Plan

> A series of test-driven prompts for building a macOS menu bar app that captures system audio, performs on-device Japanese speech recognition, and translates to English with a floating overlay.

---

## Project Blueprint Overview

### Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        VibeCaption                              │
├─────────────────────────────────────────────────────────────────┤
│  UI Layer                                                       │
│  ├── Menu Bar App (NSStatusItem)                                │
│  ├── Floating Overlay (NSWindow + SwiftUI)                      │
│  ├── Settings Panel (SwiftUI)                                   │
│  └── Setup Wizard (SwiftUI)                                     │
├─────────────────────────────────────────────────────────────────┤
│  Core Services                                                  │
│  ├── Audio Capture Service (AVAudioEngine)                      │
│  ├── Audio Preprocessing (Noise Suppression)                    │
│  ├── VAD & Segmentation                                         │
│  ├── ASR Service (VibeVoice-ASR)                                │
│  └── Translation Service (NLLB-200 CoreML)                      │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer                                                     │
│  ├── Transcript Manager                                         │
│  ├── Model Manager                                              │
│  ├── Settings Persistence                                       │
│  └── Session Storage                                            │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure                                                 │
│  ├── State Machine                                              │
│  ├── Error Handling                                             │
│  └── Auto-Update (Sparkle)                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Build Phases

| Phase | Focus | Prompts |
|-------|-------|---------|
| 1 | Foundation | 1-5 |
| 2 | Audio Pipeline | 6-10 |
| 3 | AI Services | 11-15 |
| 4 | UI Components | 16-22 |
| 5 | Integration & Polish | 23-27 |

---

## Phase 1: Foundation

### Prompt 1: Project Setup & Basic Structure

```text
Create a new macOS menu bar application called "VibeCaption" targeting macOS Ventura 13+ on Apple Silicon.

Requirements:
1. Set up an Xcode project with:
   - Deployment target: macOS 13.0
   - Swift 5.9+
   - SwiftUI lifecycle with AppKit bridging for menu bar
   - Bundle identifier: com.yourcompany.vibecaption

2. Create the basic folder structure:
   - /Sources
     - /App (main app entry)
     - /Core (business logic)
     - /UI (views and view models)
     - /Services (audio, ASR, translation)
     - /Models (data models)
     - /Utilities (helpers, extensions)
   - /Tests
     - /UnitTests
     - /IntegrationTests
   - /Resources

3. Create a minimal menu bar app that:
   - Shows an icon in the menu bar (use SF Symbol "captions.bubble")
   - Has a menu with only "Quit" option that works
   - Logs "VibeCaption launched" on startup

4. Write a unit test that verifies:
   - The app bundle identifier is correct
   - The minimum deployment target is macOS 13.0

Deliverables:
- Working Xcode project that builds and runs
- Menu bar icon visible with functional Quit menu item
- One passing unit test
```

---

### Prompt 2: App State Machine Foundation

```text
Building on the previous project setup, implement the core application state machine.

Context: VibeCaption has four states: Idle, Listening, Translating, and Paused. We need a robust state machine to manage transitions.

Requirements:
1. Create an `AppState` enum in /Sources/Core/AppState.swift:
   - idle: Default state, no processing
   - listening: Capturing and processing audio
   - translating: Post-ASR translation in progress
   - paused: Temporarily stopped, no capture

2. Create an `AppStateManager` class as an ObservableObject:
   - Published property for current state
   - Methods for state transitions with validation:
     - startListening() -> throws if models not loaded
     - stopListening()
     - pause()
     - resume()
     - toggleListening() -> main toggle for Space key
   - Property to track if overlay is visible (state preservation)
   - Delegate/callback pattern for state change notifications

3. Write comprehensive unit tests:
   - Test all valid state transitions
   - Test invalid transitions throw appropriate errors
   - Test toggleListening() behavior from each state
   - Test state preservation when overlay hidden/shown
   - Test pause stops processing flag

4. Integration with existing app:
   - Initialize AppStateManager in the main app
   - Log state changes to console for debugging

Deliverables:
- AppState.swift with enum definition
- AppStateManager.swift with full implementation
- AppStateManagerTests.swift with 10+ test cases
- All tests passing
```

---

### Prompt 3: Settings & Persistence Layer

```text
Building on the state machine, implement the settings persistence layer.

Context: VibeCaption needs to persist user preferences including audio devices, overlay configuration, and performance settings.

Requirements:
1. Create `AppSettings` model in /Sources/Models/AppSettings.swift:
   - audioInputDeviceID: String? (nil = default)
   - monitoringOutputDeviceID: String? (nil = default)
   - overlayFontSize: FontSize enum (small/medium/large, default: medium)
   - overlayMaxWidth: CGFloat (default: 480)
   - overlayAutoHideSeconds: Int (default: 30)
   - noiseSuppresssionEnabled: Bool (default: true)
   - performanceModeEnabled: Bool (default: false)
   - modelStoragePath: String (default: ~/Documents/VibeCaption/Models/)
   - transcriptStoragePath: String (default: ~/Documents/VibeCaption/Transcripts/)

2. Create `SettingsManager` class:
   - Uses UserDefaults for persistence
   - Observable for SwiftUI binding
   - Computed properties with getters/setters
   - Reset to defaults method
   - Validation for paths (creates if not exists)

3. Create FontSize enum with display names and actual font sizes:
   - small: 12pt
   - medium: 14pt  
   - large: 18pt

4. Write unit tests:
   - Test default values are correct
   - Test persistence survives app restart (mock UserDefaults)
   - Test path validation creates directories
   - Test reset to defaults works
   - Test each setting can be read/written independently

Deliverables:
- AppSettings.swift with model
- SettingsManager.swift with persistence logic
- SettingsManagerTests.swift with complete coverage
- All tests passing
```

---

### Prompt 4: Transcript Data Model & Formatting

```text
Building on settings, implement the transcript data model and formatting logic.

Context: Transcripts show Japanese text with English translation, speaker labels, and wall-clock timestamps. They must be saved to files in a specific format.

Requirements:
1. Create data models in /Sources/Models/:
   
   TranscriptBlock.swift:
   - id: UUID
   - timestamp: Date (wall-clock time)
   - speakerLabel: String? ("Speaker 1", "Speaker 2", etc.)
   - japaneseText: String
   - englishText: String? (nil until translation complete)
   - confidence: Double (0.0-1.0)
   - isLowConfidence: Bool (computed, < 0.7)

   TranscriptSession.swift:
   - id: UUID
   - startTime: Date
   - endTime: Date?
   - blocks: [TranscriptBlock]
   - pauseMarkers: [PauseMarker] // timestamp only
   - Add block / add pause marker methods

   PauseMarker.swift:
   - timestamp: Date

2. Create `TranscriptFormatter` in /Sources/Core/:
   - formatForDisplay(block:) -> AttributedString (for overlay)
   - formatForFile(session:) -> String (plain text for saving)
   - File format per spec:
     [HH:MM:SS] (Speaker X)
     Japanese text here
     English text here
     
     [HH:MM:SS] [PAUSED]

3. Create `TranscriptManager`:
   - Current session storage
   - startNewSession()
   - addBlock(block:)
   - addPauseMarker()
   - clearDisplay() - clears UI but keeps file data
   - clearAndDiscard() - removes cleared portion permanently
   - saveSession() -> saves to file with pattern YYYY-MM-DD_HHMM_VibeCaption.txt
   - Uses SettingsManager for path

4. Write comprehensive unit tests:
   - Test block creation with all fields
   - Test timestamp formatting (wall-clock HH:MM:SS)
   - Test file format output matches spec exactly
   - Test pause marker insertion
   - Test clearDisplay vs clearAndDiscard behavior
   - Test filename generation pattern
   - Test session save creates correct file

Deliverables:
- TranscriptBlock.swift, TranscriptSession.swift, PauseMarker.swift
- TranscriptFormatter.swift
- TranscriptManager.swift
- Full test coverage with 15+ tests
```

---

### Prompt 5: Error Handling Infrastructure

```text
Building on the transcript system, implement centralized error handling.

Context: VibeCaption needs modal dialogs for errors with specific actions like "Fix Now" buttons. Errors must be categorized and recoverable where possible.

Requirements:
1. Create error types in /Sources/Core/Errors/:

   VibeCaptionError.swift:
   - enum with associated values for:
     - audioRoutingFailed(device: String, reason: String)
     - noAudioFramesDetected
     - blackHoleNotInstalled
     - inputDeviceMismatch(expected: String, actual: String)
     - modelMissing(modelName: String)
     - modelCorrupted(modelName: String, path: String)
     - modelDownloadFailed(modelName: String, reason: String)
     - translationFailed(reason: String)
     - asrFailed(reason: String)
     - outOfMemory
     - coreMLLoadFailed(modelName: String, reason: String)
   
   - Properties:
     - localizedDescription: String
     - recoverySuggestion: String
     - recoveryAction: RecoveryAction enum

   RecoveryAction.swift:
   - enum: openSetupWizard, openModelManagement, openDiagnostics, retry, none

2. Create `ErrorHandler` class:
   - Singleton for app-wide error handling
   - Method: handleError(_ error: VibeCaptionError)
   - Published property for current error (for UI binding)
   - Delegate pattern for recovery action execution
   - Logging of all errors with timestamps

3. Create `ErrorModalView` SwiftUI view:
   - Displays error description and recovery suggestion
   - Shows appropriate button based on RecoveryAction
   - "Fix Now" -> triggers recovery action
   - "Dismiss" always available
   - Styled as macOS modal sheet

4. Write unit tests:
   - Test all error cases have valid descriptions
   - Test all error cases have valid recovery suggestions
   - Test recovery action mapping is correct
   - Test error logging captures all errors
   - Test error state is observable

Deliverables:
- VibeCaptionError.swift
- RecoveryAction.swift  
- ErrorHandler.swift
- ErrorModalView.swift
- ErrorHandlingTests.swift with complete coverage
```

---

## Phase 2: Audio Pipeline

### Prompt 6: Audio Device Detection & Management

```text
Building on the error handling, implement audio device detection and management.

Context: VibeCaption needs to detect available audio devices, specifically BlackHole for capturing system audio, and allow users to select input/output devices.

Requirements:
1. Create `AudioDevice` model in /Sources/Models/:
   - id: AudioDeviceID (from CoreAudio)
   - uid: String
   - name: String
   - isInput: Bool
   - isOutput: Bool
   - isBlackHole: Bool (computed from name containing "BlackHole")
   - sampleRate: Double
   - channelCount: Int

2. Create `AudioDeviceManager` in /Sources/Services/:
   - Singleton instance
   - Published lists: inputDevices, outputDevices
   - Method: refreshDevices()
   - Method: getDevice(byID:) -> AudioDevice?
   - Method: getDefaultInputDevice() -> AudioDevice?
   - Method: getDefaultOutputDevice() -> AudioDevice?
   - Method: isBlackHoleInstalled() -> Bool
   - Listen for device changes (AudioObjectAddPropertyListener)
   - Throws VibeCaptionError.blackHoleNotInstalled when needed

3. Use CoreAudio APIs:
   - AudioObjectGetPropertyData for device enumeration
   - Handle kAudioHardwarePropertyDevices
   - Get device names via kAudioDevicePropertyDeviceNameCFString

4. Write unit tests (with mocking):
   - Test device enumeration returns valid devices
   - Test BlackHole detection by name
   - Test default device selection
   - Test device change notification handling
   - Test error thrown when BlackHole not found (mocked)

5. Integration:
   - On app launch, refresh devices
   - Log detected devices to console
   - Store selected devices in SettingsManager

Deliverables:
- AudioDevice.swift
- AudioDeviceManager.swift
- AudioDeviceManagerTests.swift
- Console output showing detected devices on launch
```

---

### Prompt 7: Audio Capture Engine

```text
Building on device management, implement the core audio capture engine.

Context: VibeCaption captures system audio via BlackHole using AVAudioEngine. Audio is streamed to a ring buffer for processing.

Requirements:
1. Create `AudioCaptureEngine` in /Sources/Services/:
   - Properties:
     - isCapturing: Bool (published)
     - currentInputDevice: AudioDevice?
     - audioLevel: Float (0.0-1.0, published for UI meter)
   
   - Methods:
     - configure(inputDevice: AudioDevice) throws
     - startCapture() throws
     - stopCapture()
     - setAudioCallback(_ callback: (AVAudioPCMBuffer) -> Void)
   
   - Internal:
     - AVAudioEngine instance
     - Input node tap for audio data
     - Calculate RMS for audio level meter
     - 16kHz sample rate conversion (for ASR compatibility)

2. Create `AudioRingBuffer` in /Sources/Core/:
   - Thread-safe circular buffer for audio samples
   - Configurable size (default: 30 seconds of audio)
   - Methods:
     - write(_ buffer: AVAudioPCMBuffer)
     - read(samples: Int) -> [Float]?
     - clear()
     - availableSamples: Int

3. Error handling:
   - Throw audioRoutingFailed if device not accessible
   - Throw noAudioFramesDetected if no data after 5 seconds
   - Handle device disconnection gracefully

4. Write unit tests:
   - Test ring buffer write/read operations
   - Test ring buffer thread safety (concurrent access)
   - Test ring buffer overflow handling
   - Test audio level calculation (mock buffer with known values)
   - Test engine configuration with valid device
   - Test error on invalid device

5. Integration:
   - Connect to AudioDeviceManager for device selection
   - Log audio level periodically (debugging)

Deliverables:
- AudioCaptureEngine.swift
- AudioRingBuffer.swift
- AudioCaptureEngineTests.swift
- AudioRingBufferTests.swift
```

---

### Prompt 8: Audio Monitoring Passthrough

```text
Building on the capture engine, implement audio monitoring passthrough.

Context: Users need to hear the captured audio through their speakers/headphones while VibeCaption processes it. This requires routing captured audio to a selected output device.

Requirements:
1. Extend `AudioCaptureEngine`:
   - Add monitoringOutputDevice: AudioDevice? property
   - Add monitoringEnabled: Bool property
   - Add setMonitoringOutput(device: AudioDevice) method
   - Implement passthrough using AVAudioEngine's output node
   - Allow small latency (50-200ms acceptable per spec)

2. Create `AudioMonitor` component (or integrate into engine):
   - Route captured PCM buffers to output device
   - Volume control (0.0-1.0)
   - Mute toggle
   - Handle device changes gracefully

3. Handle edge cases:
   - Same device for input and output (prevent feedback)
   - Device disconnection mid-monitoring
   - Sample rate mismatch between input and output

4. Write unit tests:
   - Test monitoring can be enabled/disabled
   - Test output device selection
   - Test volume control affects output
   - Test feedback prevention when same device
   - Test graceful handling of device disconnection

5. Integration:
   - Connect monitoring output selection to SettingsManager
   - Persist monitoring device preference

Deliverables:
- Updated AudioCaptureEngine.swift with monitoring
- AudioMonitorTests.swift
- Monitoring device persisted in settings
```

---

### Prompt 9: Audio Preprocessing & Noise Suppression

```text
Building on monitoring, implement audio preprocessing with noise suppression.

Context: VibeCaption should clean up audio before ASR to improve transcription quality. Noise suppression is ON by default and toggleable.

Requirements:
1. Create `AudioPreprocessor` in /Sources/Services/:
   - Properties:
     - noiseSuppressionEnabled: Bool (default: true)
     - outputSampleRate: Double (16000 for ASR)
   
   - Methods:
     - process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer
     - reset() - clear internal state

2. Implement noise suppression:
   - Option A (recommended): Use Apple's Voice Processing I/O
     - AVAudioEngine's voice processing mode
     - Automatic echo cancellation and noise reduction
   - Option B: Integrate a lightweight denoiser
     - RNNoise-style or simple spectral subtraction
   
   - Make implementation swappable via protocol

3. Implement sample rate conversion:
   - Convert from device sample rate to 16kHz
   - Use AVAudioConverter
   - Handle mono/stereo conversion

4. Performance considerations:
   - Process in real-time (< 20ms per chunk)
   - CPU increase acceptable per spec
   - Add performance metrics logging

5. Write unit tests:
   - Test noise suppression toggle
   - Test sample rate conversion accuracy
   - Test processing latency measurement
   - Test reset clears state
   - Test passthrough when disabled

6. Integration:
   - Wire noise suppression setting to SettingsManager
   - Insert preprocessor between capture and ring buffer

Deliverables:
- AudioPreprocessor.swift
- AudioPreprocessorTests.swift
- Preprocessing integrated into audio pipeline
```

---

### Prompt 10: Voice Activity Detection & Segmentation

```text
Building on preprocessing, implement VAD and audio segmentation.

Context: VibeCaption should detect speech segments and create chunks for ASR processing. Only finalized segments are shown (no partials), so we need reliable segmentation.

Requirements:
1. Create `VoiceActivityDetector` in /Sources/Services/:
   - Properties:
     - isSpeechDetected: Bool (published)
     - speechThreshold: Float (configurable)
     - silenceThreshold: Float (configurable)
   
   - Methods:
     - process(_ buffer: AVAudioPCMBuffer) -> VADResult
     - reset()
   
   - VADResult:
     - enum: speech, silence, uncertain
     - confidence: Float

2. Create `AudioSegmenter` in /Sources/Services/:
   - Properties:
     - minSegmentDuration: TimeInterval (0.5s)
     - maxSegmentDuration: TimeInterval (10s)
     - silencePadding: TimeInterval (0.3s)
   
   - Methods:
     - process(_ buffer: AVAudioPCMBuffer, vadResult: VADResult)
     - setSegmentCallback(_ callback: (AudioSegment) -> Void)
   
   - AudioSegment:
     - startTime: TimeInterval
     - endTime: TimeInterval
     - audioData: [Float]
     - estimatedWordCount: Int (rough estimate)

3. Segmentation strategy:
   - Start segment on speech detection
   - End segment on silence (after padding)
   - Force end at maxSegmentDuration
   - Overlap handling for continuity

4. Write unit tests:
   - Test VAD detects speech in known audio
   - Test VAD detects silence correctly
   - Test segment creation with min/max duration
   - Test segment callback is triggered
   - Test overlap handling
   - Test reset clears pending segment

5. Integration:
   - Wire preprocessed audio to VAD
   - Wire VAD to segmenter
   - Segments go to ASR queue (stub for now)

Deliverables:
- VoiceActivityDetector.swift
- AudioSegmenter.swift
- AudioSegment.swift (model)
- VADTests.swift
- AudioSegmenterTests.swift
```

---

## Phase 3: AI Services

### Prompt 11: Model Manager Foundation

```text
Building on the audio pipeline, implement the model management system.

Context: VibeCaption uses two on-device models: Whisper-ASR for transcription and a Mac M1 Pro–suitable real-time translation model for translation. Models must be downloaded, versioned, and managed.

Model Choices

ASR (required): Whisper (e.g., whisper-small or whisper-base), packaged for on-device inference.

Translation (required): MarianMT / OPUS-MT compiled to Core ML for the target language pair (e.g., opus-mt-en-ja-coreml, opus-mt-ja-en-coreml) to prioritize low latency on M1 Pro.

Translation (optional high-quality): NLLB-200 600M (only if you want a “quality mode”; may be too slow for real-time on laptop depending on segment length).

Requirements:

1. Create model definitions in /Sources/Models/

ModelInfo.swift

id: String (e.g., "whisper-asr", "opus-mt-en-ja-coreml", "opus-mt-ja-en-coreml", "nllb-200-600m-optional")

displayName: String

version: String

downloadURL: URL

checksum: String (SHA256)

sizeBytes: Int64

isRequired: Bool

ModelStatus.swift

enum: notDownloaded, downloading(progress: Double), downloaded, corrupted, updateAvailable

2. Create ModelManager in /Sources/Services/

Properties

models: [ModelInfo] (published)

modelStatuses: [String: ModelStatus] (published)

downloadProgress: [String: Double] (published)

Methods

loadModelCatalog() — from bundled JSON or remote

getModelPath(for: ModelInfo) -> URL?

isModelReady(_ modelID: String) -> Bool

downloadModel(_ model: ModelInfo) async throws

verifyModel(_ model: ModelInfo) -> Bool (checksum)

deleteModel(_ model: ModelInfo) throws

getInstalledVersions() -> [String: String]

getTotalDiskUsage() -> Int64

Additional behavior (important for “real-time” translation)

Provide helper queries:

getTranslationModelID(for sourceLang: String, targetLang: String) -> String?

getASRModelID() -> String?

Prefer OPUS-MT CoreML translation models by default.

Allow “quality mode” to switch to optional NLLB if installed.

3. Storage structure

Base path from SettingsManager

~/Documents/VibeCaption/Models/whisper-asr/<version>/

~/Documents/VibeCaption/Models/opus-mt-en-ja-coreml/<version>/

~/Documents/VibeCaption/Models/opus-mt-ja-en-coreml/<version>/

(optional) ~/Documents/VibeCaption/Models/nllb-200-600m-optional/<version>/

4. Write unit tests

Test model catalog loading

Test path generation is correct

Test checksum verification (with known test file)

Test disk usage calculation

Test status transitions

Test download cancellation

Test translation model selection logic (EN→JA chooses opus-mt-en-ja-coreml, etc.)

5. Integration

Create bundled model-catalog.json with placeholder URLs

Initialize ModelManager on app launch

Check model status and update AppStateManager

Deliverables:

ModelInfo.swift

ModelStatus.swift

ModelManager.swift

model-catalog.json (bundled resource)

ModelManagerTests.swift

Suggested model-catalog.json IDs (example)

Use these IDs in your catalog so the app can pick the right translation model per language direction:

whisper-asr (required)

opus-mt-en-ja-coreml (required if EN→JA supported)

opus-mt-ja-en-coreml (required if JA→EN supported)

nllb-200-600m-optional (optional “quality mode”)
```

---

### Prompt 12: ASR Service Interface & Mock

```text
Building on model management, create the ASR service interface with a mock implementation.

Context: We'll integrate VibeVoice-ASR later, but first need a clean interface and mock for testing the full pipeline.

Requirements:
1. Create ASR protocol and models in /Sources/Services/ASR/:

   ASRResult.swift:
   - segments: [ASRSegment]
   - processingTime: TimeInterval
   
   ASRSegment.swift:
   - text: String (Japanese)
   - startTime: TimeInterval
   - endTime: TimeInterval
   - speakerID: Int?
   - confidence: Double

   ASRServiceProtocol.swift:
   - func loadModel() async throws
   - func unloadModel()
   - var isModelLoaded: Bool { get }
   - func transcribe(_ audio: AudioSegment) async throws -> ASRResult

2. Create `MockASRService` implementing ASRServiceProtocol:
   - Simulates realistic delay (0.5-2s based on audio length)
   - Returns predefined Japanese text segments
   - Generates mock speaker IDs (1-3 speakers)
   - Configurable for testing different scenarios:
     - success with high confidence
     - success with low confidence
     - failure (throws error)
     - empty result

3. Create `ASRServiceFactory`:
   - getService(useMock: Bool) -> ASRServiceProtocol
   - Returns mock in debug/test, real in production

4. Write unit tests:
   - Test mock returns expected results
   - Test mock respects configured delays
   - Test mock can simulate failures
   - Test factory returns correct implementation
   - Test speaker ID assignment is consistent

5. Integration:
   - Wire ASR service to AudioSegmenter output
   - Process segments and log results
   - Create ASRResult -> TranscriptBlock conversion

Deliverables:
- ASRResult.swift, ASRSegment.swift
- ASRServiceProtocol.swift
- MockASRService.swift
- ASRServiceFactory.swift
- ASRServiceTests.swift
```

---

### Prompt 13: Translation Service Interface & Mock

```text
Building on the ASR interface, create the translation service interface with a mock implementation.

Context: We'll integrate NLLB-200 CoreML later, but first need a clean interface and mock for testing.

Requirements:
1. Create translation protocol and models in /Sources/Services/Translation/:

   TranslationResult.swift:
   - originalText: String
   - translatedText: String
   - confidence: Double
   - processingTime: TimeInterval

   TranslationServiceProtocol.swift:
   - func loadModel() async throws
   - func unloadModel()
   - var isModelLoaded: Bool { get }
   - func translate(_ text: String, from: Language, to: Language) async throws -> TranslationResult

   Language.swift:
   - enum: japanese, english (extensible for future)
   - Code property (e.g., "ja", "en")

2. Create `MockTranslationService` implementing TranslationServiceProtocol:
   - Simulates realistic delay (0.3-1s based on text length)
   - Returns predefined English translations
   - Configurable for testing:
     - success with high confidence
     - success with low confidence
     - failure (throws error)
   - Dictionary of common test phrases

3. Create `TranslationServiceFactory`:
   - getService(useMock: Bool) -> TranslationServiceProtocol
   - Returns mock in debug/test, real in production

4. Write unit tests:
   - Test mock returns expected translations
   - Test mock respects configured delays
   - Test mock can simulate failures
   - Test factory returns correct implementation
   - Test language enum properties

5. Integration:
   - Wire translation service to ASR output
   - Update TranscriptBlock with English text when ready
   - Log translation results

Deliverables:
- TranslationResult.swift
- TranslationServiceProtocol.swift
- Language.swift
- MockTranslationService.swift
- TranslationServiceFactory.swift
- TranslationServiceTests.swift
```

---

### Prompt 14: Real VibeVoice-ASR Integration

```text
Building on the mock ASR, implement the real VibeVoice-ASR integration.

Context: VibeVoice-ASR is a Microsoft open-source model for rich transcription with speaker diarization. We need to integrate it for on-device Japanese ASR.

Requirements:
1. Research and setup:
   - Add VibeVoice-ASR as a dependency (via Swift Package Manager or manual integration)
   - Understand the model input format (audio format, sample rate)
   - Understand output format (segments, speakers, timestamps)

2. Create `VibeVoiceASRService` implementing ASRServiceProtocol:
   - loadModel():
     - Get model path from ModelManager
     - Initialize VibeVoice runtime
     - Throw modelMissing if not downloaded
     - Throw coreMLLoadFailed on initialization error
   
   - transcribe(_ audio: AudioSegment):
     - Convert AudioSegment to required format
     - Run inference
     - Parse output to ASRResult
     - Map speaker IDs to consistent labels

3. Handle VibeVoice specifics:
   - Long-form single-pass emphasis -> micro-batching
   - Maintain speaker continuity across chunks
   - Best-effort near-realtime processing

4. Performance optimization:
   - Use Apple Neural Engine where possible
   - Performance mode: smaller model variant if available
   - Memory management for long sessions

5. Write integration tests:
   - Test model loading from disk
   - Test transcription of sample Japanese audio
   - Test speaker diarization output
   - Test error handling for missing model
   - Test memory usage during long transcription

6. Integration:
   - Register with ASRServiceFactory
   - Use in production pipeline

Deliverables:
- VibeVoiceASRService.swift
- VibeVoiceASRServiceTests.swift
- Updated ASRServiceFactory
- Documentation of VibeVoice integration notes
```

---

### Prompt 15: Real NLLB-200 CoreML Translation Integration

```text
Building on the mock translation, implement the real NLLB-200 CoreML integration.

Context: NLLB-200 (distilled) converted to CoreML provides on-device Japanese to English translation optimized for Apple devices.

Requirements:
1. Research and setup:
   - Obtain or convert NLLB-200 distilled to CoreML format
   - Understand model input/output specifications
   - Add any required tokenization dependencies

2. Create `NLLBTranslationService` implementing TranslationServiceProtocol:
   - loadModel():
     - Get model path from ModelManager
     - Load CoreML model (MLModel)
     - Configure for ANE/GPU acceleration
     - Throw modelMissing if not downloaded
     - Throw coreMLLoadFailed on initialization error
   
   - translate(_ text:, from:, to:):
     - Tokenize input text
     - Run CoreML inference
     - Decode output tokens
     - Return TranslationResult with confidence

3. CoreML optimization:
   - Use MLComputeUnits.all for best performance
   - Batch multiple short texts if possible
   - Cache model instance

4. Tokenization:
   - Implement or integrate SentencePiece tokenizer
   - Handle Japanese text encoding properly
   - Manage vocabulary files

5. Performance mode:
   - Smaller/quantized model variant
   - Reduced beam search (if applicable)
   - Lower quality but faster

6. Write integration tests:
   - Test model loading from disk
   - Test Japanese to English translation
   - Test various text lengths
   - Test error handling
   - Test performance metrics

7. Integration:
   - Register with TranslationServiceFactory
   - Use in production pipeline

Deliverables:
- NLLBTranslationService.swift
- NLLBTokenizer.swift (if needed)
- NLLBTranslationServiceTests.swift
- Updated TranslationServiceFactory
```

---

## Phase 4: UI Components

### Prompt 16: Menu Bar Implementation

```text
Building on the AI services, implement the complete menu bar functionality.

Context: VibeCaption is primarily a menu bar app with specific menu items for controlling the overlay, settings, and wizard.

Requirements:
1. Create `MenuBarController` in /Sources/UI/MenuBar/:
   - Properties:
     - statusItem: NSStatusItem
     - currentState: AppState (observed from AppStateManager)
   
   - Menu items:
     - Show/Hide Overlay (toggles, updates text based on state)
     - Separator
     - Start/Stop (mirrors overlay Space toggle, updates text)
     - Separator
     - Open Settings…
     - Run Setup Wizard…
     - Open Transcript Folder
     - Separator
     - Quit

2. Menu bar icon:
   - Use SF Symbol "captions.bubble"
   - Different states:
     - Normal: default color
     - Listening: accent color or filled variant
     - Paused: dimmed

3. Menu item states:
   - Start/Stop updates text and icon dynamically
   - Disabled states when appropriate (e.g., Start disabled if models not loaded)

4. Actions:
   - Show/Hide Overlay -> toggle overlay window
   - Start/Stop -> call AppStateManager.toggleListening()
   - Open Settings -> present settings window
   - Run Setup Wizard -> present wizard window
   - Open Transcript Folder -> NSWorkspace.open(transcriptPath)
   - Quit -> NSApplication.terminate()

5. Write unit tests:
   - Test menu item text updates with state changes
   - Test menu item enabled/disabled states
   - Test icon changes with state
   - Test all menu actions are wired correctly

6. Integration:
   - Wire to AppStateManager
   - Wire to SettingsManager for transcript path
   - Log menu actions for debugging

Deliverables:
- MenuBarController.swift
- Updated main app to use MenuBarController
- MenuBarControllerTests.swift
```

---

### Prompt 17: Floating Overlay Window Foundation

```text
Building on the menu bar, implement the floating overlay window foundation.

Context: The overlay is an always-on-top, draggable, resizable window that displays captions. It's click-through when not focused.

Requirements:
1. Create `OverlayWindow` (NSWindow subclass) in /Sources/UI/Overlay/:
   - Window characteristics:
     - Always on top (NSWindow.Level.floating)
     - Borderless, with rounded corners
     - Draggable from anywhere
     - Resizable (with min/max constraints)
     - Semi-transparent background
   
   - Click-through behavior:
     - When not focused: clicks pass through
     - Click to focus: becomes interactive
     - Implement via ignoresMouseEvents + hit testing

2. Create `OverlayViewModel` as ObservableObject:
   - Published properties:
     - isVisible: Bool
     - position: CGPoint (persisted)
     - size: CGSize (persisted)
     - isFocused: Bool
   
   - Methods:
     - show()
     - hide()
     - toggleVisibility()

3. Position and size persistence:
   - Save position/size to UserDefaults on change
   - Restore on app launch
   - Handle screen changes (ensure visible on current screen)

4. Window management:
   - Proper focus handling
   - Escape key to unfocus
   - Track focus state changes

5. Write unit tests:
   - Test window level is floating
   - Test position/size persistence
   - Test click-through when not focused
   - Test focus state changes
   - Test visibility toggle

6. Integration:
   - Wire Show/Hide menu item to OverlayViewModel
   - Log visibility changes

Deliverables:
- OverlayWindow.swift
- OverlayViewModel.swift
- OverlayWindowTests.swift
```

---

### Prompt 18: Overlay Caption Display

```text
Building on the overlay window, implement the caption display content.

Context: The overlay shows Japanese text first, then English below, with speaker badges and timestamps. It's a scrollable transcript.

Requirements:
1. Create `OverlayContentView` (SwiftUI) in /Sources/UI/Overlay/:
   - Display:
     - Scrollable list of caption blocks
     - Default visible lines: 10 (configurable)
     - Auto-scroll to latest
   
   - Per block:
     - Speaker badge (small, above block): "Speaker 1"
     - Timestamp (wall-clock): "14:03:12"
     - Japanese text (top line)
     - English text (below, italicized or different style)
     - Low confidence indicator (subtle styling)

2. Create `CaptionBlockView` for individual blocks:
   - Speaker badge styling
   - Timestamp styling
   - Japanese text styling
   - English text styling (or placeholder if not yet translated)
   - Confidence-based opacity or border

3. Styling from settings:
   - Font size from SettingsManager (small/medium/large)
   - Max width from SettingsManager
   - Dark/light mode support

4. Animations:
   - Smooth scroll to new content
   - Fade in for new blocks
   - Translation text appears with subtle animation

5. Write unit tests:
   - Test block renders all components
   - Test font size updates from settings
   - Test scroll behavior
   - Test low confidence styling
   - Test missing English text placeholder

6. Integration:
   - Wire to TranscriptManager for blocks
   - Update in real-time as blocks added

Deliverables:
- OverlayContentView.swift
- CaptionBlockView.swift
- OverlayContentViewTests.swift (UI tests)
```

---

### Prompt 19: Overlay Controls & Status

```text
Building on caption display, implement overlay controls and status indicators.

Context: The overlay has a top-left cluster with status dot and pause button. Status shows Idle/Listening/Translating.

Requirements:
1. Create `OverlayControlsView` (SwiftUI):
   - Top-left cluster:
     - Status dot (colored circle)
       - Idle: gray
       - Listening: green (pulsing animation)
       - Translating: blue
       - Paused: yellow
     - Tooltip on hover showing state name
     - Pause button (icon only)
   
   - Idle state display:
     - Show hint text: "Press Space to translate"
     - Auto-hide after 30 seconds of inactivity

2. Create `StatusDotView`:
   - Animated pulsing for Listening state
   - Color based on AppState
   - Tooltip using .help() modifier

3. Add Space key handling:
   - Only when overlay is focused
   - Calls AppStateManager.toggleListening()
   - Visual feedback on keypress

4. Pause functionality:
   - Pause button visible in Listening/Translating states
   - Shows "Paused" label when paused
   - Calls AppStateManager.pause/resume

5. Auto-hide logic:
   - Timer resets on new captions
   - After 30s of no activity: hide overlay
   - Configurable via SettingsManager

6. Write unit tests:
   - Test status dot colors for each state
   - Test pause button visibility states
   - Test Space key triggers toggle
   - Test auto-hide timer logic
   - Test "Paused" label shows when paused

7. Integration:
   - Wire to AppStateManager
   - Connect to OverlayWindow for visibility

Deliverables:
- OverlayControlsView.swift
- StatusDotView.swift
- Updated OverlayContentView with controls
- OverlayControlsTests.swift
```

---

### Prompt 20: Clear Captions Action

```text
Building on overlay controls, implement the clear captions action with popup.

Context: Clear captions is the most important quick action. It shows a popup asking "Clear display only" or "Clear + discard".

Requirements:
1. Add clear button to OverlayControlsView:
   - Clear icon (SF Symbol "trash" or "xmark.circle")
   - Positioned appropriately in control cluster
   - Visible when there are captions to clear

2. Create `ClearCaptionsPopup` (SwiftUI):
   - Small modal popup (not full sheet)
   - Two buttons:
     - "Clear display only" - clears UI, keeps for file
     - "Clear + discard" - removes permanently
   - Cancel option (clicking outside or Escape)
   - Styled as floating overlay-style popup

3. Actions:
   - "Clear display only":
     - Call TranscriptManager.clearDisplay()
     - Close popup
     - Captions cleared from UI
     - Text still saved to file at session end
   
   - "Clear + discard":
     - Call TranscriptManager.clearAndDiscard()
     - Close popup
     - Cleared portion won't be in saved file

4. Popup behavior:
   - Must show every time (no shortcuts to skip)
   - Positioned near clear button
   - Keyboard accessible

5. Write unit tests:
   - Test popup appears on clear button click
   - Test "Clear display only" calls correct method
   - Test "Clear + discard" calls correct method
   - Test popup dismissal
   - Test clear button visibility based on content

6. Integration:
   - Wire to TranscriptManager
   - Test end-to-end clear behavior

Deliverables:
- ClearCaptionsPopup.swift
- Updated OverlayControlsView
- ClearCaptionsTests.swift
```

---

### Prompt 21: Settings Panel

```text
Building on overlay features, implement the settings panel.

Context: Settings is a separate window accessible from the menu bar with sections for audio, overlay, models, diagnostics, and updates.

Requirements:
1. Create `SettingsWindow` and `SettingsView` (SwiftUI):
   - Tabbed interface with sections:
     - General
     - Audio
     - Overlay
     - Models
     - Diagnostics
     - Updates

2. General tab:
   - Performance mode toggle
   - Noise suppression toggle

3. Audio tab:
   - Input device picker (from AudioDeviceManager)
   - Monitoring output device picker
   - Audio level meter (real-time visualization)
   - Show BlackHole status (installed/not installed)

4. Overlay tab:
   - Font size picker (Small/Medium/Large)
   - Max width slider (320-800px)
   - Auto-hide duration (15s/30s/60s/Never)
   - Preview of current settings

5. Models tab:
   - List of required models
   - Per model: name, version, status, size
   - Download/Update buttons
   - Disk usage total
   - Model storage path display

6. Diagnostics tab:
   - Selected input/output devices
   - Audio frames arriving (yes/no + meter)
   - Model loaded status (ASR, Translation)
   - Current CPU/RAM usage
   - Pipeline state

7. Updates tab:
   - Auto-update enabled toggle
   - Check for updates button
   - Current version display
   - Model update prompts (only here, not proactive)

8. Write unit tests:
   - Test settings binding to SettingsManager
   - Test device picker updates settings
   - Test model list displays correctly
   - Test diagnostics shows real data

Deliverables:
- SettingsWindow.swift
- SettingsView.swift (with all tabs)
- Subviews for each tab
- SettingsViewTests.swift
```

---

### Prompt 22: Setup Wizard

```text
Building on the settings panel, implement the setup wizard.

Context: The wizard runs on first launch and guides users through BlackHole installation and audio routing configuration.

Requirements:
1. Create `SetupWizardWindow` and `SetupWizardView` (SwiftUI):
   - Multi-step wizard flow
   - Progress indicator
   - Back/Next/Finish buttons
   - Can be reopened from menu bar

2. Step 1: Welcome
   - Brief app description
   - What the wizard will help with
   - "Get Started" button

3. Step 2: BlackHole Detection
   - Check if BlackHole is installed (AudioDeviceManager.isBlackHoleInstalled())
   - If installed: show green checkmark, explain what it is
   - If not installed:
     - Explain why it's needed
     - Link to BlackHole GitHub releases
     - Instructions for installation
     - "Check Again" button
     - Cannot proceed until installed

4. Step 3: Audio Routing Instructions
   - Explain routing concept
   - Instructions for common apps:
     - Zoom: Audio settings -> Output device = BlackHole
     - Chrome: macOS system audio preferences
     - Teams: Similar instructions
   - Screenshots or diagrams if possible
   - Generic: "Set app's output to BlackHole"

5. Step 4: Test Audio
   - Real-time level meter
   - Device selectors (input = BlackHole, output = speakers)
   - "Play test sound" button (from system)
   - Success indicator when audio detected
   - Cannot proceed until audio confirmed

6. Step 5: Completion
   - Summary of configuration
   - "Open Overlay" button
   - "Finish" button

7. First-launch detection:
   - Check UserDefaults for wizard completed flag
   - Show wizard on first launch
   - Accessible from menu for re-running

8. Write unit tests:
   - Test step navigation
   - Test BlackHole detection display
   - Test device selection persists
   - Test completion flag is set
   - Test wizard can be reopened

Deliverables:
- SetupWizardWindow.swift
- SetupWizardView.swift
- Subviews for each step
- SetupWizardTests.swift
```

---

## Phase 5: Integration & Polish

### Prompt 23: Full Pipeline Integration

```text
Building on all components, integrate the complete audio-to-caption pipeline.

Context: All individual components exist. Now wire them together into a cohesive pipeline that processes audio and produces captions.

Requirements:
1. Create `CaptionPipeline` in /Sources/Core/:
   - Orchestrates the full flow:
     AudioCapture -> Preprocessing -> VAD -> Segmenter -> ASR -> Translation -> TranscriptManager
   
   - Properties:
     - isRunning: Bool
     - currentState: PipelineState (enum)
     - statistics: PipelineStatistics (latency, throughput)
   
   - Methods:
     - start() async throws
     - stop()
     - pause()
     - resume()

2. Pipeline flow:
   - AudioCaptureEngine provides buffers
   - AudioPreprocessor cleans audio
   - VoiceActivityDetector adds VAD results
   - AudioSegmenter creates segments
   - ASR service transcribes (async)
   - When ASR complete: update TranscriptManager with Japanese
   - Enqueue for translation (async, parallel)
   - When translation complete: update block with English
   - UI updates automatically via TranscriptManager

3. Concurrency:
   - Use Swift async/await
   - ASR and translation can run in parallel
   - Proper task cancellation on stop/pause
   - Handle backpressure (queue limits)

4. State synchronization:
   - Pipeline state syncs with AppStateManager
   - Proper cleanup on errors
   - Resume from pause correctly

5. Write integration tests:
   - Test full pipeline with mock ASR/translation
   - Test Japanese appears before English
   - Test pause stops processing
   - Test stop saves transcript
   - Test error propagation

6. Integration:
   - Wire Space key toggle to pipeline
   - Wire menu bar Start/Stop to pipeline
   - Wire overlay visibility to pipeline state

Deliverables:
- CaptionPipeline.swift
- PipelineStatistics.swift
- CaptionPipelineTests.swift (integration)
```

---

### Prompt 24: Transcript File Saving

```text
Building on the pipeline, implement automatic transcript file saving.

Context: Transcripts are saved automatically at the end of each session (when user stops listening) to a per-session file.

Requirements:
1. Extend `TranscriptManager`:
   - Automatic save on session end
   - File path from SettingsManager
   - Filename: YYYY-MM-DD_HHMM_VibeCaption.txt
   
2. File format (per spec):
   ```
   [14:03:12] (Speaker 1)
   こんにちは、今日の会議を始めましょう。
   Hello, let's start today's meeting.
   
   [14:03:18] (Speaker 2)
   はい、よろしくお願いします。
   Yes, thank you for having me.
   
   [14:03:25] [PAUSED]
   
   [14:05:30] (Speaker 1)
   続けましょう。
   Let's continue.
   ```

3. Save triggers:
   - User stops listening (Space toggle off)
   - App quits while session active
   - Overlay hidden while session active
   - Error causes pipeline stop

4. Edge cases:
   - Empty session (no blocks): don't save file
   - Very long session: periodic autosave?
   - Clear + discard: don't include discarded content
   - Disk full: show error

5. "Open Transcript Folder" menu item:
   - Opens Finder at transcript directory
   - Creates directory if doesn't exist

6. Write unit tests:
   - Test file is created on session end
   - Test filename format is correct
   - Test file content matches spec format
   - Test empty session doesn't create file
   - Test clear+discard removes content
   - Test directory creation

7. Integration:
   - Wire to pipeline stop events
   - Wire to app lifecycle (quit)
   - Wire to menu bar "Open Transcript Folder"

Deliverables:
- Updated TranscriptManager with file saving
- TranscriptFileTests.swift
- Menu bar integration
```

---

### Prompt 25: Auto-Update with Sparkle

```text
Building on transcript saving, implement auto-update functionality.

Context: VibeCaption uses Sparkle for auto-updates. The app is internally distributed, signed, and notarized.

Requirements:
1. Add Sparkle dependency:
   - Via Swift Package Manager or CocoaPods
   - Latest Sparkle 2.x version

2. Configure Sparkle:
   - Appcast URL (placeholder, internal server)
   - Enable automatic update checks
   - Configure update frequency
   - Handle signing/notarization requirements

3. Update UI in Settings:
   - Check for Updates button
   - Auto-update toggle
   - Last checked timestamp
   - Current version display

4. Update notifications:
   - Sparkle handles UI for available updates
   - User can postpone
   - Force update for critical security fixes (configurable)

5. Model updates (separate from app updates):
   - Check for model updates in ModelManager
   - Only show in Settings (not proactive per spec)
   - Version comparison logic
   - Download new models when user triggers

6. Build configuration:
   - Add code signing settings
   - Notarization script/configuration
   - Distribution profile setup

7. Write unit tests:
   - Test update check triggers correctly
   - Test auto-update setting persists
   - Test model update detection
   - Test version comparison logic

8. Integration:
   - Initialize Sparkle on app launch
   - Wire Settings UI to Sparkle
   - Wire model updates to ModelManager

Deliverables:
- Sparkle integration in AppDelegate/main
- Updated Settings update tab
- UpdateManager.swift (wraps Sparkle)
- UpdateManagerTests.swift
- Build/signing configuration documentation
```

---

### Prompt 26: Error Modals & Recovery Flows

```text
Building on auto-update, implement the error modal flows with recovery actions.

Context: Error conditions should show modal dialogs with "Fix Now" buttons that guide users to resolution.

Requirements:
1. Enhance `ErrorModalView`:
   - Different styles for different error severities
   - Clear error description
   - Recovery suggestion
   - Action buttons:
     - "Fix Now" / recovery action button
     - "Open Diagnostics" where applicable
     - "Dismiss"

2. Recovery action implementations:
   - openSetupWizard:
     - Opens wizard to appropriate step (audio routing for audio errors)
   - openModelManagement:
     - Opens Settings to Models tab
   - openDiagnostics:
     - Opens Settings to Diagnostics tab
   - retry:
     - Re-attempts failed operation

3. Error scenarios and flows:
   - No BlackHole: Wizard step 2
   - No audio frames: Wizard step 4 (test audio)
   - Model missing: Settings Models tab
   - ASR/Translation error: Diagnostics
   - Out of memory: Show usage info

4. Modal presentation:
   - Sheet style on overlay window
   - Or separate window if overlay hidden
   - Only one modal at a time
   - Escape to dismiss

5. Error state management:
   - Clear error after successful recovery
   - Prevent duplicate popups
   - Log all errors for diagnostics

6. Write unit tests:
   - Test each error shows correct modal
   - Test recovery actions navigate correctly
   - Test modal dismissal
   - Test error clearing after recovery
   - Test no duplicate modals

7. Integration:
   - Wire ErrorHandler to UI
   - Test error flows end-to-end
   - Ensure recovery actually resolves issues

Deliverables:
- Enhanced ErrorModalView
- RecoveryActionHandler.swift
- ErrorFlowTests.swift
```

---

### Prompt 27: Final Polish & End-to-End Testing

```text
Building on all features, complete final polish and comprehensive testing.

Context: All core features are implemented. Now ensure quality, performance, and a polished user experience.

Requirements:
1. UI Polish:
   - Consistent styling across all views
   - Proper animations and transitions
   - Dark mode / light mode support
   - Accessibility (VoiceOver labels, keyboard navigation)
   - App icon design

2. Performance optimization:
   - Profile memory usage during 60+ minute session
   - Optimize any memory leaks
   - Profile CPU usage
   - Ensure < 30% CPU on M1 during normal use
   - Performance mode actually reduces resource usage

3. End-to-end test suite:
   - Record sample Japanese meeting audio
   - Test full flow: launch -> setup -> listen -> captions -> save
   - Verify:
     - Japanese appears first
     - English follows
     - Speaker labels present
     - Timestamps correct
     - Transcript file saved correctly
   - Test with noisy audio
   - Test with multiple speakers

4. UI tests:
   - Overlay focus/unfocus behavior
   - Space key toggles correctly
   - Menu bar items all work
   - Settings all persist
   - Wizard completes successfully

5. Edge case testing:
   - Device disconnection during capture
   - Model unloaded mid-transcription
   - Network loss during model download
   - Disk full during save
   - Extended sessions (2+ hours)

6. Documentation:
   - README with setup instructions
   - User guide (brief)
   - Developer documentation
   - Known issues / limitations

7. Final fixes:
   - Address any bugs found in testing
   - Performance optimizations as needed
   - UX improvements based on testing

Deliverables:
- Polished, production-ready app
- Comprehensive test suite
- Documentation
- Final build ready for distribution
```

---

## Appendix: Implementation Notes

### A. Architecture Decisions

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Noise suppression | Apple Voice Processing I/O | Native, optimized, toggleable |
| VAD | Energy-based + ZCR | Simple, CPU efficient, good for Japanese |
| Chunking | 0.5-10s segments | Balance latency vs accuracy |
| State management | ObservableObject | SwiftUI native, reactive |
| Concurrency | Swift async/await | Modern, structured concurrency |
| Persistence | UserDefaults + Files | Simple, reliable |
| Updates | Sparkle | Industry standard for macOS |

### B. Model Considerations

| Model | Size | Notes |
|-------|------|-------|
| VibeVoice-ASR | ~500MB-2GB | Japanese specialized, diarization |
| NLLB-200 distilled | ~600MB-1.2GB | CoreML optimized, ANE acceleration |

### C. Testing Strategy

1. **Unit tests**: Core logic, formatting, state transitions
2. **Integration tests**: Service interactions, device handling
3. **E2E tests**: Full pipeline with recorded audio
4. **UI tests**: User interactions, accessibility
5. **Performance tests**: Memory, CPU profiling

### D. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| VibeVoice integration complexity | Mock early, integrate late |
| CoreML model conversion | Test simple model first |
| Audio routing confusion | Strong wizard guidance |
| Memory leaks | Profile early and often |
| Performance issues | Performance mode fallback |

---

## Summary

This prompt plan provides **27 incremental prompts** organized into **5 phases** that build a complete VibeCaption application:

1. **Foundation** (5 prompts): Project setup, state machine, settings, transcripts, errors
2. **Audio Pipeline** (5 prompts): Device detection, capture, monitoring, preprocessing, VAD
3. **AI Services** (5 prompts): Model management, ASR interface/mock/real, translation interface/mock/real
4. **UI Components** (7 prompts): Menu bar, overlay window, captions, controls, clear action, settings, wizard
5. **Integration & Polish** (5 prompts): Pipeline integration, file saving, updates, error flows, testing

Each prompt is designed to:
- Build on previous work
- Include tests from the start
- Be small enough for focused implementation
- Be large enough to make meaningful progress
- Wire into the existing codebase (no orphaned code)

Total estimated implementation time: **80-120 hours** for an experienced macOS/Swift developer.
