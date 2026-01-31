# Whisper Integration Notes

## Overview
VibeCaption integrates `whisper.cpp` via the `SwiftWhisper` wrapper to provide high-performance, on-device speech recognition.

## Dependencies
- **SwiftWhisper**: A Swift wrapper for OpenAI's Whisper model port `whisper.cpp`.
  - URL: `https://github.com/exPHAT/SwiftWhisper.git`
  - Version: Up to Next Major (1.0.0 < 2.0.0)

## Model Management
- **Format**: The service uses `ggml` quantized models (e.g., `ggml-base.bin`).
- **Configuration**: `model-catalog.json` defines the download URL and checksum.
- **Storage**: `ModelManager` handles downloading and storing models in the app's support directory.
- **Loading**: `WhisperASRService.loadModel()` loads the model from disk into memory. This is a potentially heavy operation and should be done during the "Initializing" state, not during active recording if possible.

## Implementation Details
- **Threading**: `transcribe(_:)` runs on a background actor (`WhisperASRService`).
- **Audio Format**: Expects 16kHz PCM Float32 audio samples.
- **Language**: Currently hardcoded to Japanese (`.japanese`).
- **Diarization**: Not supported in the current version (speaker ID is always `nil`).

## Known Issues / Limitations
- **Model Checksum**: The checksum in `model-catalog.json` might need manual update if the upstream model file changes.
- **Memory Usage**: `ggml-base.bin` requires ~200-300MB of RAM.
- **Concurrency**: The current `SwiftWhisper` wrapper usage in the service assumes serial transcription requests.
