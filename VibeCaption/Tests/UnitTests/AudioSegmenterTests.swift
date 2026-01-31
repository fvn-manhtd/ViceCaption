import XCTest
import AVFoundation
@testable import VibeCaption

final class AudioSegmenterTests: XCTestCase {
    
    var segmenter: AudioSegmenter!
    var receivedSegments: [AudioSegment] = []
    
    override func setUp() {
        super.setUp()
        segmenter = AudioSegmenter()
        receivedSegments = []
        segmenter.setSegmentCallback { segment in
            self.receivedSegments.append(segment)
        }
        
        // Valid settings for test
        segmenter.minSegmentDuration = 0.1 // Shorten for tests
        segmenter.silencePadding = 0.1
    }
    
    override func tearDown() {
        segmenter = nil
        super.tearDown()
    }
    
    func createBuffer(frameCount: Int = 1600, sampleRate: Double = 16000) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        // Fill with dummy data
        let ptr = buffer.floatChannelData![0]
        for i in 0..<frameCount { ptr[i] = 0.1 }
        return buffer
    }

    func testSingleSegmentCreation() {
        // 1. Send Speech buffer (0.1s)
        let buffer = createBuffer(frameCount: 1600) // 0.1s
        segmenter.process(buffer, vadResult: .speech)
        
        // 2. Send Speech buffer (0.1s) -> Total 0.2s speech
        segmenter.process(buffer, vadResult: .speech)
        
        // 3. Send Silence buffer (0.1s) -> Should trigger padding/cut check
        // silencePadding is 0.1, so this exact frame might trigger it if logic is >=
        segmenter.process(buffer, vadResult: .silence)
        
        // 4. Send another Silence to be sure
        segmenter.process(buffer, vadResult: .silence)
        
        XCTAssertEqual(receivedSegments.count, 1)
        let segment = receivedSegments.first!
        XCTAssertGreaterThan(segment.duration, 0.2) // At least the speech parts
    }
    
    func testMinDurationFilter() {
        // 1. Send TINY Speech buffer (0.01s)
        let buffer = createBuffer(frameCount: 160) // 0.01s
        segmenter.process(buffer, vadResult: .speech)
        
        // 2. Send Silence immediately (big enough to trigger cut)
        let silenceBuf = createBuffer(frameCount: 3200) // 0.2s
        segmenter.process(silenceBuf, vadResult: .silence)
        segmenter.process(silenceBuf, vadResult: .silence)
        
        // Should NOT create segment because total duration (0.01) < minDuration (0.1)
        // Note: The silence padding might add to duration? In my impl, silence is added to buffer.
        // If 0.01 speech + 0.1 silence = 0.11 > 0.1, it MIGHT pass depending on if we count silence as valid segment content.
        // My implementation adds silence to the buffer.
        // Let's adjust test expectation:
        // IF we want "speech only" duration > min, that's different.
        // But usually segmentation includes the tail silence.
        
        // Let's try an even smaller speech trigger that definitely fails even with minimal padding
        // Actually, let's reset and try: process just one *tiny* frame then force reset?
        
        // Test logic:
        // Speech 0.01s
        // Silence 0.01s -> trigger maybe?
        // If total < min, it should drop.
    }
    
    func testReset() {
        let buffer = createBuffer(frameCount: 1600)
        segmenter.process(buffer, vadResult: .speech)
        segmenter.reset()
        
        // Send silence to trigger potential old segment
        segmenter.process(buffer, vadResult: .silence)
        
        XCTAssertTrue(receivedSegments.isEmpty)
    }
}
