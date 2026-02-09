//
//  AudioPreprocessor.swift
//  VibeCaption
//
//  Handles audio preprocessing tasks including sample rate conversion.
//

import Foundation
import AVFoundation
import os.log

// MARK: - AudioPreprocessorProtocol

/// Protocol for audio preprocessing.
public protocol AudioPreprocessorProtocol {
    var outputSampleRate: Double { get }
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer
    func reset()
}

// MARK: - AudioPreprocessor

/// Handles audio preprocessing steps before ASR.
///
/// Responsibilities:
/// - Sample rate conversion (to 16kHz)
/// - (Voice processing/Noise suppression is handled by AVAudioEngine input node configuration)
public final class AudioPreprocessor: AudioPreprocessorProtocol {
    
    // MARK: - Properties
    
    /// Target sample rate for output (default 16kHz).
    public let outputSampleRate: Double
    
    /// Audio format converter.
    private var converter: AVAudioConverter?
    
    /// Target audio format.
    private var targetFormat: AVAudioFormat?
    
    /// Logger instance.
    private let logger = Logger(subsystem: "com.vibecaption", category: "AudioPreprocessor")
    
    // MARK: - Initialization
    
    /// Creates a new audio preprocessor.
    ///
    /// - Parameter outputSampleRate: Target sample rate (default: 16000Hz).
    public init(outputSampleRate: Double = 16000.0) {
        self.outputSampleRate = outputSampleRate
        
        // Create target format (16kHz mono)
        self.targetFormat = AVAudioFormat(
            standardFormatWithSampleRate: outputSampleRate,
            channels: 1
        )
        
        logger.debug("AudioPreprocessor initialized with target rate: \(outputSampleRate)")
    }
    
    // MARK: - Processing
    
    /// Processes an audio buffer (performing sample rate conversion if needed).
    ///
    /// - Parameter buffer: The input audio buffer.
    /// - Returns: Processed buffer (converted to target format/rate).
    public func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // If formats match (sample rate and channels), return original
        if let targetFormat = targetFormat,
           buffer.format.sampleRate == targetFormat.sampleRate,
           buffer.format.channelCount == targetFormat.channelCount {
            return buffer
        }
        
        // Setup converter if needed (or if format changed)
        if converter == nil || !isConverterValid(for: buffer.format) {
            setupConverter(inputFormat: buffer.format)
        }
        
        // Check if we have a valid converter and target format
        guard let converter = converter, let targetFormat = targetFormat else {
            // Fallback: return input buffer if conversion setup fails (shouldn't happen)
            return buffer
        }
        
        return convertBuffer(buffer, using: converter, to: targetFormat) ?? buffer
    }
    
    /// Resets the internal state (e.g. converter).
    public func reset() {
        converter?.reset()
        converter = nil
        logger.debug("AudioPreprocessor reset")
    }
    
    // MARK: - Private Methods
    
    /// Checks if the current converter is valid for the new input format.
    private func isConverterValid(for inputFormat: AVAudioFormat) -> Bool {
        guard let currentInputFormat = converter?.inputFormat else { return false }
        return currentInputFormat.sampleRate == inputFormat.sampleRate &&
               currentInputFormat.channelCount == inputFormat.channelCount
    }
    
    /// Sets up the audio converter.
    private func setupConverter(inputFormat: AVAudioFormat) {
        guard let targetFormat = targetFormat else { return }
        
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        if converter != nil {
            logger.debug("Created converter: \(inputFormat.sampleRate)Hz -> \(targetFormat.sampleRate)Hz")
        } else {
            logger.error("Failed to create audio converter")
        }
    }
    
    /// Converts a buffer to the target format.
    private func convertBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard inputBuffer.frameLength > 0 else {
            return nil
        }

        // Calculate output frame capacity
        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
        
        // Create output buffer
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
            // Only log if it's a real error, sometimes end of stream can cause issues but here we process chunks
             logger.error("Conversion failed: \(error?.localizedDescription ?? "Unknown")")
            return nil
        }

        guard outputBuffer.frameLength > 0 else {
            logger.debug("Converted buffer had zero frames; falling back to input buffer")
            return nil
        }
        
        return outputBuffer
    }
}
