//
//  AudioDeviceManager.swift
//  VibeCaption
//
//  Manages audio device enumeration and detection using CoreAudio.
//

import Foundation
import CoreAudio
import Combine
import os.log

// MARK: - AudioDeviceManagerProtocol

/// Protocol defining the interface for audio device management.
///
/// This protocol enables dependency injection and mocking for unit tests.
public protocol AudioDeviceManagerProtocol: AnyObject {
    /// All available input devices.
    var inputDevices: [AudioDevice] { get }
    
    /// All available output devices.
    var outputDevices: [AudioDevice] { get }
    
    /// Refreshes the list of available audio devices.
    func refreshDevices()
    
    /// Retrieves a device by its CoreAudio device ID.
    func getDevice(byID deviceID: AudioDeviceID) -> AudioDevice?
    
    /// Returns the system's default input device.
    func getDefaultInputDevice() -> AudioDevice?
    
    /// Returns the system's default output device.
    func getDefaultOutputDevice() -> AudioDevice?
    
    /// Checks if BlackHole audio driver is installed.
    func isBlackHoleInstalled() -> Bool
}

// MARK: - AudioDeviceManager

/// Manages audio device enumeration and detection for VibeCaption.
///
/// This singleton class uses CoreAudio APIs to enumerate system audio devices,
/// detect BlackHole virtual audio driver, and listen for device changes.
///
/// Usage:
/// ```swift
/// let manager = AudioDeviceManager.shared
/// manager.refreshDevices()
/// print(manager.inputDevices)
/// print(manager.isBlackHoleInstalled())
/// ```
public final class AudioDeviceManager: ObservableObject, AudioDeviceManagerProtocol {
    
    // MARK: - Singleton
    
    /// Shared singleton instance.
    public static let shared = AudioDeviceManager()
    
    // MARK: - Published Properties
    
    /// All available input devices.
    @Published public private(set) var inputDevices: [AudioDevice] = []
    
    /// All available output devices.
    @Published public private(set) var outputDevices: [AudioDevice] = []
    
