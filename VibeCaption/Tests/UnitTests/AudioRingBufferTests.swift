//
//  AudioRingBufferTests.swift
//  VibeCaptionTests
//
//  Unit tests for AudioRingBuffer.
//

import XCTest
import AVFoundation
@testable import VibeCaption

// MARK: - AudioRingBuffer Tests

final class AudioRingBufferTests: XCTestCase {
    
    var sut: AudioRingBuffer!
    
    override func setUp() {
        super.setUp()
        sut = AudioRingBuffer(capacity: 1000)
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    /// Test that buffer initializes with correct capacity.
    func testInitializationWithCapacity() {
        let buffer = AudioRingBuffer(capacity: 500)
        XCTAssertEqual(buffer.capacity, 500)
        XCTAssertEqual(buffer.availableSamples, 0)
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertFalse(buffer.isFull)
    }
    
    /// Test default initialization uses 30 seconds at 16kHz.
    func testDefaultInitialization() {
        let buffer = AudioRingBuffer()
        XCTAssertEqual(buffer.capacity, 16000 * 30)
    }
    
    // MARK: - Write/Read Tests
    
    /// Test basic write and read operations.
    func testWriteAndReadSamples() {
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        
        let written = sut.write(samples: samples)
        XCTAssertEqual(written, 5)
        XCTAssertEqual(sut.availableSamples, 5)
        
        let readSamples = sut.read(samples: 5)
        XCTAssertNotNil(readSamples)
        XCTAssertEqual(readSamples!, samples, accuracy: 0.0001)
        XCTAssertEqual(sut.availableSamples, 0)
    }
    
    /// Test partial read.
    func testPartialRead() {
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        sut.write(samples: samples)
        
        let firstRead = sut.read(samples: 2)
        XCTAssertNotNil(firstRead)
        XCTAssertEqual(firstRead!, [0.1, 0.2], accuracy: 0.0001)
        XCTAssertEqual(sut.availableSamples, 3)
        
        let secondRead = sut.read(samples: 3)
        XCTAssertNotNil(secondRead)
        XCTAssertEqual(secondRead!, [0.3, 0.4, 0.5], accuracy: 0.0001)
        XCTAssertEqual(sut.availableSamples, 0)
    }
    
    /// Test read returns nil when not enough samples.
    func testReadReturnsNilWhenNotEnoughSamples() {
        sut.write(samples: [0.1, 0.2, 0.3])
        
        let result = sut.read(samples: 5)
        XCTAssertNil(result)
        // Samples should still be in buffer
        XCTAssertEqual(sut.availableSamples, 3)
    }
    
    /// Test read with zero samples returns empty array.
    func testReadZeroSamplesReturnsEmptyArray() {
        let result = sut.read(samples: 0)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isEmpty)
    }
    
    /// Test readAll returns all samples.
    func testReadAllReturnsAllSamples() {
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        sut.write(samples: samples)
        
        let result = sut.readAll()
        XCTAssertEqual(result, samples, accuracy: 0.0001)
        XCTAssertEqual(sut.availableSamples, 0)
    }
    
    /// Test readAll on empty buffer returns empty array.
    func testReadAllOnEmptyBufferReturnsEmptyArray() {
        let result = sut.readAll()
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Peek Tests
    
    /// Test peek does not remove samples.
    func testPeekDoesNotRemoveSamples() {
        let samples: [Float] = [0.1, 0.2, 0.3]
        sut.write(samples: samples)
        
        let peeked = sut.peek(samples: 3)
        XCTAssertNotNil(peeked)
        XCTAssertEqual(peeked!, samples, accuracy: 0.0001)
        XCTAssertEqual(sut.availableSamples, 3)
        
        // Can still read the samples
        let read = sut.read(samples: 3)
        XCTAssertEqual(read!, samples, accuracy: 0.0001)
    }
    
    /// Test peek returns nil when not enough samples.
    func testPeekReturnsNilWhenNotEnoughSamples() {
        sut.write(samples: [0.1, 0.2])
        let result = sut.peek(samples: 5)
        XCTAssertNil(result)
    }
    
    // MARK: - Overflow Tests
    
    /// Test buffer overflow wraps around correctly.
    func testBufferOverflowWrapsAround() {
        let buffer = AudioRingBuffer(capacity: 5)
        
        // Write 3 samples
        buffer.write(samples: [1.0, 2.0, 3.0])
        XCTAssertEqual(buffer.availableSamples, 3)
        
        // Write 4 more (should overwrite first 2)
        buffer.write(samples: [4.0, 5.0, 6.0, 7.0])
        XCTAssertEqual(buffer.availableSamples, 5) // Buffer is full
        
        // Read should return the last 5 samples written
        let result = buffer.readAll()
        XCTAssertEqual(result, [3.0, 4.0, 5.0, 6.0, 7.0], accuracy: 0.0001)
    }
    
    /// Test buffer maintains FIFO order when not overflowing.
    func testBufferMaintainsFIFOOrder() {
        for i in 0..<100 {
            sut.write(samples: [Float(i)])
        }
        
        for i in 0..<100 {
            let sample = sut.read(samples: 1)
            XCTAssertNotNil(sample)
            XCTAssertEqual(sample![0], Float(i), accuracy: 0.0001)
        }
    }
    
    // MARK: - Clear Tests
    
    /// Test clear resets buffer.
    func testClearResetsBuffer() {
        sut.write(samples: [0.1, 0.2, 0.3, 0.4, 0.5])
        XCTAssertEqual(sut.availableSamples, 5)
        
        sut.clear()
        
        XCTAssertEqual(sut.availableSamples, 0)
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.freeSpace, sut.capacity)
    }
    
