import XCTest
import AVFoundation
@testable import VibeCaption

final class VADTests: XCTestCase {
    
    var vad: VoiceActivityDetector!
    
    override func setUp() {
        super.setUp()
        vad = VoiceActivityDetector()
    }
    
    override func tearDown() {
        vad = nil
        super.tearDown()
    }
    
    // Helper to create silence buffer
    func createSilentBuffer(frameCount: Int = 512) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            channelData[i] = 0.0
        }
        
        return buffer
    }
    
    // Helper to create loud noise buffer
    func createLoudBuffer(frameCount: Int = 512) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            // Sine wave with amplitude 0.5 (quite loud, > threshold)
            channelData[i] = 0.5 * sin(Float(i) * 0.1)
        }
        
        return buffer
    }

    func testInitialState() {
        XCTAssertFalse(vad.isSpeechDetected)
    }
    
    func testSilenceDetection() {
        let buffer = createSilentBuffer()
        let result = vad.process(buffer)
        
        // Initial silence processing might be uncertain or silence depending on internal state
        // But eventually it should be silence
        // Depending on VAD logic, first frame might be silence directly if counters are 0
        XCTAssertEqual(result, .silence)
        XCTAssertFalse(vad.isSpeechDetected)
    }
    
    func testSpeechDetectionWaitTimes() {
        // Feed loud audio. VAD requires N consecutive frames to switch to speech.
        let loudBuffer = createLoudBuffer()
        
        // 1st frame: above threshold, but counter = 1 (need 3)
        var result = vad.process(loudBuffer)
        // Should effectively stay in previous state (silence) or transition
        // Based on my implementation: "result = isSpeechDetected ? .speech : .silence"
        XCTAssertEqual(result, .silence)
        XCTAssertFalse(vad.isSpeechDetected)
        
        // 2nd frame
        result = vad.process(loudBuffer)
        XCTAssertEqual(result, .silence)
        
        // 3rd frame - should now trigger speech
        result = vad.process(loudBuffer)
        XCTAssertEqual(result, .speech)
        XCTAssertTrue(vad.isSpeechDetected)
    }

    func testModerateSpeechLevelTriggersSpeechWithDefaultThresholds() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        buffer.frameLength = 512

        let channelData = buffer.floatChannelData![0]
        for i in 0..<512 {
            channelData[i] = 0.03 * sin(Float(i) * 0.1)
        }

        _ = vad.process(buffer)
        _ = vad.process(buffer)
        let result = vad.process(buffer)

        XCTAssertEqual(result, .speech)
        XCTAssertTrue(vad.isSpeechDetected)
    }
    
    func testSilenceHysteresis() {
        // First get into speech state
        let loudBuffer = createLoudBuffer()
        for _ in 0..<5 {
            _ = vad.process(loudBuffer)
        }
        XCTAssertTrue(vad.isSpeechDetected)
        
        // Now feed silence. Needs N frames to switch back to silence.
        let silentBuffer = createSilentBuffer()
        
        // Feed 1 silence frame
        var result = vad.process(silentBuffer)
        XCTAssertEqual(result, .speech) // Still holding speech
        
        // Feed more silence frames (assuming requiredSilenceFrames = 10)
        for _ in 0..<8 {
            _ = vad.process(silentBuffer)
        }
        XCTAssertTrue(vad.isSpeechDetected)
        
        // Final silence frame to tip the scale
        result = vad.process(silentBuffer)
        // With 1+8+1 = 10 frames? 
        // Let's just loop enough times to be sure
         for _ in 0..<5 {
            result = vad.process(silentBuffer)
        }

        XCTAssertEqual(result, .silence)
        XCTAssertFalse(vad.isSpeechDetected)
    }
    
    func testReset() {
        // Trigger speech
        let loudBuffer = createLoudBuffer()
        for _ in 0..<5 { _ = vad.process(loudBuffer) }
        XCTAssertTrue(vad.isSpeechDetected)
        
        vad.reset()
        XCTAssertFalse(vad.isSpeechDetected)
    }

    func testZeroLengthBufferReturnsStableState() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        buffer.frameLength = 0

        let result = vad.process(buffer)
        XCTAssertEqual(result, .silence)
        XCTAssertFalse(vad.isSpeechDetected)
    }
}
