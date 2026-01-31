//
//  AudioDevice.swift
//  VibeCaption
//
//  Model representing an audio device from CoreAudio.
//

import Foundation
import CoreAudio

// MARK: - AudioDevice

/// Represents an audio device enumerated from the system.
///
/// This model encapsulates CoreAudio device information in a Swift-friendly
/// structure with computed properties for common checks like BlackHole detection.
///
/// Example:
/// ```swift
/// let device = AudioDevice(
///     deviceID: 42,
///     uid: "BlackHole2ch_UID",
///     name: "BlackHole 2ch",
///     isInput: true,
///     isOutput: false,
///     sampleRate: 48000.0,
///     channelCount: 2
/// )
/// print(device.isBlackHole) // true
/// ```
public struct AudioDevice: Identifiable, Equatable, Codable, Sendable {
    
    // MARK: - Properties
    
    /// The CoreAudio device ID.
    public let deviceID: AudioDeviceID
    
    /// Unique identifier for the device (persistent across reboots).
    public let uid: String
    
    /// Human-readable display name of the device.
    public let name: String
    
    /// Whether this device supports audio input.
    public let isInput: Bool
    
    /// Whether this device supports audio output.
    public let isOutput: Bool
    
    /// The device's nominal sample rate in Hz.
    public let sampleRate: Double
    
    /// Number of audio channels the device supports.
    public let channelCount: Int
    
    // MARK: - Computed Properties
    
    /// Unique identifier conforming to Identifiable protocol.
    /// Uses the UID as it's persistent across reboots.
    public var id: String { uid }
    
    /// Indicates whether this device is a BlackHole virtual audio device.
    ///
    /// BlackHole is required for capturing system audio on macOS.
    /// Detection is based on the device name containing "BlackHole".
    public var isBlackHole: Bool {
        name.localizedCaseInsensitiveContains("BlackHole")
    }
    
    // MARK: - Initialization
    
    /// Creates a new AudioDevice instance.
    ///
    /// - Parameters:
    ///   - deviceID: The CoreAudio device ID (AudioDeviceID).
    ///   - uid: Unique identifier string for the device.
    ///   - name: Human-readable display name.
    ///   - isInput: Whether the device supports audio input.
    ///   - isOutput: Whether the device supports audio output.
    ///   - sampleRate: Nominal sample rate in Hz.
    ///   - channelCount: Number of audio channels.
    public init(
        deviceID: AudioDeviceID,
        uid: String,
        name: String,
        isInput: Bool,
        isOutput: Bool,
        sampleRate: Double,
        channelCount: Int
    ) {
        self.deviceID = deviceID
        self.uid = uid
        self.name = name
        self.isInput = isInput
        self.isOutput = isOutput
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

// MARK: - CustomStringConvertible

extension AudioDevice: CustomStringConvertible {
    public var description: String {
        let type = [isInput ? "Input" : nil, isOutput ? "Output" : nil]
            .compactMap { $0 }
            .joined(separator: "/")
        return "\(name) (\(type)) - \(Int(sampleRate))Hz, \(channelCount)ch"
    }
}
