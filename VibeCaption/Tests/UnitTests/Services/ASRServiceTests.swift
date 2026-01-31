import XCTest
@testable import VibeCaption

final class ASRServiceTests: XCTestCase {

    func makeAudioSegment(start: TimeInterval, end: TimeInterval) -> AudioSegment {
        let frames = max(1, Int((end - start) * 16000))
        let data = Array<Float>(repeating: 0.0, count: frames)
        return AudioSegment(startTime: start, endTime: end, audioData: data)
    }

    // MARK: - Mock basic behavior
    func testMockReturnsExpectedResults() async throws {
        let mock = MockASRService(scenario: .successHighConfidence)
        let seg = makeAudioSegment(start: 0, end: 2.0)

        let result = try await mock.transcribe(seg)
        XCTAssertFalse(result.segments.isEmpty)
        XCTAssertGreaterThan(result.processingTime, 0)
        for s in result.segments {
            XCTAssertFalse(s.text.isEmpty)
            XCTAssertGreaterThanOrEqual(s.confidence, 0.7, "High confidence scenario should be >= 0.7")
        }
    }

    func testMockRespectsConfiguredDelays() async throws {
        let mock = MockASRService(scenario: .successLowConfidence)
        let shortSeg = makeAudioSegment(start: 0, end: 0.6)
        let longSeg = makeAudioSegment(start: 0, end: 8.0)

        let t1s = Date()
        _ = try await mock.transcribe(shortSeg)
        let t1 = Date().timeIntervalSince(t1s)

        let t2s = Date()
        _ = try await mock.transcribe(longSeg)
        let t2 = Date().timeIntervalSince(t2s)

        // Short should be around >= 0.5s
        XCTAssertGreaterThanOrEqual(t1, 0.45)
        // Long should be near upper bound ~2.0s
        XCTAssertGreaterThanOrEqual(t2, 1.7)
        // Monotonic: long takes longer than short
        XCTAssertGreaterThan(t2, t1)
    }

    func testMockCanSimulateFailures() async {
        let mock = MockASRService(scenario: .failure)
        let seg = makeAudioSegment(start: 0, end: 1.0)

        do {
            _ = try await mock.transcribe(seg)
            XCTFail("Expected simulated failure")
        } catch let error as MockASRError {
            XCTAssertEqual(error, .simulatedFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFactoryReturnsCorrectImplementation() {
        let s1 = ASRServiceFactory.getService(useMock: true)
        XCTAssertTrue(s1 is MockASRService)

        let s2 = ASRServiceFactory.getService(useMock: false)
        XCTAssertFalse(s2 is MockASRService)
    }

    func testSpeakerIDAssignmentConsistent() async throws {
        let seg = makeAudioSegment(start: 10.0, end: 14.0)
        let mock1 = MockASRService(scenario: .successHighConfidence)
        let mock2 = MockASRService(scenario: .successHighConfidence)

        let r1 = try await mock1.transcribe(seg)
        let r2 = try await mock2.transcribe(seg)

        XCTAssertEqual(r1.segments.count, r2.segments.count)
        for i in 0..<r1.segments.count {
            XCTAssertEqual(r1.segments[i].speakerID, r2.segments[i].speakerID)
            if let spk = r1.segments[i].speakerID {
                XCTAssertTrue((1...3).contains(spk))
            }
        }
    }
}

