//
//  AudioCaptureEngineTests.swift
//  VibeCaptionTests
//
//  Unit tests for AudioCaptureEngine.
//

import XCTest
import AVFoundation
import Combine
import CoreAudio
@testable import VibeCaption

// MARK: - Mock AudioCaptureEngine

/// Mock implementation for testing AudioCaptureEngine protocol.
final class MockAudioCaptureEngine: AudioCaptureEngineProtocol {
    
    @Published var audioLevel: Float = 0.0
    var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    
    private(set) var isCapturing: Bool = false
    private(set) var currentInputDevice: AudioDevice?
    
    // Monitoring properties
    private(set) var monitoringEnabled: Bool = false
    private(set) var monitoringVolume: Float = 1.0
    var currentMonitoringDevice: AudioDevice?
    
    var configureCallCount = 0
    var startCaptureCallCount = 0
    var stopCaptureCallCount = 0
    var setMonitoringOutputCallCount = 0
    var enableMonitoringCallCount = 0
    var setMonitoringVolumeCallCount = 0
    var setNoiseSuppressionCallCount = 0
    var audioCallback: ((AVAudioPCMBuffer) -> Void)?
    
    var shouldThrowOnConfigure = false
    var shouldThrowOnStart = false
    var shouldThrowOnMonitoring = false
    var configureError: VibeCaptionError?
    var startError: VibeCaptionError?
    var monitoringError: VibeCaptionError?
    
    func configure(inputDevice: AudioDevice) throws {
        configureCallCount += 1
        
        if shouldThrowOnConfigure, let error = configureError {
            throw error
        }
        
        currentInputDevice = inputDevice
    }
    
    func startCapture() throws {
        startCaptureCallCount += 1
        
        if shouldThrowOnStart, let error = startError {
            throw error
        }
        
        isCapturing = true
    }
    
    func stopCapture() {
        stopCaptureCallCount += 1
        isCapturing = false
        monitoringEnabled = false
    }
    
    func setAudioCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void) {
        audioCallback = callback
    }
    
    // MARK: - Monitoring Methods
    
    func setMonitoringOutput(device: AudioDevice?) throws {
        setMonitoringOutputCallCount += 1
        
        // Check for feedback loop
        if let device = device, let inputDevice = currentInputDevice {
            if device.uid == inputDevice.uid {
                throw VibeCaptionError.feedbackLoopDetected(
                    inputDevice: inputDevice.name,
                    outputDevice: device.name
                )
            }
        }
        
        // Check if output device
        if let device = device, !device.isOutput {
            throw VibeCaptionError.audioRoutingFailed(
                device: device.name,
                reason: "Device does not support audio output"
            )
        }
        
        currentMonitoringDevice = device
    }
    
    func enableMonitoring(_ enabled: Bool) throws {
        enableMonitoringCallCount += 1
        
        if shouldThrowOnMonitoring, let error = monitoringError {
            throw error
        }
        
        // Check for feedback loop
        if enabled,
           let inputDevice = currentInputDevice,
           let outputDevice = currentMonitoringDevice,
           inputDevice.uid == outputDevice.uid {
            throw VibeCaptionError.feedbackLoopDetected(
                inputDevice: inputDevice.name,
                outputDevice: outputDevice.name
            )
        }
        
        monitoringEnabled = enabled
    }
    
    func setMonitoringVolume(_ volume: Float) {
        setMonitoringVolumeCallCount += 1
        monitoringVolume = max(0.0, min(1.0, volume))
    }
    
    /// Simulate receiving audio at a given level.
    func simulateAudioLevel(_ level: Float) {
        audioLevel = level
    }
    
    // MARK: - Feature Control
    
    func setNoiseSuppression(_ enabled: Bool) {
        setNoiseSuppressionCallCount += 1
    }
}

// MARK: - AudioCaptureEngine Tests

final class AudioCaptureEngineTests: XCTestCase {
    
    var sut: AudioCaptureEngine!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AudioCaptureEngine(ringBufferCapacity: 1000)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut?.stopCapture()
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Test Fixtures
    
