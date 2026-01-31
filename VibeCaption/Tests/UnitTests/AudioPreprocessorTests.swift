//
//  AudioPreprocessorTests.swift
//  VibeCaptionTests
//
//  Tests for AudioPreprocessor.
//

import XCTest
import AVFoundation
@testable import VibeCaption

final class AudioPreprocessorTests: XCTestCase {
    
    var preprocessor: AudioPreprocessor!
    
    override func setUp() {
        super.setUp()
        preprocessor = AudioPreprocessor(outputSampleRate: 16000.0)
    }
    
    override func tearDown() {
        preprocessor = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(preprocessor.outputSampleRate, 16000.0)
    }
    
    // MARK: - Processing Tests
    
    func testProcessPassthrough() {
        // Create 16kHz buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000.0, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        let output = preprocessor.process(buffer)
        
        // Should be same instance or same format
        XCTAssertEqual(output.format.sampleRate, 16000.0)
        XCTAssertEqual(output.frameLength, 1024)
    }
    
    func testProcessConversion() {
        // Create 44.1kHz buffer
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!
        let sampleCount = 44100 // 1 second
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        // Fill with silence (or dummy data)
        for i in 0..<Int(buffer.frameLength) {
            buffer.floatChannelData?[0][i] = 0.5 * sin(Float(i) / 100.0)
        }
        
        let output = preprocessor.process(buffer)
        
        // Should be 16kHz
        XCTAssertEqual(output.format.sampleRate, 16000.0)
        
        // Expected frames: 44100 * (16000/44100) = 16000
        // Allow variance due to rounding
        XCTAssertEqual(output.frameLength, 16000, accuracy: 10)
    }
    
    func testReset() {
        // Just verify it doesn't crash
        preprocessor.reset()
    }
}
