//
//  AudioCaptureEngine.swift
//  VibeCaption
//
//  Core audio capture engine using AVAudioEngine.
//

import Foundation
import AVFoundation
import Combine
import os.log

// MARK: - AudioCaptureEngineProtocol

/// Protocol defining the audio capture engine interface.
///
/// This protocol allows for mock implementations during testing.
public protocol AudioCaptureEngineProtocol: AnyObject {
    var isCapturing: Bool { get }
    var currentInputDevice: AudioDevice? { get }
    var audioLevel: Float { get }
    var audioLevelPublisher: Published<Float>.Publisher { get }
    
    func configure(inputDevice: AudioDevice) throws
    func startCapture() throws
    func stopCapture()
    func setAudioCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void)
}

// MARK: - AudioCaptureEngine

/// Core audio capture engine for VibeCaption using AVAudioEngine.
///
/// This class manages audio capture from a specified input device,
/// performs sample rate conversion to 16kHz for ASR compatibility,
/// and calculates RMS audio levels for the UI meter.
///
/// Usage:
/// ```swift
/// let engine = AudioCaptureEngine()
/// try engine.configure(inputDevice: blackHoleDevice)
/// engine.setAudioCallback { buffer in
///     process(buffer)
/// }
/// try engine.startCapture()
/// ```
public final class AudioCaptureEngine: ObservableObject, AudioCaptureEngineProtocol {
    
    // MARK: - Constants
    
    /// Target sample rate for ASR processing.
    public static let targetSampleRate: Double = 16000
    
    /// Buffer size for audio tap (in frames).
    private static let bufferSize: AVAudioFrameCount = 4096
    
    /// Timeout duration for detecting audio frames (in seconds).
    private static let noAudioTimeout: TimeInterval = 5.0
    
    /// Interval for logging audio level (in seconds).
    private static let audioLevelLogInterval: TimeInterval = 1.0
    
    // MARK: - Published Properties
    
    /// Whether audio capture is currently active.
    @Published public private(set) var isCapturing: Bool = false
    
    /// Current RMS audio level (0.0-1.0) for UI meter.
    @Published public private(set) var audioLevel: Float = 0.0
    
    /// Publisher for audio level updates.
    public var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    
    // MARK: - Properties
    
    /// Currently configured input device.
    public private(set) var currentInputDevice: AudioDevice?
    
    /// Internal ring buffer for audio samples.
    public let ringBuffer: AudioRingBuffer
    
    /// The AVAudioEngine instance.
    private var audioEngine: AVAudioEngine
    
    /// Audio format converter for 16kHz output.
    private var converter: AVAudioConverter?
    
    /// Target audio format (16kHz mono).
    private var targetFormat: AVAudioFormat?
    
    /// Callback for processed audio data.
    private var audioCallback: ((AVAudioPCMBuffer) -> Void)?
    
    /// Timer for detecting no audio frames.
    private var noAudioTimer: Timer?
    
    /// Last time audio frames were received.
    private var lastAudioFrameTime: Date?
    
    /// Timer for periodic audio level logging.
    private var levelLogTimer: Timer?
    
    /// Logger instance.
    private let logger = Logger(subsystem: "com.vibecaption", category: "AudioCaptureEngine")
    
    // MARK: - Initialization
    
    /// Creates a new audio capture engine.
    ///
    /// - Parameter ringBufferCapacity: Capacity of the ring buffer in samples.
    ///                                 Default is 30 seconds at 16kHz.
    public init(ringBufferCapacity: Int = Int(targetSampleRate) * 30) {
        self.audioEngine = AVAudioEngine()
        self.ringBuffer = AudioRingBuffer(capacity: ringBufferCapacity)
        
        // Create target format (16kHz mono)
        self.targetFormat = AVAudioFormat(
            standardFormatWithSampleRate: Self.targetSampleRate,
            channels: 1
        )
        
        logger.info("AudioCaptureEngine initialized")
    }
    
    deinit {
        stopCapture()
    }
    
