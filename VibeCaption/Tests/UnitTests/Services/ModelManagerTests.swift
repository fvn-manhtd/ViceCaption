//
//  ModelManagerTests.swift
//  VibeCaptionTests
//
//  Tests for model download/update behavior and network edge cases.
//

import XCTest
import Foundation
import CryptoKit
@testable import VibeCaption

final class ModelManagerTests: XCTestCase {
    private var modelManager: ModelManager!
    private var settingsManager: SettingsManager!
    private var mockUserDefaults: UserDefaults!
    private var tempModelDirectory: URL!
    private var suiteName: String!

    override func setUp() {
        super.setUp()

        suiteName = "ModelManagerTests_\(UUID().uuidString)"
        mockUserDefaults = UserDefaults(suiteName: suiteName)
        mockUserDefaults.removePersistentDomain(forName: suiteName)

        settingsManager = SettingsManager(userDefaults: mockUserDefaults)
        tempModelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-tests-\(UUID().uuidString)", isDirectory: true)
        settingsManager.modelStoragePath = tempModelDirectory.path

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        modelManager = ModelManager(settingsManager: settingsManager, urlSession: session)

        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        try? FileManager.default.removeItem(at: tempModelDirectory)
        mockUserDefaults.removePersistentDomain(forName: suiteName)

        modelManager = nil
        settingsManager = nil
        mockUserDefaults = nil
        tempModelDirectory = nil
        suiteName = nil

        super.tearDown()
    }

    func testDownloadModelHandlesNetworkLoss() async {
        let model = makeModel(
            id: "network-loss-model",
            checksum: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        MockURLProtocol.responseProvider = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await modelManager.downloadModel(model)
            XCTFail("Expected download to fail due to network loss")
        } catch let error as ModelError {
            guard case .downloadFailed = error else {
                XCTFail("Expected downloadFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await waitForMainQueue()
        XCTAssertEqual(modelManager.modelStatuses[model.id], .notDownloaded)
    }

    func testDownloadModelMarksCorruptedWhenChecksumMismatch() async {
        let model = makeModel(
            id: "checksum-mismatch-model",
            checksum: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        MockURLProtocol.responseProvider = { _ in
            Data("bad-data".utf8)
        }

        do {
            try await modelManager.downloadModel(model)
            XCTFail("Expected verification failure")
        } catch let error as ModelError {
            guard case .verificationFailed = error else {
                XCTFail("Expected verificationFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await waitForMainQueue()
        XCTAssertEqual(modelManager.modelStatuses[model.id], .corrupted)
    }

    func testDownloadModelSuccessMarksDownloadedAndWritesFile() async throws {
        let model = makeModel(
            id: "download-success-model",
            checksum: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let payload = Data("model-bytes".utf8)
        MockURLProtocol.responseProvider = { _ in payload }

        try await modelManager.downloadModel(model)
        await waitForMainQueue()

        XCTAssertEqual(modelManager.modelStatuses[model.id], .downloaded)

        let modelPath = try XCTUnwrap(modelManager.getModelPath(for: model))
        let fileURL = modelPath.appendingPathComponent(model.downloadURL.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testDownloadModelSupportsMD5Checksum() async throws {
        let payload = Data("model-bytes".utf8)
        let model = makeModel(
            id: "md5-checksum-model",
            checksum: md5Hex(payload)
        )

        MockURLProtocol.responseProvider = { _ in payload }

        try await modelManager.downloadModel(model)
        await waitForMainQueue()

        XCTAssertEqual(modelManager.modelStatuses[model.id], .downloaded)
    }

    func testDownloadModelSupportsSHA1Checksum() async throws {
        let payload = Data("model-bytes".utf8)
        let model = makeModel(
            id: "sha1-checksum-model",
            checksum: sha1Hex(payload)
        )

        MockURLProtocol.responseProvider = { _ in payload }

        try await modelManager.downloadModel(model)
        await waitForMainQueue()

        XCTAssertEqual(modelManager.modelStatuses[model.id], .downloaded)
    }

    func testDownloadModelAcceptsMissingChecksumWhenPayloadIsValid() async throws {
        let model = makeModel(
            id: "missing-checksum-model",
            checksum: ""
        )

        MockURLProtocol.responseProvider = { _ in
            Data("plain-binary-model-payload".utf8)
        }

        try await modelManager.downloadModel(model)
        await waitForMainQueue()

        XCTAssertEqual(modelManager.modelStatuses[model.id], .downloaded)
    }

    func testDownloadModelRejectsHTMLPayloadWhenChecksumMissing() async {
        let model = makeModel(
            id: "html-payload-model",
            checksum: ""
        )

        MockURLProtocol.responseProvider = { _ in
            Data("<html><body>Unauthorized</body></html>".utf8)
        }

        do {
            try await modelManager.downloadModel(model)
            XCTFail("Expected verification failure for HTML payload")
        } catch let error as ModelError {
            guard case .verificationFailed = error else {
                XCTFail("Expected verificationFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await waitForMainQueue()
        XCTAssertEqual(modelManager.modelStatuses[model.id], .corrupted)
    }

    func testModelUpdateDetectionFindsInstalledOutdatedModel() {
        let currentModel = ModelInfo(
            id: "whisper",
            displayName: "Whisper",
            version: "1.0.0",
            downloadURL: URL(string: "https://example.com/whisper-1.0.0.bin")!,
            checksum: "abc123",
            sizeBytes: 1_000,
            isRequired: true
        )
        let latestModel = ModelInfo(
            id: "whisper",
            displayName: "Whisper",
            version: "1.2.0",
            downloadURL: URL(string: "https://example.com/whisper-1.2.0.bin")!,
            checksum: "def456",
            sizeBytes: 1_200,
            isRequired: true
        )

        let updates = ModelManager.detectModelUpdates(
            currentCatalog: [currentModel],
            latestCatalog: [latestModel],
            installedStatuses: ["whisper": .downloaded]
        )

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.currentVersion, "1.0.0")
        XCTAssertEqual(updates.first?.latestVersion, "1.2.0")
    }

    func testVersionComparisonLogic() {
        XCTAssertEqual(ModelManager.compareVersions("1.10.0", "1.2.0"), .orderedDescending)
        XCTAssertEqual(ModelManager.compareVersions("2.0", "2.0.0"), .orderedSame)
        XCTAssertEqual(ModelManager.compareVersions("3.0-beta", "3.0"), .orderedAscending)
        XCTAssertEqual(ModelManager.compareVersions("1.0.1", "1.0.9"), .orderedAscending)
    }

    private func makeModel(id: String, checksum: String) -> ModelInfo {
        ModelInfo(
            id: id,
            displayName: id,
            version: "1.0.0",
            downloadURL: URL(string: "https://example.com/\(id).bin")!,
            checksum: checksum,
            sizeBytes: 1024,
            isRequired: true
        )
    }

    private func waitForMainQueue() async {
        await MainActor.run {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func md5Hex(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func sha1Hex(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private final class MockURLProtocol: URLProtocol {
    static var responseProvider: ((URLRequest) throws -> Data)?

    static func reset() {
        responseProvider = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let payload = try Self.responseProvider?(request) ?? Data()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "\(payload.count)"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: payload)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
