//
//  AudioDeviceManagerTests.swift
//  VibeCaptionTests
//
//  Unit tests for AudioDevice model and AudioDeviceManager service.
//

import XCTest
import Combine
import CoreAudio
@testable import VibeCaption

// MARK: - AudioDevice Tests

final class AudioDeviceTests: XCTestCase {
    
    // MARK: - Test Fixtures
    
    private func makeDevice(
        deviceID: AudioDeviceID = 42,
        uid: String = "test-uid",
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
    
    /// Test that device initializes with correct properties.
    func testDeviceInitialization() {
        let device = makeDevice(
            deviceID: 123,
            uid: "unique-id",
            name: "My Audio Device",
            isInput: true,
            isOutput: true,
            sampleRate: 44100.0,
            channelCount: 8
        )
        
        XCTAssertEqual(device.deviceID, 123)
        XCTAssertEqual(device.uid, "unique-id")
        XCTAssertEqual(device.name, "My Audio Device")
        XCTAssertTrue(device.isInput)
        XCTAssertTrue(device.isOutput)
        XCTAssertEqual(device.sampleRate, 44100.0)
        XCTAssertEqual(device.channelCount, 8)
    }
    
    /// Test that id property returns uid.
    func testDeviceIdReturnsUID() {
        let device = makeDevice(uid: "my-unique-id")
        XCTAssertEqual(device.id, "my-unique-id")
    }
    
    // MARK: - BlackHole Detection Tests
    
    /// Test that BlackHole device is detected by name.
    func testBlackHoleDeviceDetectedByExactName() {
        let device = makeDevice(name: "BlackHole 2ch")
        XCTAssertTrue(device.isBlackHole)
    }
    
    /// Test that BlackHole 16ch is detected.
    func testBlackHole16chDetected() {
        let device = makeDevice(name: "BlackHole 16ch")
        XCTAssertTrue(device.isBlackHole)
    }
    
    /// Test case-insensitive BlackHole detection.
    func testBlackHoleDetectionIsCaseInsensitive() {
        let lowercase = makeDevice(name: "blackhole 2ch")
        let uppercase = makeDevice(name: "BLACKHOLE 2CH")
        let mixedCase = makeDevice(name: "BlAcKhOlE 2ch")
        
        XCTAssertTrue(lowercase.isBlackHole)
        XCTAssertTrue(uppercase.isBlackHole)
        XCTAssertTrue(mixedCase.isBlackHole)
    }
    
    /// Test that non-BlackHole device is not flagged.
    func testNonBlackHoleDeviceNotFlagged() {
        let builtIn = makeDevice(name: "Built-in Microphone")
        let external = makeDevice(name: "USB Audio Interface")
        let airplay = makeDevice(name: "AirPlay")
        
        XCTAssertFalse(builtIn.isBlackHole)
        XCTAssertFalse(external.isBlackHole)
        XCTAssertFalse(airplay.isBlackHole)
    }
    
    /// Test partial BlackHole name match.
    func testPartialBlackHoleNameMatch() {
        let device = makeDevice(name: "My BlackHole Device")
        XCTAssertTrue(device.isBlackHole)
    }
    
    // MARK: - Equatable Tests
    
    /// Test that identical devices are equal.
    func testDevicesWithSamePropertiesAreEqual() {
        let device1 = makeDevice()
        let device2 = makeDevice()
        XCTAssertEqual(device1, device2)
    }
    
    /// Test that different devices are not equal.
    func testDevicesWithDifferentUIDsAreNotEqual() {
        let device1 = makeDevice(uid: "uid-1")
        let device2 = makeDevice(uid: "uid-2")
        XCTAssertNotEqual(device1, device2)
    }
    
    /// Test that devices with different device IDs are not equal.
    func testDevicesWithDifferentDeviceIDsAreNotEqual() {
        let device1 = makeDevice(deviceID: 1)
        let device2 = makeDevice(deviceID: 2)
        XCTAssertNotEqual(device1, device2)
    }
    
    // MARK: - Identifiable Tests
    
    /// Test devices are usable in SwiftUI with Identifiable.
    func testDevicesHaveUniqueIdentifiableIDs() {
        let device1 = makeDevice(uid: "device-1")
        let device2 = makeDevice(uid: "device-2")
        
        XCTAssertNotEqual(device1.id, device2.id)
    }
    
    // MARK: - Description Tests
    
    /// Test custom string description format.
    func testDeviceDescriptionFormat() {
        let inputDevice = makeDevice(
            name: "Test Input",
            isInput: true,
            isOutput: false,
            sampleRate: 48000.0,
            channelCount: 2
        )
        
        XCTAssertTrue(inputDevice.description.contains("Test Input"))
        XCTAssertTrue(inputDevice.description.contains("Input"))
        XCTAssertTrue(inputDevice.description.contains("48000Hz"))
        XCTAssertTrue(inputDevice.description.contains("2ch"))
    }
    
    /// Test combined input/output device description.
    func testCombinedDeviceDescription() {
        let device = makeDevice(
            name: "Combined Device",
            isInput: true,
            isOutput: true
        )
        
        XCTAssertTrue(device.description.contains("Input"))
        XCTAssertTrue(device.description.contains("Output"))
    }
}

// MARK: - Mock AudioDeviceManager

/// Mock implementation of AudioDeviceManagerProtocol for testing.
final class MockAudioDeviceManager: AudioDeviceManagerProtocol {
    