    // MARK: - Configuration
    
    /// Configures the engine to use the specified input device.
    ///
    /// - Parameter inputDevice: The audio device to use for capture.
    /// - Throws: `VibeCaptionError.audioRoutingFailed` if the device is not accessible.
    public func configure(inputDevice: AudioDevice) throws {
        logger.info("Configuring input device: \(inputDevice.name)")
        
        // Verify device is an input device
        guard inputDevice.isInput else {
            logger.error("Device is not an input device: \(inputDevice.name)")
            throw VibeCaptionError.audioRoutingFailed(
                device: inputDevice.name,
                reason: "Device does not support audio input"
            )
        }
        
        // Stop any existing capture
        if isCapturing {
            stopCapture()
        }
        
        // Reset the engine
        audioEngine = AVAudioEngine()
        
        // Try to set the input device via AudioUnit
        do {
            try setInputDevice(inputDevice)
        } catch {
            logger.error("Failed to set input device: \(error.localizedDescription)")
            throw VibeCaptionError.audioRoutingFailed(
                device: inputDevice.name,
                reason: error.localizedDescription
            )
        }
        
        // Setup converter for the new input format
        setupConverter()
        
        currentInputDevice = inputDevice
        logger.info("Input device configured successfully: \(inputDevice.name)")
    }
    
    // MARK: - Capture Control
    
    /// Starts audio capture from the configured input device.
    ///
    /// - Throws: `VibeCaptionError.audioRoutingFailed` if capture cannot be started.
    public func startCapture() throws {
        guard !isCapturing else {
            logger.warning("Capture already in progress")
            return
        }
        
        guard currentInputDevice != nil else {
            logger.error("No input device configured")
            throw VibeCaptionError.audioRoutingFailed(
                device: "None",
                reason: "No input device configured. Call configure(inputDevice:) first."
            )
        }
        
        logger.info("Starting audio capture...")
        
        // Install tap on input node
        installInputTap()
        
        // Start the engine
        do {
            try audioEngine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            throw VibeCaptionError.audioRoutingFailed(
                device: currentInputDevice?.name ?? "Unknown",
                reason: error.localizedDescription
            )
        }
        
        // Start no-audio detection timer
        startNoAudioTimer()
        
        // Start level logging timer
        startLevelLogging()
        
        isCapturing = true
        lastAudioFrameTime = Date()
        logger.info("Audio capture started")
    }
    
    /// Stops audio capture.
    public func stopCapture() {
        guard isCapturing else { return }
        
        logger.info("Stopping audio capture...")
        
        // Stop timers
        noAudioTimer?.invalidate()
        noAudioTimer = nil
        levelLogTimer?.invalidate()
        levelLogTimer = nil
        
        // Remove input tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Stop engine
        audioEngine.stop()
        
        isCapturing = false
        audioLevel = 0.0
        logger.info("Audio capture stopped")
    }
    
