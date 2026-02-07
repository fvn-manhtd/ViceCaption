//
//  ModelInfo.swift
//  VibeCaption
//
//  Defines the metadata for an AI model.
//

import Foundation

public struct ModelInfo: Codable, Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let version: String
    public let downloadURL: URL
    public let checksum: String // Hex digest (SHA256/SHA1/MD5). Empty means checksum unavailable.
    public let sizeBytes: Int64
    public let isRequired: Bool
    
    public init(
        id: String,
        displayName: String,
        version: String,
        downloadURL: URL,
        checksum: String,
        sizeBytes: Int64,
        isRequired: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.sizeBytes = sizeBytes
        self.isRequired = isRequired
    }
}