    var inputDevices: [AudioDevice] = []
    var outputDevices: [AudioDevice] = []
    
    var refreshDevicesCalled = false
    var refreshDevicesCallCount = 0
    
    func refreshDevices() {
        refreshDevicesCalled = true
        refreshDevicesCallCount += 1
    }
    
    func getDevice(byID deviceID: AudioDeviceID) -> AudioDevice? {
        let allDevices = inputDevices + outputDevices
        return allDevices.first { $0.deviceID == deviceID }
    }
    
    func getDefaultInputDevice() -> AudioDevice? {
        inputDevices.first
    }
    
    func getDefaultOutputDevice() -> AudioDevice? {
        outputDevices.first
    }
    
    func isBlackHoleInstalled() -> Bool {
        let allDevices = inputDevices + outputDevices
        return allDevices.contains { $0.isBlackHole }
    }
}

// MARK: - AudioDeviceManager Tests

@MainActor
final class AudioDeviceManagerTests: XCTestCase {
    
    var sut: AudioDeviceManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AudioDeviceManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }

    private func refreshDevicesAndWait(timeout: TimeInterval = 3.0) {
        let expectation = expectation(description: "Devices refreshed")

        sut.$inputDevices
            .dropFirst()
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.refreshDevices()
        waitForExpectations(timeout: timeout)
    }
    
    // MARK: - Singleton Tests
    
    /// Test that shared instance exists.
    func testSharedInstanceExists() {
        XCTAssertNotNil(AudioDeviceManager.shared)
    }
    
    /// Test that shared returns same instance.
    func testSharedReturnsSameInstance() {
        let instance1 = AudioDeviceManager.shared
        let instance2 = AudioDeviceManager.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Device Enumeration Tests
    
    /// Test that refreshDevices populates device lists.
    /// Note: This test may find different devices on different machines.
    func testRefreshDevicesPopulatesLists() {
        // Should complete even on environments with no audio hardware.
        refreshDevicesAndWait()
    }
    
    /// Test that devices have valid properties.
    func testDevicesHaveValidProperties() {
        refreshDevicesAndWait()

        for device in sut.inputDevices {
            XCTAssertFalse(device.uid.isEmpty, "Device UID should not be empty")
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
            XCTAssertTrue(device.isInput, "Input device should be marked as input")
            XCTAssertGreaterThan(device.sampleRate, 0, "Sample rate should be positive")
            XCTAssertGreaterThan(device.channelCount, 0, "Channel count should be positive")
        }

        for device in sut.outputDevices {
            XCTAssertFalse(device.uid.isEmpty, "Device UID should not be empty")
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
            XCTAssertTrue(device.isOutput, "Output device should be marked as output")
        }
    }
    
    // MARK: - Get Device Tests
    
    /// Test getDevice returns nil for unknown ID.
    func testGetDeviceReturnsNilForUnknownID() {
        let device = sut.getDevice(byID: AudioDeviceID.max)
        XCTAssertNil(device)
    }
    
    /// Test getDevice returns device when found.
    func testGetDeviceReturnsDeviceWhenFound() {
        refreshDevicesAndWait()

        if let firstInput = sut.inputDevices.first {
            let found = sut.getDevice(byID: firstInput.deviceID)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.deviceID, firstInput.deviceID)
        }
    }
    
    // MARK: - Default Device Tests
    
    /// Test default input device returns a device (if available).
    func testDefaultInputDeviceReturnsDevice() {
        refreshDevicesAndWait()

        // Note: May be nil in CI environments without audio hardware
        if !sut.inputDevices.isEmpty {
            let defaultInput = sut.getDefaultInputDevice()
            if let device = defaultInput {
                XCTAssertTrue(device.isInput)
            }
        }
    }
    
    /// Test default output device returns a device (if available).
    func testDefaultOutputDeviceReturnsDevice() {
        refreshDevicesAndWait()

        if !sut.outputDevices.isEmpty {
            let defaultOutput = sut.getDefaultOutputDevice()
            if let device = defaultOutput {
                XCTAssertTrue(device.isOutput)
            }
        }
    }
    
    // MARK: - Observable Tests
    
    /// Test inputDevices is observable via Combine.
    /// Note: Observable tests verify that the @Published properties work correctly.
    /// Since devices are refreshed on init, we check that we can observe current state.
    func testInputDevicesIsObservable() {
        let expectation = expectation(description: "Input devices published")

        sut.$inputDevices
            .dropFirst()
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.refreshDevices()
        waitForExpectations(timeout: 3.0)
    }
    
    /// Test outputDevices is observable via Combine.
    func testOutputDevicesIsObservable() {
        let expectation = expectation(description: "Output devices published")

        sut.$outputDevices
            .dropFirst()
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.refreshDevices()
        waitForExpectations(timeout: 3.0)
    }
}

