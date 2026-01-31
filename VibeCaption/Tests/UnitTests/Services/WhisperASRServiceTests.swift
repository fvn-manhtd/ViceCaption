//
//  WhisperASRServiceTests.swift
//  VibeCaptionTests
//
//  Created by VibeCaption AI.
//

import XCTest
@testable import VibeCaption

class WhisperASRServiceTests: XCTestCase {
    var modelManager: ModelManager!
    var service: WhisperASRService!
    var settingsManager: SettingsManager!
    var tempStorageURL: URL!
    
    override func setUpWithError() throws {
        // Setup simple temp storage
        tempStorageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempStorageURL, withIntermediateDirectories: true)
        
        let defaults = UserDefaults(suiteName: "WhisperTests")!
        defaults.removePersistentDomain(forName: "WhisperTests")
        
        settingsManager = SettingsManager(userDefaults: defaults)
        settingsManager.modelStoragePath = tempStorageURL.path
        
        modelManager = ModelManager(settingsManager: settingsManager)
        modelManager.loadModelCatalog()
        
        service = WhisperASRService(modelManager: modelManager)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempStorageURL)
        if let defaults = UserDefaults(suiteName: "WhisperTests") {
            defaults.removePersistentDomain(forName: "WhisperTests")
        }
    }
    
    func testLoadModel_MissingModel_Throws() async {
        // Ensure no file exists at expected path (default state of temp dir)
        
        do {
            try await service.loadModel()
            XCTFail("Should throw when model is missing")
        } catch let error as ModelError {
            // Verify it is notFound or invalidInstallation which are handled by ModelManager/Service
            switch error {
            case .modelNotFound, .invalidInstallation:
                break // Success
            default:
                XCTFail("Unexpected ModelError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testLoadModel_InvalidFile_Throws() async throws {
        // 1. Find expected path for the whisper model
        guard let modelID = modelManager.getASRModelID(),
              let info = modelManager.getModel(id: modelID),
              let path = modelManager.getModelPath(for: info) else {
            XCTFail("Could not determine model path")
            return
        }
        
        // 2. Ensure parent dir exists
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // 3. Write dummy file (invalid model content)
        try "dummy invalid binary content".write(to: path, atomically: true, encoding: .utf8)
        
        // 4. Try loading
        do {
            try await service.loadModel()
            XCTFail("Should throw on invalid model file")
        } catch ASRServiceError.initializationFailed {
             // Success
        } catch {
             XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testTranscribe_ModelNotLoaded_Throws() async {
        // Create dummy audio (1 second silence)
        let audio = AudioSegment(
            startTime: 0,
            endTime: 1,
            audioData: [Float](repeating: 0, count: 16000)
        )
        
        do {
            let _ = try await service.transcribe(audio)
            XCTFail("Should throw if model not loaded")
        } catch ASRServiceError.modelNotLoaded {
            // Success
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
    
    // NOTE: Successful transcription tests require a valid ggml model file (~150MB).
    // These are best run as integration tests or manually verify during development.
}