    private func makeDevice(
        deviceID: AudioDeviceID = 42,
        uid: String = "test-device-uid",
        name: String = "Test Device",
        isInput: Bool = true,
        isOutput: Bool = false,
        sampleRate: Double = 48000.0,
        channelCount: Int = 2
    ) -> AudioDevice {
        AudioDevice(
            deviceID: deviceID,
            uid: uid,
            name: name,
            isInput: isInput,
            isOutput: isOutput,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
    }
    
    // MARK: - Initialization Tests
    
    /// Test engine initializes with correct defaults.
    func testInitializationDefaults() {
        XCTAssertFalse(sut.isCapturing)
        XCTAssertNil(sut.currentInputDevice)
        XCTAssertEqual(sut.audioLevel, 0.0)
    }
    
    /// Test ring buffer is created with specified capacity.
    func testRingBufferCapacity() {
        let engine = AudioCaptureEngine(ringBufferCapacity: 5000)
        XCTAssertEqual(engine.ringBuffer.capacity, 5000)
    }
    
    /// Test target sample rate constant.
    func testTargetSampleRate() {
        XCTAssertEqual(AudioCaptureEngine.targetSampleRate, 16000)
    }
    
    // MARK: - Configuration Tests
    
    /// Test configuration with non-input device throws error.
    func testConfigureWithOutputOnlyDeviceThrows() {
        let outputDevice = makeDevice(isInput: false, isOutput: true)
        
        XCTAssertThrowsError(try sut.configure(inputDevice: outputDevice)) { error in
            guard let vibeCaptionError = error as? VibeCaptionError else {
                XCTFail("Expected VibeCaptionError")
                return
            }
            
            if case .audioRoutingFailed(let device, let reason) = vibeCaptionError {
                XCTAssertEqual(device, outputDevice.name)
                XCTAssertTrue(reason.contains("input"))
            } else {
                XCTFail("Expected audioRoutingFailed error")
            }
        }
    }
    
    /// Test configuration stores current device.
    func testConfigureStoresDevice() {
        // Note: This test may fail on CI without audio hardware.
        // We test the mock instead for reliable CI testing.
        let mock = MockAudioCaptureEngine()
        let device = makeDevice(name: "BlackHole 2ch")
        
        try? mock.configure(inputDevice: device)
        
        XCTAssertEqual(mock.currentInputDevice?.name, "BlackHole 2ch")
        XCTAssertEqual(mock.configureCallCount, 1)
    }
    
    // MARK: - Capture Control Tests (Mock)
    
    /// Test start capture changes state.
    func testStartCaptureChangesState() {
        let mock = MockAudioCaptureEngine()
        let device = makeDevice()
        
        try? mock.configure(inputDevice: device)
        try? mock.startCapture()
        
        XCTAssertTrue(mock.isCapturing)
    }
    
    /// Test stop capture changes state.
    func testStopCaptureChangesState() {
        let mock = MockAudioCaptureEngine()
        let device = makeDevice()
        
        try? mock.configure(inputDevice: device)
        try? mock.startCapture()
        mock.stopCapture()
        
        XCTAssertFalse(mock.isCapturing)
    }
    
    /// Test start without configure throws.
    func testStartWithoutConfigureThrows() {
        // Real engine should throw when starting without configuration
        XCTAssertThrowsError(try sut.startCapture()) { error in
            guard let vibeCaptionError = error as? VibeCaptionError else {
                XCTFail("Expected VibeCaptionError")
                return
            }
            
            if case .audioRoutingFailed(_, let reason) = vibeCaptionError {
                XCTAssertTrue(reason.contains("No input device configured"))
            } else {
                XCTFail("Expected audioRoutingFailed error")
            }
        }
    }
    
    /// Test mock throws configured error.
    func testMockThrowsConfiguredError() {
        let mock = MockAudioCaptureEngine()
        mock.shouldThrowOnConfigure = true
        mock.configureError = .audioRoutingFailed(device: "Test", reason: "Test error")
        
        let device = makeDevice()
        
        XCTAssertThrowsError(try mock.configure(inputDevice: device))
    }
    
    // MARK: - Audio Callback Tests
    
    /// Test callback is stored.
    func testCallbackIsStored() {
        let mock = MockAudioCaptureEngine()
        var callbackInvoked = false
        
        mock.setAudioCallback { _ in
            callbackInvoked = true
        }
        
        XCTAssertNotNil(mock.audioCallback)
    }
    
    // MARK: - Audio Level Tests
    
    /// Test audio level is published.
    func testAudioLevelIsPublished() {
        let expectation = expectation(description: "Audio level published")
        let mock = MockAudioCaptureEngine()
        var receivedLevel: Float = 0.0
        
        mock.$audioLevel
            .dropFirst()
            .sink { level in
                receivedLevel = level
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        mock.simulateAudioLevel(0.75)
        
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedLevel, 0.75, accuracy: 0.001)
    }
    
    // MARK: - RMS Calculation Tests
    
    /// Test RMS calculation with known values.
    func testRMSCalculationWithKnownValues() {
        // RMS of [1, 1, 1, 1] = sqrt((1+1+1+1)/4) = 1.0
        let uniformSamples: [Float] = [1.0, 1.0, 1.0, 1.0]
        let rms = AudioCaptureEngine.calculateRMS(samples: uniformSamples)
        XCTAssertEqual(rms, 1.0, accuracy: 0.0001)
    }
    
    /// Test RMS calculation with zero values.
    func testRMSCalculationWithZeroValues() {
        let zeroSamples: [Float] = [0.0, 0.0, 0.0, 0.0]
        let rms = AudioCaptureEngine.calculateRMS(samples: zeroSamples)
        XCTAssertEqual(rms, 0.0, accuracy: 0.0001)
    }
    
    /// Test RMS calculation with mixed values.
    func testRMSCalculationWithMixedValues() {
        // RMS of [0.5, -0.5, 0.5, -0.5] = sqrt((0.25+0.25+0.25+0.25)/4) = 0.5
        let mixedSamples: [Float] = [0.5, -0.5, 0.5, -0.5]
        let rms = AudioCaptureEngine.calculateRMS(samples: mixedSamples)
        XCTAssertEqual(rms, 0.5, accuracy: 0.0001)
    }
    
    /// Test RMS calculation with single sample.
    func testRMSCalculationWithSingleSample() {
        let singleSample: [Float] = [0.8]
        let rms = AudioCaptureEngine.calculateRMS(samples: singleSample)
        XCTAssertEqual(rms, 0.8, accuracy: 0.0001)
    }
    
    /// Test RMS calculation with empty array.
    func testRMSCalculationWithEmptyArray() {
        let emptySamples: [Float] = []
        let rms = AudioCaptureEngine.calculateRMS(samples: emptySamples)
        XCTAssertEqual(rms, 0.0, accuracy: 0.0001)
    }
    
    /// Test RMS calculation with realistic audio values.
    func testRMSCalculationWithRealisticValues() {
        // Simulate typical audio: varying between -0.3 and 0.3
        let samples: [Float] = [0.1, -0.2, 0.3, -0.1, 0.2, -0.3, 0.15, -0.15]
        let rms = AudioCaptureEngine.calculateRMS(samples: samples)
        
        // Manual calculation:
        // Sum of squares = 0.01 + 0.04 + 0.09 + 0.01 + 0.04 + 0.09 + 0.0225 + 0.0225 = 0.325
        // RMS = sqrt(0.325 / 8) = sqrt(0.040625) ≈ 0.2016
        XCTAssertEqual(rms, 0.2016, accuracy: 0.01)
    }
    
    // MARK: - Protocol Conformance Tests
    
    /// Test real engine conforms to protocol.
    func testRealEngineConformsToProtocol() {
        let engine: AudioCaptureEngineProtocol = AudioCaptureEngine()
        
        XCTAssertFalse(engine.isCapturing)
        XCTAssertNil(engine.currentInputDevice)
        XCTAssertEqual(engine.audioLevel, 0.0)
    }
    
    /// Test mock engine conforms to protocol.
    func testMockEngineConformsToProtocol() {
        let mock: AudioCaptureEngineProtocol = MockAudioCaptureEngine()
        
        XCTAssertFalse(mock.isCapturing)
        XCTAssertNil(mock.currentInputDevice)
    }
    
    // MARK: - Edge Case Tests
    
    /// Test double start does nothing.
    func testDoubleStartDoesNothing() {
        let mock = MockAudioCaptureEngine()
        let device = makeDevice()
        
        try? mock.configure(inputDevice: device)
        try? mock.startCapture()
        try? mock.startCapture()
        
        XCTAssertEqual(mock.startCaptureCallCount, 2)
        XCTAssertTrue(mock.isCapturing)
    }
    
    /// Test stop when not capturing is safe.
    func testStopWhenNotCapturingIsSafe() {
        let mock = MockAudioCaptureEngine()
        mock.stopCapture()
        
        XCTAssertEqual(mock.stopCaptureCallCount, 1)
        XCTAssertFalse(mock.isCapturing)
    }
    
    // MARK: - Monitoring Tests
    
    /// Test monitoring defaults to disabled.
    func testMonitoringDefaultsToDisabled() {
        XCTAssertFalse(sut.monitoringEnabled)
        XCTAssertNil(sut.currentMonitoringDevice)
    }
    
    /// Test monitoring volume defaults to 1.0.
    func testMonitoringVolumeDefaults() {
        XCTAssertEqual(sut.monitoringVolume, 1.0, accuracy: 0.001)
    }
    
    /// Test monitoring can be enabled.
    func testMonitoringCanBeEnabled() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "input-uid", isInput: true, isOutput: false)
        let outputDevice = makeDevice(uid: "output-uid", isInput: false, isOutput: true)
        
