//
//  PipelineStatistics.swift
//  VibeCaption
//
//  Tracks latency and throughput for the caption pipeline.
//

import Foundation

public struct PipelineStatistics: Equatable {
    public private(set) var segmentsProcessed: Int
    public private(set) var blocksProcessed: Int
    public private(set) var droppedSegments: Int
    public private(set) var averageLatency: TimeInterval
    public private(set) var lastLatency: TimeInterval
    public private(set) var throughputPerMinute: Double

    private var firstSegmentAt: Date?

    public init(
        segmentsProcessed: Int = 0,
        blocksProcessed: Int = 0,
        droppedSegments: Int = 0,
        averageLatency: TimeInterval = 0,
        lastLatency: TimeInterval = 0,
        throughputPerMinute: Double = 0
    ) {
        self.segmentsProcessed = segmentsProcessed
        self.blocksProcessed = blocksProcessed
        self.droppedSegments = droppedSegments
        self.averageLatency = averageLatency
        self.lastLatency = lastLatency
        self.throughputPerMinute = throughputPerMinute
        self.firstSegmentAt = nil
    }

    public mutating func recordSegment(
        latency: TimeInterval,
        blockCount: Int,
        processedAt: Date = Date()
    ) {
        if firstSegmentAt == nil {
            firstSegmentAt = processedAt
        }

        segmentsProcessed += 1
        blocksProcessed += blockCount
        lastLatency = latency

        let totalLatency = averageLatency * Double(segmentsProcessed - 1) + latency
        averageLatency = totalLatency / Double(segmentsProcessed)

        guard let start = firstSegmentAt else {
            throughputPerMinute = 0
            return
        }

        let elapsedSeconds = max(1.0, processedAt.timeIntervalSince(start))
        let elapsedMinutes = elapsedSeconds / 60.0
        throughputPerMinute = Double(segmentsProcessed) / elapsedMinutes
    }

    public mutating func recordDroppedSegment() {
        droppedSegments += 1
    }

    public mutating func reset() {
        self = PipelineStatistics()
    }
}