    // MARK: - Private Properties
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption",
        category: "AudioDeviceManager"
    )
    
    /// Listener block reference for device changes.
    private var deviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    
    /// Queue for CoreAudio property listener callbacks.
    private let listenerQueue = DispatchQueue(label: "com.vibecaption.audiodevicemanager")
    
    // MARK: - Initialization
    
    /// Creates a new AudioDeviceManager instance.
    /// Use `shared` singleton for production code.
    public init() {
        setupDeviceChangeListener()
        refreshDevices()
        logger.debug("AudioDeviceManager initialized")
    }
    
    deinit {
        removeDeviceChangeListener()
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the list of available audio devices.
    ///
    /// This method queries CoreAudio for all system audio devices
    /// and updates the `inputDevices` and `outputDevices` arrays.
    public func refreshDevices() {
        logger.debug("Refreshing audio devices...")
        
        let allDevices = enumerateAllDevices()
        
        DispatchQueue.main.async { [weak self] in
            self?.inputDevices = allDevices.filter { $0.isInput }
            self?.outputDevices = allDevices.filter { $0.isOutput }
            
            self?.logger.info("Found \(self?.inputDevices.count ?? 0) input devices, \(self?.outputDevices.count ?? 0) output devices")
        }
    }
    
    /// Retrieves a device by its CoreAudio device ID.
    ///
    /// - Parameter deviceID: The AudioDeviceID to search for.
    /// - Returns: The matching AudioDevice, or nil if not found.
    public func getDevice(byID deviceID: AudioDeviceID) -> AudioDevice? {
        let allDevices = inputDevices + outputDevices
        return allDevices.first { $0.deviceID == deviceID }
    }
    
    /// Returns the system's default input device.
    ///
    /// - Returns: The default input AudioDevice, or nil if none available.
    public func getDefaultInputDevice() -> AudioDevice? {
        guard let deviceID = getDefaultDeviceID(forInput: true) else {
            logger.warning("No default input device found")
            return nil
        }
        return getDevice(byID: deviceID)
    }
    
    /// Returns the system's default output device.
    ///
    /// - Returns: The default output AudioDevice, or nil if none available.
    public func getDefaultOutputDevice() -> AudioDevice? {
        guard let deviceID = getDefaultDeviceID(forInput: false) else {
            logger.warning("No default output device found")
            return nil
        }
        return getDevice(byID: deviceID)
    }
    
    /// Checks if BlackHole audio driver is installed.
    ///
    /// BlackHole is a virtual audio driver required for capturing
    /// system audio on macOS.
    ///
    /// - Returns: `true` if at least one BlackHole device is found.
    public func isBlackHoleInstalled() -> Bool {
        let allDevices = inputDevices + outputDevices
        return allDevices.contains { $0.isBlackHole }
    }
    
    /// Gets the BlackHole input device if available.
    ///
    /// - Returns: The BlackHole input device, or nil if not installed.
    public func getBlackHoleInputDevice() -> AudioDevice? {
        inputDevices.first { $0.isBlackHole }
    }
    
    // MARK: - Private Methods
    
    /// Enumerates all audio devices in the system.
    private func enumerateAllDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            logger.error("Failed to get devices data size: \(status)")
            return []
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else {
            logger.error("Failed to get device IDs: \(status)")
            return []
        }
        
        return deviceIDs.compactMap { createAudioDevice(from: $0) }
    }
    
    /// Creates an AudioDevice from a CoreAudio device ID.
    private func createAudioDevice(from deviceID: AudioDeviceID) -> AudioDevice? {
        guard let name = getDeviceName(deviceID: deviceID),
              let uid = getDeviceUID(deviceID: deviceID) else {
            return nil
        }
        
        let inputChannels = getChannelCount(deviceID: deviceID, forInput: true)
        let outputChannels = getChannelCount(deviceID: deviceID, forInput: false)
        let sampleRate = getDeviceSampleRate(deviceID: deviceID)
        
        // Skip devices with no channels (they're not usable)
        guard inputChannels > 0 || outputChannels > 0 else {
            return nil
        }
        
        return AudioDevice(
            deviceID: deviceID,
            uid: uid,
            name: name,
            isInput: inputChannels > 0,
            isOutput: outputChannels > 0,
            sampleRate: sampleRate,
            channelCount: max(inputChannels, outputChannels)
        )
    }
    
    /// Gets the device name from CoreAudio.
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &name
        )
        
        guard status == noErr else {
            return nil
        }
        
        return name as String
    }
    
    /// Gets the device UID from CoreAudio.
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &uid
        )
        
        guard status == noErr else {
            return nil
        }
        
        return uid as String
    }
    
    /// Gets the channel count for input or output.
    private func getChannelCount(deviceID: AudioDeviceID, forInput: Bool) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: forInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr, dataSize > 0 else {
            return 0
        }
        
        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        )
        
        guard status == noErr else {
            return 0
        }
        
        let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self)
        let bufferCount = Int(bufferList.pointee.mNumberBuffers)
        
        var totalChannels = 0
        
        // Access buffers safely
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for buffer in buffers {
            totalChannels += Int(buffer.mNumberChannels)
        }
        
        return totalChannels
    }
    
    /// Gets the device sample rate.
    private func getDeviceSampleRate(deviceID: AudioDeviceID) -> Double {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &sampleRate
        )
        
        guard status == noErr else {
            return 44100.0 // Default fallback
        }
        
        return sampleRate
    }
    
    /// Gets the default device ID for input or output.
    private func getDefaultDeviceID(forInput: Bool) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: forInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }
        
        return deviceID
    }
    
    // MARK: - Device Change Listener
    
    /// Sets up a listener for audio device changes.
    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        deviceChangeListenerBlock = { [weak self] (_, _) in
            self?.logger.info("Audio device configuration changed")
            self?.refreshDevices()
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            listenerQueue,
            deviceChangeListenerBlock!
        )
        
        if status != noErr {
            logger.error("Failed to add device change listener: \(status)")
        } else {
            logger.debug("Device change listener registered")
        }
    }
    
    /// Removes the device change listener.
    private func removeDeviceChangeListener() {
        guard let listenerBlock = deviceChangeListenerBlock else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            listenerQueue,
            listenerBlock
        )
        
        if status != noErr {
            logger.warning("Failed to remove device change listener: \(status)")
        }
        
        deviceChangeListenerBlock = nil
    }
}