// MARK: - Mock AudioDeviceManager Tests

final class MockAudioDeviceManagerTests: XCTestCase {
    
    var mockManager: MockAudioDeviceManager!
    
    override func setUp() {
        super.setUp()
        mockManager = MockAudioDeviceManager()
    }
    
    override func tearDown() {
        mockManager = nil
        super.tearDown()
    }
    
    // MARK: - Test Fixtures
    
    private func makeDevice(
        deviceID: AudioDeviceID = 42,
        name: String = "Test Device",
        isInput: Bool = true,
        isBlackHole: Bool = false
    ) -> AudioDevice {
        AudioDevice(
            deviceID: deviceID,
            uid: "uid-\(deviceID)",
            name: isBlackHole ? "BlackHole 2ch" : name,
            isInput: isInput,
            isOutput: !isInput,
            sampleRate: 48000.0,
            channelCount: 2
        )
    }
    
    // MARK: - BlackHole Detection Tests
    
    /// Test isBlackHoleInstalled returns true when BlackHole device present.
    func testBlackHoleInstalledWhenDevicePresent() {
        mockManager.inputDevices = [
            makeDevice(deviceID: 1, name: "Built-in Microphone"),
            makeDevice(deviceID: 2, name: "BlackHole 2ch")
        ]
        
        XCTAssertTrue(mockManager.isBlackHoleInstalled())
    }
    
    /// Test isBlackHoleInstalled returns false when no BlackHole device.
    func testBlackHoleNotInstalledWhenNoDevice() {
        mockManager.inputDevices = [
            makeDevice(deviceID: 1, name: "Built-in Microphone"),
            makeDevice(deviceID: 2, name: "USB Audio")
        ]
        
        XCTAssertFalse(mockManager.isBlackHoleInstalled())
    }
    
    /// Test BlackHole detected in output devices.
    func testBlackHoleDetectedInOutputDevices() {
        mockManager.outputDevices = [
            AudioDevice(
                deviceID: 1,
                uid: "uid-1",
                name: "BlackHole 16ch",
                isInput: false,
                isOutput: true,
                sampleRate: 48000,
                channelCount: 16
            )
        ]
        
        XCTAssertTrue(mockManager.isBlackHoleInstalled())
    }
    
    // MARK: - Device Lookup Tests
    
    /// Test getDevice returns correct device by ID.
    func testGetDeviceByIDReturnsCorrectDevice() {
        let device1 = makeDevice(deviceID: 100)
        let device2 = makeDevice(deviceID: 200)
        mockManager.inputDevices = [device1, device2]
        
        let found = mockManager.getDevice(byID: 200)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.deviceID, 200)
    }
    
    /// Test getDevice returns nil for unknown ID.
    func testGetDeviceByIDReturnsNilForUnknown() {
        mockManager.inputDevices = [makeDevice(deviceID: 1)]
        
        let found = mockManager.getDevice(byID: 999)
        XCTAssertNil(found)
    }
    
    // MARK: - Default Device Tests
    
    /// Test getDefaultInputDevice returns first input device.
    func testGetDefaultInputDeviceReturnsFirst() {
        let device1 = makeDevice(deviceID: 1, name: "First Input")
        let device2 = makeDevice(deviceID: 2, name: "Second Input")
        mockManager.inputDevices = [device1, device2]
        
        let defaultDevice = mockManager.getDefaultInputDevice()
        XCTAssertEqual(defaultDevice?.deviceID, 1)
    }
    
    /// Test getDefaultInputDevice returns nil when no devices.
    func testGetDefaultInputDeviceReturnsNilWhenEmpty() {
        mockManager.inputDevices = []
        
        let defaultDevice = mockManager.getDefaultInputDevice()
        XCTAssertNil(defaultDevice)
    }
    
    /// Test getDefaultOutputDevice returns first output device.
    func testGetDefaultOutputDeviceReturnsFirst() {
        let device1 = makeDevice(deviceID: 1, name: "First Output", isInput: false)
        let device2 = makeDevice(deviceID: 2, name: "Second Output", isInput: false)
        mockManager.outputDevices = [device1, device2]
        
        let defaultDevice = mockManager.getDefaultOutputDevice()
        XCTAssertEqual(defaultDevice?.deviceID, 1)
    }
    
    // MARK: - Refresh Devices Tests
    
    /// Test refreshDevices tracks call count.
    func testRefreshDevicesTracksCallCount() {
        XCTAssertEqual(mockManager.refreshDevicesCallCount, 0)
        XCTAssertFalse(mockManager.refreshDevicesCalled)
        
        mockManager.refreshDevices()
        
        XCTAssertEqual(mockManager.refreshDevicesCallCount, 1)
        XCTAssertTrue(mockManager.refreshDevicesCalled)
        
        mockManager.refreshDevices()
        mockManager.refreshDevices()
        
        XCTAssertEqual(mockManager.refreshDevicesCallCount, 3)
    }
}
