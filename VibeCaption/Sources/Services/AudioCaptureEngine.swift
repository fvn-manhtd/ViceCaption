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
    
    // Monitoring properties
    var monitoringEnabled: Bool { get }
    var monitoringVolume: Float { get }
    var currentMonitoringDevice: AudioDevice? { get }
    
    func configure(inputDevice: AudioDevice) throws
    func startCapture() throws
    func stopCapture()
    func setAudioCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void)
    
    // Monitoring methods
    func setMonitoringOutput(device: AudioDevice?) throws
    func enableMonitoring(_ enabled: Bool) throws
    func setMonitoringVolume(_ volume: Float)
    
    // Noise Suppression
    func setNoiseSuppression(_ enabled: Bool)
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
    
    /// Whether audio monitoring is currently enabled.
    @Published public private(set) var monitoringEnabled: Bool = false
    
    /// Current monitoring volume (0.0-1.0).
    @Published public private(set) var monitoringVolume: Float = 1.0
    
    /// Publisher for audio level updates.
    public var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    
    // MARK: - Properties
    
    /// Currently configured input device.
    public private(set) var currentInputDevice: AudioDevice?
    
    /// Currently configured monitoring output device.
    public private(set) var currentMonitoringDevice: AudioDevice?
    
    /// Internal ring buffer for audio samples.
    public let ringBuffer: AudioRingBuffer
    
    /// The AVAudioEngine instance.
    private var audioEngine: AVAudioEngine
    
    /// Audio preprocessor for sample rate conversion.
    private let preprocessor: AudioPreprocessor
    
    /// Callback for processed audio data.
    private var audioCallback: ((AVAudioPCMBuffer) -> Void)?
    
    /// Timer for detecting no audio frames.
    private var noAudioTimer: Timer?
    
    /// Last time audio frames were received.
    private var lastAudioFrameTime: Date?
    
    /// Timer for periodic audio level logging.
    private var levelLogTimer: Timer?
    
    /// Monitoring output engine (separate from capture engine).
    private var monitoringEngine: AVAudioEngine?
    
    /// Monitoring player node for scheduling audio buffers.
    private var monitoringPlayerNode: AVAudioPlayerNode?
    
    /// Audio format for monitoring output.
    private var monitoringFormat: AVAudioFormat?
    
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
        self.preprocessor = AudioPreprocessor(outputSampleRate: Self.targetSampleRate)
        
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
        try configure(inputDevice: inputDevice, noiseSuppressionEnabled: true)
    }

    /// Configures the engine to use the specified input device.
    ///
    /// - Parameter inputDevice: The audio device to use for capture.
    /// - Parameter noiseSuppressionEnabled: Whether to enable system noise suppression (Voice Processing I/O).
    /// - Throws: `VibeCaptionError.audioRoutingFailed` if the device is not accessible.
    public func configure(inputDevice: AudioDevice, noiseSuppressionEnabled: Bool = true) throws {
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
        
        // Reset preprocessor
        preprocessor.reset()
        
        // Reset the engine
        audioEngine = AVAudioEngine()
        
        // Configure Voice Processing I/O if requested (macOS 10.14+)
        if #available(macOS 10.14, *) {
            do {
                // Voice Processing I/O is enabled on the input node
                try audioEngine.inputNode.setVoiceProcessingEnabled(noiseSuppressionEnabled)
                logger.info("Voice Processing I/O set to: \(noiseSuppressionEnabled)")
            } catch {
                logger.warning("Failed to set Voice Processing I/O: \(error.localizedDescription)")
            }
        }
        
        // Try to set the input device via AudioUnit
        do {
            try setInputDevice(inputDevice)
            currentInputDevice = inputDevice
            logger.info("Input device configured successfully: \(inputDevice.name)")
        } catch {
            // Some macOS audio units reject explicit device binding (e.g. -10875).
            // In that case, continue with system default input instead of failing startup.
            logger.warning("Failed to bind input device \(inputDevice.name): \(error.localizedDescription). Falling back to system default input.")
            currentInputDevice = AudioDeviceManager.shared.getDefaultInputDevice() ?? inputDevice
            logger.info("Using fallback input device: \(self.currentInputDevice?.name ?? inputDevice.name)")
        }
    }
    
    // MARK: - Feature Control
    
    /// Enables or disables voice processing (noise suppression).
    ///
    /// - Parameter enabled: Whether to enable noise suppression.
    public func setNoiseSuppression(_ enabled: Bool) {
        if #available(macOS 10.14, *) {
            do {
                try audioEngine.inputNode.setVoiceProcessingEnabled(enabled)
                logger.info("Voice Processing I/O set to: \(enabled)")
            } catch {
                logger.warning("Failed to set Voice Processing I/O: \(error.localizedDescription)")
            }
        }
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
        
        // Stop monitoring if enabled
        if monitoringEnabled {
            teardownMonitoringEngine()
            monitoringEnabled = false
        }
        
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
    
    // MARK: - Monitoring Control
    
    /// Sets the output device for audio monitoring.
    ///
    /// - Parameter device: The audio device to use for monitoring output.
    ///                     Pass `nil` to use the system default output.
    /// - Throws: `VibeCaptionError.feedbackLoopDetected` if same device is used for input and output.
    ///           `VibeCaptionError.audioRoutingFailed` if the device cannot be set.
    public func setMonitoringOutput(device: AudioDevice?) throws {
        // Check for feedback loop
        if let device = device, let inputDevice = currentInputDevice {
            if device.uid == inputDevice.uid {
                logger.error("Feedback loop detected: same device for input and output")
                throw VibeCaptionError.feedbackLoopDetected(
                    inputDevice: inputDevice.name,
                    outputDevice: device.name
                )
            }
        }
        
        // Verify device is an output device
        if let device = device {
            guard device.isOutput else {
                logger.error("Device is not an output device: \(device.name)")
                throw VibeCaptionError.audioRoutingFailed(
                    device: device.name,
                    reason: "Device does not support audio output"
                )
            }
        }
        
        // Stop monitoring if currently enabled
        let wasEnabled = monitoringEnabled
        if wasEnabled {
            try? enableMonitoring(false)
        }
        
        currentMonitoringDevice = device
        
        // Restart monitoring if it was enabled
        if wasEnabled {
            try? enableMonitoring(true)
        }
        
        logger.info("Monitoring output device set to: \(device?.name ?? "system default")")
    }
    
    /// Enables or disables audio monitoring passthrough.
    ///
    /// - Parameter enabled: Whether to enable monitoring.
    /// - Throws: `VibeCaptionError.feedbackLoopDetected` if same device is used for input and output.
    public func enableMonitoring(_ enabled: Bool) throws {
        guard monitoringEnabled != enabled else { return }
        
        if enabled {
            // Check for feedback loop before enabling
            if let inputDevice = currentInputDevice,
               let outputDevice = currentMonitoringDevice,
               inputDevice.uid == outputDevice.uid {
                logger.error("Cannot enable monitoring: feedback loop detected")
                throw VibeCaptionError.feedbackLoopDetected(
                    inputDevice: inputDevice.name,
                    outputDevice: outputDevice.name
                )
            }
            
            try setupMonitoringEngine()
            monitoringEnabled = true
            logger.info("Audio monitoring enabled")
        } else {
            teardownMonitoringEngine()
            monitoringEnabled = false
            logger.info("Audio monitoring disabled")
        }
    }
    
    /// Sets the monitoring output volume.
    ///
    /// - Parameter volume: Volume level from 0.0 (mute) to 1.0 (full).
    public func setMonitoringVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        monitoringVolume = clampedVolume
        monitoringPlayerNode?.volume = clampedVolume
        logger.debug("Monitoring volume set to: \(clampedVolume)")
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
        
        // Preprocess buffer (SRC)
        let outputBuffer = preprocessor.process(buffer)
        
        // Write to ring buffer
        ringBuffer.write(outputBuffer)
        
        // Send to monitoring if enabled
        if monitoringEnabled {
            scheduleMonitoringBuffer(outputBuffer)
        }
        
        // Call user callback
        audioCallback?(outputBuffer)
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
    
    // MARK: - Monitoring Engine Methods
    
    /// Sets up the monitoring audio engine for passthrough.
    private func setupMonitoringEngine() throws {
        // Clean up any existing monitoring engine
        teardownMonitoringEngine()
        
        // Create new monitoring engine
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        engine.attach(playerNode)
        
        // Use the preprocessor target sample rate for monitoring output.
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: preprocessor.outputSampleRate,
            channels: 1
        )!
        
        // Connect player to main mixer to output
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
        
        // Set output device if specified
        if let device = currentMonitoringDevice {
            try setMonitoringOutputDevice(device, on: engine)
        }
        
        // Set volume
        playerNode.volume = monitoringVolume
        
        // Start the engine
        do {
            try engine.start()
            playerNode.play()
        } catch {
            logger.error("Failed to start monitoring engine: \(error.localizedDescription)")
            throw VibeCaptionError.audioRoutingFailed(
                device: currentMonitoringDevice?.name ?? "System Default",
                reason: error.localizedDescription
            )
        }
        
        monitoringEngine = engine
        monitoringPlayerNode = playerNode
        monitoringFormat = outputFormat
        
        logger.info("Monitoring engine started with format: \(outputFormat)")
    }
    
    /// Tears down the monitoring audio engine.
    private func teardownMonitoringEngine() {
        monitoringPlayerNode?.stop()
        monitoringEngine?.stop()
        
        if let playerNode = monitoringPlayerNode, let engine = monitoringEngine {
            engine.detach(playerNode)
        }
        
        monitoringPlayerNode = nil
        monitoringEngine = nil
        monitoringFormat = nil
        
        logger.debug("Monitoring engine stopped")
    }
    
    /// Schedules an audio buffer for monitoring playback.
    private func scheduleMonitoringBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let playerNode = monitoringPlayerNode,
              let engine = monitoringEngine,
              engine.isRunning else { return }
        
        // Convert buffer to monitoring format if needed
        let bufferToSchedule: AVAudioPCMBuffer
        if let monitoringFormat = monitoringFormat,
           buffer.format.sampleRate != monitoringFormat.sampleRate ||
           buffer.format.channelCount != monitoringFormat.channelCount {
            // Need to convert
            if let converted = convertBufferForMonitoring(buffer, to: monitoringFormat) {
                bufferToSchedule = converted
            } else {
                return // Skip this buffer if conversion fails
            }
        } else {
            bufferToSchedule = buffer
        }
        
        // Schedule buffer for playback
        playerNode.scheduleBuffer(bufferToSchedule, completionHandler: nil)
    }
    
    /// Converts a buffer for monitoring output.
    private func convertBufferForMonitoring(
        _ inputBuffer: AVAudioPCMBuffer,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: outputFormat) else {
            return nil
        }
        
        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        guard status != .error else {
            logger.error("Monitoring buffer conversion failed: \(error?.localizedDescription ?? "Unknown")")
            return nil
        }
        
        return outputBuffer
    }
    
    /// Sets the output device on a monitoring engine.
    private func setMonitoringOutputDevice(_ device: AudioDevice, on engine: AVAudioEngine) throws {
        #if os(macOS)
        let outputNode = engine.outputNode
        let audioUnit = outputNode.audioUnit
        
        guard let au = audioUnit else {
            throw VibeCaptionError.audioRoutingFailed(
                device: device.name,
                reason: "Failed to get audio unit from output node"
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
                reason: "Failed to set output device (error: \(status))"
            )
        }
        
        logger.info("Set monitoring output device to: \(device.name)")
        #endif
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