        try? mock.configure(inputDevice: inputDevice)
        try? mock.setMonitoringOutput(device: outputDevice)
        try? mock.enableMonitoring(true)
        
        XCTAssertTrue(mock.monitoringEnabled)
    }
    
    /// Test monitoring can be disabled.
    func testMonitoringCanBeDisabled() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "input-uid", isInput: true, isOutput: false)
        let outputDevice = makeDevice(uid: "output-uid", isInput: false, isOutput: true)
        
        try? mock.configure(inputDevice: inputDevice)
        try? mock.setMonitoringOutput(device: outputDevice)
        try? mock.enableMonitoring(true)
        try? mock.enableMonitoring(false)
        
        XCTAssertFalse(mock.monitoringEnabled)
    }
    
    /// Test monitoring device selection.
    func testMonitoringDeviceSelection() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "input-uid", name: "Input", isInput: true, isOutput: false)
        let outputDevice = makeDevice(uid: "output-uid", name: "Output", isInput: false, isOutput: true)
        
        try? mock.configure(inputDevice: inputDevice)
        try? mock.setMonitoringOutput(device: outputDevice)
        
        XCTAssertEqual(mock.currentMonitoringDevice?.name, "Output")
        XCTAssertEqual(mock.setMonitoringOutputCallCount, 1)
    }
    
    /// Test monitoring volume control clamps values.
    func testMonitoringVolumeControl() {
        let mock = MockAudioCaptureEngine()
        
        mock.setMonitoringVolume(0.5)
        XCTAssertEqual(mock.monitoringVolume, 0.5, accuracy: 0.001)
        
        mock.setMonitoringVolume(1.5) // Above max
        XCTAssertEqual(mock.monitoringVolume, 1.0, accuracy: 0.001)
        
        mock.setMonitoringVolume(-0.5) // Below min
        XCTAssertEqual(mock.monitoringVolume, 0.0, accuracy: 0.001)
    }
    
    /// Test feedback prevention when same device for input and output.
    func testFeedbackPrevention() {
        let mock = MockAudioCaptureEngine()
        let device = makeDevice(
            uid: "same-uid",
            name: "Same Device",
            isInput: true,
            isOutput: true
        )
        
        try? mock.configure(inputDevice: device)
        
        XCTAssertThrowsError(try mock.setMonitoringOutput(device: device)) { error in
            guard let vibeCaptionError = error as? VibeCaptionError else {
                XCTFail("Expected VibeCaptionError")
                return
            }
            
            if case .feedbackLoopDetected(let inputDevice, let outputDevice) = vibeCaptionError {
                XCTAssertEqual(inputDevice, "Same Device")
                XCTAssertEqual(outputDevice, "Same Device")
            } else {
                XCTFail("Expected feedbackLoopDetected error")
            }
        }
    }
    
    /// Test feedback prevention when enabling monitoring with same device.
    func testFeedbackPreventionOnEnable() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "same-uid", name: "Same Device", isInput: true, isOutput: false)
        
        try? mock.configure(inputDevice: inputDevice)
        mock.currentMonitoringDevice = makeDevice(uid: "same-uid", name: "Same Device", isInput: false, isOutput: true)
        
        XCTAssertThrowsError(try mock.enableMonitoring(true)) { error in
            guard let vibeCaptionError = error as? VibeCaptionError else {
                XCTFail("Expected VibeCaptionError")
                return
            }
            
            if case .feedbackLoopDetected = vibeCaptionError {
                // Expected
            } else {
                XCTFail("Expected feedbackLoopDetected error")
            }
        }
    }
    
    /// Test monitoring stops when capture stops.
    func testMonitoringStopsWithCapture() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "input-uid", isInput: true, isOutput: false)
        let outputDevice = makeDevice(uid: "output-uid", isInput: false, isOutput: true)
        
        try? mock.configure(inputDevice: inputDevice)
        try? mock.setMonitoringOutput(device: outputDevice)
        try? mock.startCapture()
        try? mock.enableMonitoring(true)
        
        XCTAssertTrue(mock.monitoringEnabled)
        
        mock.stopCapture()
        
        XCTAssertFalse(mock.monitoringEnabled)
    }
    
    /// Test setting output-only device throws when not output.
    func testSetMonitoringOutputWithInputOnlyDeviceThrows() {
        let mock = MockAudioCaptureEngine()
        let inputDevice = makeDevice(uid: "input-uid", isInput: true, isOutput: false)
        let inputOnlyDevice = makeDevice(uid: "input-only-uid", name: "Input Only", isInput: true, isOutput: false)
        
        try? mock.configure(inputDevice: inputDevice)
        
        XCTAssertThrowsError(try mock.setMonitoringOutput(device: inputOnlyDevice)) { error in
            guard let vibeCaptionError = error as? VibeCaptionError else {
                XCTFail("Expected VibeCaptionError")
                return
            }
            
            if case .audioRoutingFailed(let device, let reason) = vibeCaptionError {
                XCTAssertEqual(device, "Input Only")
                XCTAssertTrue(reason.contains("output"))
            } else {
                XCTFail("Expected audioRoutingFailed error")
            }
        }
    }
    
    /// Test mock conforms to protocol with monitoring.
    func testMockConformsToProtocolWithMonitoring() {
        let mock: AudioCaptureEngineProtocol = MockAudioCaptureEngine()
        
        XCTAssertFalse(mock.monitoringEnabled)
        XCTAssertEqual(mock.monitoringVolume, 1.0, accuracy: 0.001)
        XCTAssertNil(mock.currentMonitoringDevice)
    }
    
    // MARK: - Feature Control Tests
    
    /// Test noise suppression can be toggled.
    func testSetNoiseSuppression() {
        // Verification that the API exists and can be called
        sut.setNoiseSuppression(true)
        sut.setNoiseSuppression(false)
        
        // Since we can't easily mock AVAudioEngine internal state in unit tests without a detailed mock wrapper,
        // we mainly ensure the method executes without crashing.
        // On macOS < 10.14 this does nothing.
    }
    
    /// Test mock records noise suppression calls.
    func testMockRecordsNoiseSuppressionCalls() {
        let mock = MockAudioCaptureEngine()
        
        mock.setNoiseSuppression(true)
        XCTAssertEqual(mock.setNoiseSuppressionCallCount, 1)
        
        mock.setNoiseSuppression(false)
        XCTAssertEqual(mock.setNoiseSuppressionCallCount, 2)
    }
}
