//
//  AudioRingBuffer.swift
//  VibeCaption
//
//  Thread-safe circular buffer for audio samples.
//

import Foundation
import AVFoundation

// MARK: - AudioRingBuffer

/// Thread-safe circular buffer for storing audio samples.
///
/// This buffer is designed for real-time audio processing, allowing
/// concurrent write and read operations from different threads.
/// The buffer uses a circular/ring design to efficiently manage memory.
///
/// Example:
/// ```swift
/// let buffer = AudioRingBuffer(capacity: 48000 * 30) // 30 seconds at 48kHz
/// buffer.write(audioBuffer)
/// if let samples = buffer.read(samples: 1024) {
///     process(samples)
/// }
/// ```
public final class AudioRingBuffer: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The maximum number of samples the buffer can hold.
    public let capacity: Int
    
    /// Internal storage for audio samples.
    private var buffer: [Float]
    
    /// Current write position in the buffer.
    private var writeIndex: Int = 0
    
    /// Current read position in the buffer.
    private var readIndex: Int = 0
    
    /// Number of samples currently available for reading.
    private var samplesAvailable: Int = 0
    
    /// Queue for thread-safe access.
    private let accessQueue = DispatchQueue(
        label: "com.vibecaption.audioringbuffer",
        attributes: .concurrent
    )
    
    // MARK: - Computed Properties
    
    /// Number of samples currently available for reading.
    public var availableSamples: Int {
        accessQueue.sync {
            samplesAvailable
        }
    }
    
    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        availableSamples == 0
    }
    
    /// Whether the buffer is full.
    public var isFull: Bool {
        availableSamples == capacity
    }
    
    /// Amount of free space in samples.
    public var freeSpace: Int {
        capacity - availableSamples
    }
    
    // MARK: - Initialization
    
    /// Creates a new audio ring buffer with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of samples the buffer can hold.
    ///                       Default is 30 seconds at 16kHz (480,000 samples).
    public init(capacity: Int = 16000 * 30) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }
    
    // MARK: - Public Methods
    
    /// Writes audio samples from an AVAudioPCMBuffer to the ring buffer.
    ///
    /// If the buffer is full, older samples will be overwritten (circular behavior).
    /// This method is thread-safe.
    ///
    /// - Parameter audioBuffer: The audio buffer containing samples to write.
    /// - Returns: Number of samples actually written.
    @discardableResult
    public func write(_ audioBuffer: AVAudioPCMBuffer) -> Int {
        guard let channelData = audioBuffer.floatChannelData else {
            return 0
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        guard frameCount > 0 else {
            return 0
        }
        
        // Use first channel (mono) or average channels if stereo
        let channelCount = Int(audioBuffer.format.channelCount)
        var samples = [Float](repeating: 0, count: frameCount)
        
        if channelCount == 1 {
            // Mono: copy directly
            samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        } else {
            // Multi-channel: average to mono
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                samples[i] = sum / Float(channelCount)
            }
        }
        
        return write(samples: samples)
    }
    
    /// Writes an array of samples to the ring buffer.
    ///
    /// If the buffer becomes full, older samples will be overwritten.
    /// This method is thread-safe.
    ///
    /// - Parameter samples: Array of audio samples to write.
    /// - Returns: Number of samples written.
    @discardableResult
    public func write(samples: [Float]) -> Int {
        guard !samples.isEmpty else { return 0 }
        
        return accessQueue.sync(flags: .barrier) {
            let samplesToWrite = samples.count
            
            for i in 0..<samplesToWrite {
                buffer[writeIndex] = samples[i]
                writeIndex = (writeIndex + 1) % capacity
                
                // If we're overwriting unread data, advance read index
                if samplesAvailable == capacity {
                    readIndex = (readIndex + 1) % capacity
                } else {
                    samplesAvailable += 1
                }
            }
            
            return samplesToWrite
        }
    }
    
    /// Reads the specified number of samples from the buffer.
    ///
    /// This method is thread-safe and blocks until enough samples are available
    /// or returns nil if the requested samples exceed available samples.
    ///
    /// - Parameter count: Number of samples to read.
    /// - Returns: Array of samples, or nil if not enough samples available.
    public func read(samples count: Int) -> [Float]? {
        guard count > 0 else { return [] }
        
        return accessQueue.sync(flags: .barrier) {
            guard samplesAvailable >= count else {
                return nil
            }
            
            var result = [Float](repeating: 0, count: count)
            
            for i in 0..<count {
                result[i] = buffer[readIndex]
                readIndex = (readIndex + 1) % capacity
            }
            
            samplesAvailable -= count
            return result
        }
    }
    
    /// Reads all available samples from the buffer.
    ///
    /// This method is thread-safe.
    ///
    /// - Returns: Array of all available samples.
    public func readAll() -> [Float] {
        return accessQueue.sync(flags: .barrier) {
            guard samplesAvailable > 0 else {
                return []
            }
            
            var result = [Float](repeating: 0, count: samplesAvailable)
            
            for i in 0..<samplesAvailable {
                result[i] = buffer[(readIndex + i) % capacity]
            }
            
            readIndex = writeIndex
            samplesAvailable = 0
            return result
        }
    }
    
    /// Peeks at samples without removing them from the buffer.
    ///
    /// - Parameter count: Number of samples to peek.
    /// - Returns: Array of samples, or nil if not enough samples available.
    public func peek(samples count: Int) -> [Float]? {
        guard count > 0 else { return [] }
        
        return accessQueue.sync {
            guard samplesAvailable >= count else {
                return nil
            }
            
            var result = [Float](repeating: 0, count: count)
            
            for i in 0..<count {
                result[i] = buffer[(readIndex + i) % capacity]
            }
            
            return result
        }
    }
    
    /// Clears all samples from the buffer.
    ///
    /// This method is thread-safe.
    public func clear() {
        accessQueue.sync(flags: .barrier) {
            writeIndex = 0
            readIndex = 0
            samplesAvailable = 0
            // Zero out buffer for security
            buffer = [Float](repeating: 0, count: capacity)
        }
    }
    
    /// Discards the specified number of samples from the read end.
    ///
    /// - Parameter count: Number of samples to discard.
    /// - Returns: Number of samples actually discarded.
    @discardableResult
    public func discard(samples count: Int) -> Int {
        guard count > 0 else { return 0 }
        
        return accessQueue.sync(flags: .barrier) {
            let toDiscard = min(count, samplesAvailable)
            readIndex = (readIndex + toDiscard) % capacity
            samplesAvailable -= toDiscard
            return toDiscard
        }
    }
}

// MARK: - CustomStringConvertible

extension AudioRingBuffer: CustomStringConvertible {
    public var description: String {
        "AudioRingBuffer(capacity: \(capacity), available: \(availableSamples), free: \(freeSpace))"
    }
}
