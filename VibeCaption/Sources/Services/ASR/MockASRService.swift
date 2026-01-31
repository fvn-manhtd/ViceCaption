import Foundation

/// Scenarios for configurable mock behavior
enum MockASRScenario: Equatable {
    case successHighConfidence
    case successLowConfidence
    case failure
    case empty
}

enum MockASRError: Error, LocalizedError, Equatable {
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated ASR failure"
        }
    }
}

/// Mock implementation of ASRServiceProtocol for tests/dev
final class MockASRService: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    private(set) var scenario: MockASRScenario
    
    /// Create a mock ASR service
    /// - Parameter scenario: Behavior configuration (success/low/failure/empty)
    init(scenario: MockASRScenario = .successHighConfidence) {
        self.scenario = scenario
    }
    
    func loadModel() async throws {
        // Simulate fast load
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        isModelLoaded = true
    }
    
    func unloadModel() {
        isModelLoaded = false
    }
    
    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        // Simulated latency based on audio length (0.5s - 2.0s)
        let dur = max(0.0, audio.duration)
        let delay = Self.computeDelay(forDuration: dur)
        let start = Date()
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        switch scenario {
        case .failure:
            throw MockASRError.simulatedFailure
        case .empty:
            return ASRResult(segments: [], processingTime: Date().timeIntervalSince(start))
        case .successHighConfidence, .successLowConfidence:
            let segs = makeSegments(for: audio, highConfidence: scenario == .successHighConfidence)
            return ASRResult(segments: segs, processingTime: Date().timeIntervalSince(start))
        }
    }
    
    // MARK: - Helpers
    
    /// Delay computation used by tests to verify timing monotonicity
    static func computeDelay(forDuration duration: TimeInterval) -> TimeInterval {
        let base: TimeInterval = 0.5
        let scaled = min(1.5, max(0, duration) * 0.15) // 0.15s per sec, clamp +1.5s
        return base + scaled // [0.5, 2.0]
    }
    
    private func makeSegments(for audio: AudioSegment, highConfidence: Bool) -> [ASRSegment] {
        // Choose deterministic number of segments based on duration
        let nSegs: Int
        if audio.duration < 1.0 { nSegs = 1 }
        else if audio.duration < 3.0 { nSegs = 2 }
        else { nSegs = 3 }
        
        let textPool: [[String]] = [
            ["こんにちは。"],
            ["こんにちは。", "お元気ですか？"],
            ["今日はいい天気ですね。", "そうですね。", "ありがとうございます。"]
        ]
        let phrases = textPool[max(0, min(textPool.count - 1, nSegs - 1))]
        
        // Deterministic RNG seed based on timing to keep stable across runs
        let seed = stableSeed(start: audio.startTime, end: audio.endTime)
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        // 1-3 speakers
        let speakerCount = max(1, min(3, 1 + Int(rng.next() % 3)))
        
        // Confidence range
        let confBase: Double = highConfidence ? 0.85 : 0.45
        let confSpan: Double = highConfidence ? 0.13 : 0.18
        
        // Split the time range evenly among segments for mock
        let total = max(0.001, audio.duration)
        let segDur = total / Double(nSegs)
        
        var segments: [ASRSegment] = []
        for i in 0..<nSegs {
            let st = audio.startTime + Double(i) * segDur
            let et = i == nSegs - 1 ? audio.endTime : (st + segDur)
            let speakerID = 1 + (i % speakerCount)
            let confidence = min(1.0, max(0.0, confBase + Double(rng.next() % 100) / 100.0 * confSpan))
            let text = phrases[min(i, phrases.count - 1)]
            segments.append(ASRSegment(text: text, startTime: st, endTime: et, speakerID: speakerID, confidence: confidence))
        }
        return segments
    }
}

// MARK: - Deterministic RNG

/// Simple deterministic generator for stable tests
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0xdeadbeef }
    mutating func next() -> UInt64 {
        // xorshift64*
        var x = state
        x &^= x << 13
        x &^= x >> 7
        x &^= x << 17
        state = x
        return x &* 0x2545F4914F6CDD1D
    }
}

private func stableSeed(start: TimeInterval, end: TimeInterval) -> UInt64 {
    let a = UInt64((start * 1_000).rounded())
    let b = UInt64((end * 1_000).rounded())
    return (a &<< 32) ^ b ^ 0x9E3779B97F4A7C15
}