    // MARK: - Discard Tests
    
    /// Test discard removes samples from read end.
    func testDiscardRemovesSamples() {
        sut.write(samples: [0.1, 0.2, 0.3, 0.4, 0.5])
        
        let discarded = sut.discard(samples: 2)
        XCTAssertEqual(discarded, 2)
        XCTAssertEqual(sut.availableSamples, 3)
        
        let remaining = sut.readAll()
        XCTAssertEqual(remaining, [0.3, 0.4, 0.5], accuracy: 0.0001)
    }
    
    /// Test discard more than available.
    func testDiscardMoreThanAvailable() {
        sut.write(samples: [0.1, 0.2, 0.3])
        
        let discarded = sut.discard(samples: 10)
        XCTAssertEqual(discarded, 3)
        XCTAssertEqual(sut.availableSamples, 0)
    }
    
    // MARK: - Thread Safety Tests
    
    /// Test concurrent write operations.
    func testConcurrentWriteOperations() {
        let expectation = expectation(description: "Concurrent writes")
        let iterations = 100
        let samplesPerWrite: [Float] = [0.1, 0.2, 0.3]
        
        let writeQueue = DispatchQueue(label: "write", attributes: .concurrent)
        let group = DispatchGroup()
        
        for _ in 0..<iterations {
            group.enter()
            writeQueue.async {
                self.sut.write(samples: samplesPerWrite)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Should have written some samples (exact count depends on timing and overflow)
            XCTAssertGreaterThan(self.sut.availableSamples, 0)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    /// Test concurrent read and write operations.
    func testConcurrentReadAndWrite() {
        let expectation = expectation(description: "Concurrent read/write")
        let iterations = 100
        let buffer = AudioRingBuffer(capacity: 10000)
        
        let writeQueue = DispatchQueue(label: "write")
        let readQueue = DispatchQueue(label: "read")
        let group = DispatchGroup()
        
        var readCount = 0
        
        // Start continuous writes
        for i in 0..<iterations {
            group.enter()
            writeQueue.async {
                buffer.write(samples: Array(repeating: Float(i), count: 10))
                group.leave()
            }
        }
        
        // Start concurrent reads
        for _ in 0..<iterations {
            group.enter()
            readQueue.async {
                if let samples = buffer.read(samples: 5) {
                    readCount += samples.count
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Just verify no crash occurred
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Properties Tests
    
    /// Test isEmpty property.
    func testIsEmptyProperty() {
        XCTAssertTrue(sut.isEmpty)
        
        sut.write(samples: [0.1])
        XCTAssertFalse(sut.isEmpty)
        
        _ = sut.read(samples: 1)
        XCTAssertTrue(sut.isEmpty)
    }
    
    /// Test isFull property.
    func testIsFullProperty() {
        let buffer = AudioRingBuffer(capacity: 3)
        
        XCTAssertFalse(buffer.isFull)
        
        buffer.write(samples: [0.1, 0.2, 0.3])
        XCTAssertTrue(buffer.isFull)
        
        _ = buffer.read(samples: 1)
        XCTAssertFalse(buffer.isFull)
    }
    
    /// Test freeSpace property.
    func testFreeSpaceProperty() {
        XCTAssertEqual(sut.freeSpace, 1000)
        
        sut.write(samples: Array(repeating: 0.0, count: 300))
        XCTAssertEqual(sut.freeSpace, 700)
        
        _ = sut.read(samples: 100)
        XCTAssertEqual(sut.freeSpace, 800)
    }
    
    // MARK: - Description Tests
    
    /// Test CustomStringConvertible.
    func testDescription() {
        sut.write(samples: [0.1, 0.2, 0.3])
        let description = sut.description
        
        XCTAssertTrue(description.contains("1000"))
        XCTAssertTrue(description.contains("3"))
    }
}

// MARK: - Helper Extensions

extension Array where Element == Float {
    static func == (lhs: [Float], rhs: [Float], accuracy: Float) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if abs(lhs[i] - rhs[i]) > accuracy {
                return false
            }
        }
        return true
    }
}

extension XCTestCase {
    func XCTAssertEqual(_ lhs: [Float], _ rhs: [Float], accuracy: Float, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(lhs.count, rhs.count, "Array counts differ", file: file, line: line)
        for i in 0..<lhs.count {
            XCTAssertEqual(lhs[i], rhs[i], accuracy: accuracy, "Values differ at index \(i)", file: file, line: line)
        }
    }
}
