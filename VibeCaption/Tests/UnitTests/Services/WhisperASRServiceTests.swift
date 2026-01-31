//
//  WhisperASRServiceTests.swift
//  VibeCaption
//
//  Created by VibeCaption AI.
//

import XCTest
@testable import VibeCaption

final class WhisperASRServiceTests: XCTestCase {
    
    var service: WhisperASRService!
    var modelManager: ModelManager!
    var settingsManager: SettingsManager!
    
    override func setUp() {
        super.setUp()
        settingsManager = SettingsManager()
        modelManager = ModelManager(settingsManager: settingsManager)
        service = WhisperASRService(modelManager: modelManager)
    }
    
    override func tearDown() {
        service = nil
        modelManager = nil
        settingsManager = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertFalse(await service.isModelLoaded)
    }
    
    func testLoadModelMissing() async {
        // Ensure no model is loaded/downloaded for a fake ID if possible, 
        // but here we are testing the real service.
        // If we haven't downloaded the model, this should throw modelNotFound.
        
        // This test depends on the state of ModelManager. 
        // Ideally we would mock ModelManager, but it's a concrete class.
        // We catch the error and verify it's the expected type if strictly no model.
        
        do {
            try await service.loadModel()
            // If it succeeds, that means a model was present.
            XCTAssertTrue(await service.isModelLoaded)
        } catch let error as ModelError {
            // Expected if not downloaded
            if case .modelNotFound = error {
                 XCTAssertFalse(await service.isModelLoaded)
            } else if case .invalidInstallation = error {
                 // Also possible
            } else {
                // Other errors might be failures
                print("Model loading failed with: \(error)")
            }
        } catch {
             // ASRServiceError
        }
    }
    
    // Note: Actual transcription tests require a real model file and audio file.
    // Creating a dummy audio segment involves standard arrays.
    
    func testTranscribeWithoutModelThrows() async {
        let audio = AudioSegment(startTime: 0, endTime: 1, audioData: [Float](repeating: 0, count: 16000))
        
        do {
            _ = try await service.transcribe(audio)
            XCTFail("Should throw if model not loaded")
        } catch let error as ASRServiceError {
            XCTAssertEqual(error, .modelNotLoaded)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
