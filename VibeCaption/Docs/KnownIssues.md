# Known Issues and Limitations

## Functional Limitations
- Setup wizard audio-test step currently simulates meter activity for UI verification; full hardware-meter wiring should be completed for production calibration workflows.
- Real-world speaker diarization quality depends on upstream ASR model capabilities.
- Model downloading assumes a valid checksum in model catalog metadata.

## Operational Notes
- Menu-bar and overlay tests are primarily behavior/unit style, not full XCUI automation.
- Physical device disconnect/reconnect scenarios still require manual hardware validation in addition to automated tests.
- Long-session validation is automated via sampling script, but thermal and battery behavior should still be manually reviewed on target hardware.

## Swift Warnings (Non-blocking)
- No known Swift compiler warnings are currently emitted in the default Debug test build configuration.