    /// Sets the callback for receiving audio data.
    ///
    /// - Parameter callback: Closure called with each processed audio buffer.
    public func setAudioCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void) {
        audioCallback = callback
    }
    
    // MARK: - Private Methods
    
    /// Sets the input device for the audio engine.
    private func setInputDevice(_ device: AudioDevice) throws {
        #if os(macOS)
        let inputNode = audioEngine.inputNode
        let audioUnit = inputNode.audioUnit
        
        guard let au = audioUnit else {
            throw VibeCaptionError.audioRoutingFailed(
                device: device.name,
                reason: "Failed to get audio unit from input node"
            )
        }
        
        var deviceID = device.deviceID
        let status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        guard status == noErr else {
            throw VibeCaptionError.audioRoutingFailed(
                device: device.name,
                reason: "Failed to set input device (error: \(status))"
            )
        }
        #endif
    }
    
    /// Sets up the audio converter for sample rate conversion.
    private func setupConverter() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        guard let outputFormat = targetFormat else {
            logger.error("Target format not available")
            return
        }
        
        // Create converter if sample rates differ
        if inputFormat.sampleRate != outputFormat.sampleRate {
            converter = AVAudioConverter(from: inputFormat, to: outputFormat)
            logger.info("Created converter: \(inputFormat.sampleRate)Hz -> \(outputFormat.sampleRate)Hz")
        } else {
            converter = nil
            logger.info("No sample rate conversion needed")
        }
    }
    
    /// Installs the audio tap on the input node.
    private func installInputTap() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: Self.bufferSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        logger.info("Installed input tap with format: \(inputFormat)")
    }
    
    /// Processes incoming audio buffer.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Update last frame time
        lastAudioFrameTime = Date()
        
        // Calculate RMS level
        let level = calculateRMSLevel(buffer: buffer)
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
        }
        
        // Convert to target format if needed
        let outputBuffer: AVAudioPCMBuffer
        if let converter = converter,
           let targetFormat = targetFormat,
           let convertedBuffer = convertBuffer(buffer, using: converter, to: targetFormat) {
            outputBuffer = convertedBuffer
        } else {
            outputBuffer = buffer
        }
        
        // Write to ring buffer
        ringBuffer.write(outputBuffer)
        
        // Call user callback
        audioCallback?(outputBuffer)
    }
    
    /// Converts audio buffer to target format.
    private func convertBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        // Calculate output frame capacity
        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            logger.error("Failed to create output buffer")
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        guard status != .error else {
            logger.error("Conversion failed: \(error?.localizedDescription ?? "Unknown")")
            return nil
        }
        
        return outputBuffer
    }
    
    /// Calculates the RMS (Root Mean Square) level of the audio buffer.
    ///
    /// - Parameter buffer: The audio buffer to analyze.
    /// - Returns: RMS level normalized to 0.0-1.0 range.
    private func calculateRMSLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        guard frameLength > 0 else { return 0.0 }
        
        var sumOfSquares: Float = 0.0
        
        // Sum squares across all channels
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for i in 0..<frameLength {
                let sample = samples[i]
                sumOfSquares += sample * sample
            }
        }
        
        // Calculate RMS
        let totalSamples = Float(frameLength * channelCount)
        let rms = sqrt(sumOfSquares / totalSamples)
        
        // Normalize to 0-1 range (assuming max amplitude of 1.0)
        // Apply some scaling for better visual representation
        let normalizedLevel = min(rms * 2.0, 1.0)
        
        return normalizedLevel
    }
    
    /// Starts the no-audio detection timer.
    private func startNoAudioTimer() {
        noAudioTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkForNoAudio()
        }
    }
    
    /// Checks if audio frames have been received recently.
    private func checkForNoAudio() {
        guard isCapturing else { return }
        
        guard let lastTime = lastAudioFrameTime else {
            // No frames received yet, but timer started
            return
        }
        
        let elapsed = Date().timeIntervalSince(lastTime)
        if elapsed >= Self.noAudioTimeout {
            logger.warning("No audio frames detected for \(elapsed) seconds")
            // Note: We log a warning but don't throw here.
            // The error should be handled by the calling code if needed.
            // In a real implementation, we might use a delegate or notification.
        }
    }
    
    /// Starts periodic audio level logging for debugging.
    private func startLevelLogging() {
        levelLogTimer = Timer.scheduledTimer(
            withTimeInterval: Self.audioLevelLogInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self, self.isCapturing else { return }
            self.logger.debug("Audio level: \(String(format: "%.2f", self.audioLevel))")
        }
    }
}

// MARK: - RMS Calculation Utility

extension AudioCaptureEngine {
    
    /// Calculates RMS level from raw float samples.
    ///
    /// This is a utility method for testing and external use.
    ///
    /// - Parameter samples: Array of audio samples.
    /// - Returns: RMS level (not normalized).
    public static func calculateRMS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        var sumOfSquares: Float = 0.0
        for sample in samples {
            sumOfSquares += sample * sample
        }
        
        return sqrt(sumOfSquares / Float(samples.count))
    }
}
