//
//  ModelStatus.swift
//  VibeCaption
//
//  Defines the possible states of a model.
//

import Foundation

public enum ModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case corrupted
    case updateAvailable
    
    public var isReady: Bool {
        if case .downloaded = self { return true }
        return false
    }
    
    public var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}
