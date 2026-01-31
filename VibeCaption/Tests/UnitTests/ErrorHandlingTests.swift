//
//  ErrorHandlingTests.swift
//  VibeCaptionTests
//
//  Comprehensive unit tests for the error handling system.
//

import XCTest
import Combine
@testable import VibeCaption

// MARK: - VibeCaptionError Tests

final class VibeCaptionErrorTests: XCTestCase {
    
    // MARK: - All Error Cases
    
    /// All possible error cases for testing.
    private var allErrorCases: [VibeCaptionError] {
        [
            .audioRoutingFailed(device: "BlackHole 2ch", reason: "Device not available"),
            .noAudioFramesDetected,
            .blackHoleNotInstalled,
            .inputDeviceMismatch(expected: "BlackHole 2ch", actual: "Built-in Microphone"),
            .modelMissing(modelName: "VibeVoice-ASR"),
            .modelCorrupted(modelName: "NLLB-200", path: "/path/to/model"),
            .modelDownloadFailed(modelName: "VibeVoice-ASR", reason: "Network timeout"),
            .coreMLLoadFailed(modelName: "NLLB-200", reason: "Incompatible architecture"),
            .translationFailed(reason: "Tokenization error"),
            .asrFailed(reason: "Audio format not supported"),
            .outOfMemory
        ]
    }
    
    // MARK: - Localized Description Tests
    
    /// Test that all error cases have non-empty localized descriptions.
    func testAllErrorsHaveLocalizedDescription() {
        for error in allErrorCases {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error \(error) should have non-empty description")
            XCTAssertGreaterThan(description.count, 5, "Description should be meaningful for \(error)")
        }
    }
    
    /// Test specific error descriptions contain expected information.
    func testAudioRoutingFailedDescription() {
        let error = VibeCaptionError.audioRoutingFailed(device: "TestDevice", reason: "TestReason")
        XCTAssertTrue(error.localizedDescription.contains("TestDevice"))
        XCTAssertTrue(error.localizedDescription.contains("TestReason"))
    }
    
    func testInputDeviceMismatchDescription() {
        let error = VibeCaptionError.inputDeviceMismatch(expected: "Expected", actual: "Actual")
        XCTAssertTrue(error.localizedDescription.contains("Expected"))
        XCTAssertTrue(error.localizedDescription.contains("Actual"))
    }
    
    func testModelMissingDescription() {
        let error = VibeCaptionError.modelMissing(modelName: "TestModel")
        XCTAssertTrue(error.localizedDescription.contains("TestModel"))
    }
    
    func testModelCorruptedDescription() {
        let error = VibeCaptionError.modelCorrupted(modelName: "TestModel", path: "/test/path")
        XCTAssertTrue(error.localizedDescription.contains("TestModel"))
    }
    
    // MARK: - Recovery Suggestion Tests
    
    /// Test that all error cases have non-empty recovery suggestions.
    func testAllErrorsHaveRecoverySuggestion() {
        for error in allErrorCases {
            let suggestion = error.recoverySuggestion
            XCTAssertFalse(suggestion.isEmpty, "Error \(error) should have non-empty recovery suggestion")
            XCTAssertGreaterThan(suggestion.count, 10, "Recovery suggestion should be meaningful for \(error)")
        }
    }
    
    /// Test model corrupted includes path in suggestion.
    func testModelCorruptedSuggestionContainsPath() {
        let path = "/custom/test/path"
        let error = VibeCaptionError.modelCorrupted(modelName: "TestModel", path: path)
        XCTAssertTrue(error.recoverySuggestion.contains(path))
    }
    
    // MARK: - Recovery Action Mapping Tests
    
    /// Test audio errors map to setup wizard.
    func testAudioErrorsMappedToSetupWizard() {
        XCTAssertEqual(
            VibeCaptionError.audioRoutingFailed(device: "", reason: "").recoveryAction,
            .openSetupWizard
        )
        XCTAssertEqual(
            VibeCaptionError.blackHoleNotInstalled.recoveryAction,
            .openSetupWizard
        )
        XCTAssertEqual(
            VibeCaptionError.inputDeviceMismatch(expected: "", actual: "").recoveryAction,
            .openSetupWizard
        )
    }
    
    /// Test no audio frames maps to diagnostics.
    func testNoAudioFramesMappedToDiagnostics() {
        XCTAssertEqual(
            VibeCaptionError.noAudioFramesDetected.recoveryAction,
            .openDiagnostics
        )
    }
    
    /// Test model errors map to model management.
    func testModelErrorsMappedToModelManagement() {
        XCTAssertEqual(
            VibeCaptionError.modelMissing(modelName: "").recoveryAction,
            .openModelManagement
        )
        XCTAssertEqual(
            VibeCaptionError.modelCorrupted(modelName: "", path: "").recoveryAction,
            .openModelManagement
        )
        XCTAssertEqual(
            VibeCaptionError.modelDownloadFailed(modelName: "", reason: "").recoveryAction,
            .openModelManagement
        )
    }
    
    /// Test processing errors map to retry.
    func testProcessingErrorsMappedToRetry() {
        XCTAssertEqual(
            VibeCaptionError.coreMLLoadFailed(modelName: "", reason: "").recoveryAction,
            .retry
        )
        XCTAssertEqual(
            VibeCaptionError.translationFailed(reason: "").recoveryAction,
            .retry
        )
        XCTAssertEqual(
            VibeCaptionError.asrFailed(reason: "").recoveryAction,
            .retry
        )
    }
    
    /// Test out of memory has no recovery action.
    func testOutOfMemoryMappedToNone() {
        XCTAssertEqual(VibeCaptionError.outOfMemory.recoveryAction, .none)
    }
    
    // MARK: - Equatable Tests
    
    /// Test same errors are equal.
    func testSameErrorsAreEqual() {
        let error1 = VibeCaptionError.modelMissing(modelName: "ASR")
        let error2 = VibeCaptionError.modelMissing(modelName: "ASR")
        XCTAssertEqual(error1, error2)
    }
    
    /// Test different errors are not equal.
    func testDifferentErrorsAreNotEqual() {
        let error1 = VibeCaptionError.modelMissing(modelName: "ASR")
        let error2 = VibeCaptionError.modelMissing(modelName: "NLLB")
        XCTAssertNotEqual(error1, error2)
    }
}

// MARK: - RecoveryAction Tests

final class RecoveryActionTests: XCTestCase {
    
    /// Test all recovery actions have appropriate button titles.
    func testRecoveryActionsHaveButtonTitles() {
        XCTAssertEqual(RecoveryAction.openSetupWizard.buttonTitle, "Open Setup Wizard")
        XCTAssertEqual(RecoveryAction.openModelManagement.buttonTitle, "Manage Models")
        XCTAssertEqual(RecoveryAction.openDiagnostics.buttonTitle, "Open Diagnostics")
        XCTAssertEqual(RecoveryAction.retry.buttonTitle, "Retry")
        XCTAssertEqual(RecoveryAction.none.buttonTitle, "")
    }
    
    /// Test hasRecoveryButton is correct.
    func testHasRecoveryButton() {
        XCTAssertTrue(RecoveryAction.openSetupWizard.hasRecoveryButton)
        XCTAssertTrue(RecoveryAction.openModelManagement.hasRecoveryButton)
        XCTAssertTrue(RecoveryAction.openDiagnostics.hasRecoveryButton)
        XCTAssertTrue(RecoveryAction.retry.hasRecoveryButton)
        XCTAssertFalse(RecoveryAction.none.hasRecoveryButton)
    }
    
    /// Test all cases are enumerable.
    func testAllCases() {
        XCTAssertEqual(RecoveryAction.allCases.count, 5)
    }
}

// MARK: - ErrorHandler Tests

@MainActor
final class ErrorHandlerTests: XCTestCase {
    
    var sut: ErrorHandler!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = ErrorHandler()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    /// Test initial state has no current error.
    func testInitialStateHasNoError() {
        XCTAssertNil(sut.currentError)
        XCTAssertFalse(sut.showErrorModal)
    }
    
    /// Test initial error log is empty.
    func testInitialErrorLogIsEmpty() {
        XCTAssertTrue(sut.errorLog.isEmpty)
    }
    
    // MARK: - Handle Error Tests
    
    /// Test handleError sets current error.
    func testHandleErrorSetsCurrentError() {
        let error = VibeCaptionError.noAudioFramesDetected
        
        sut.handleError(error)
        
        XCTAssertEqual(sut.currentError, error)
    }
    
    /// Test handleError shows modal.
    func testHandleErrorShowsModal() {
        sut.handleError(.noAudioFramesDetected)
        
        XCTAssertTrue(sut.showErrorModal)
    }
    
    /// Test handleError adds to log.
    func testHandleErrorAddsToLog() {
        let error = VibeCaptionError.noAudioFramesDetected
        
        sut.handleError(error)
        
        XCTAssertEqual(sut.errorLog.count, 1)
        XCTAssertEqual(sut.errorLog.first?.error, error)
    }
    
    /// Test multiple errors are logged.
    func testMultipleErrorsAreLogged() {
        sut.handleError(.noAudioFramesDetected)
        sut.handleError(.outOfMemory)
        sut.handleError(.blackHoleNotInstalled)
        
        XCTAssertEqual(sut.errorLog.count, 3)
    }
    
    /// Test error log has timestamps.
    func testErrorLogHasTimestamps() {
        let beforeTime = Date()
        sut.handleError(.noAudioFramesDetected)
        let afterTime = Date()
        
        guard let entry = sut.errorLog.first else {
            XCTFail("Expected error log entry")
            return
        }
        
        XCTAssertGreaterThanOrEqual(entry.timestamp, beforeTime)
        XCTAssertLessThanOrEqual(entry.timestamp, afterTime)
    }
    
    // MARK: - Dismiss Error Tests
    
    /// Test dismissError clears current error.
    func testDismissErrorClearsCurrentError() {
        sut.handleError(.noAudioFramesDetected)
        
        sut.dismissError()
        
        XCTAssertNil(sut.currentError)
    }
    
    /// Test dismissError hides modal.
    func testDismissErrorHidesModal() {
        sut.handleError(.noAudioFramesDetected)
        
        sut.dismissError()
        
        XCTAssertFalse(sut.showErrorModal)
    }
    
    /// Test dismissError keeps log.
    func testDismissErrorKeepsLog() {
        sut.handleError(.noAudioFramesDetected)
        
        sut.dismissError()
        
        XCTAssertEqual(sut.errorLog.count, 1)
    }
    
    // MARK: - Clear Log Tests
    
    /// Test clearErrorLog removes all entries.
    func testClearErrorLogRemovesAllEntries() {
        sut.handleError(.noAudioFramesDetected)
        sut.handleError(.outOfMemory)
        
        sut.clearErrorLog()
        
        XCTAssertTrue(sut.errorLog.isEmpty)
    }
    
    // MARK: - Recent Errors Tests
    
    /// Test recentErrors returns correct count.
    func testRecentErrorsReturnsCorrectCount() {
        sut.handleError(.noAudioFramesDetected)
        sut.handleError(.outOfMemory)
        sut.handleError(.blackHoleNotInstalled)
        
        let recent = sut.recentErrors(count: 2)
        
        XCTAssertEqual(recent.count, 2)
    }
    
    /// Test recentErrors returns most recent.
    func testRecentErrorsReturnsMostRecent() {
        sut.handleError(.noAudioFramesDetected)
        sut.handleError(.blackHoleNotInstalled)
        
        let recent = sut.recentErrors(count: 1)
        
        XCTAssertEqual(recent.first?.error, .blackHoleNotInstalled)
    }
    
    // MARK: - Observable Tests
    
    /// Test currentError is observable via Combine.
    func testCurrentErrorIsObservable() {
        let expectation = expectation(description: "Error published")
        var receivedError: VibeCaptionError?
        
        sut.$currentError
            .dropFirst() // Skip initial nil
            .sink { error in
                receivedError = error
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        sut.handleError(.outOfMemory)
        
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedError, .outOfMemory)
    }
    
    /// Test showErrorModal is observable via Combine.
    func testShowErrorModalIsObservable() {
        let expectation = expectation(description: "Modal state published")
        var modalShown = false
        
        sut.$showErrorModal
            .dropFirst() // Skip initial false
            .sink { shown in
                modalShown = shown
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        sut.handleError(.outOfMemory)
        
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(modalShown)
    }
    
    // MARK: - Delegate Tests
    
    /// Test executeRecoveryAction calls delegate.
    func testExecuteRecoveryActionCallsDelegate() {
        let mockDelegate = MockErrorHandlerDelegate()
        sut.delegate = mockDelegate
        
        sut.handleError(.blackHoleNotInstalled)
        sut.executeRecoveryAction()
        
        XCTAssertEqual(mockDelegate.executedAction, .openSetupWizard)
    }
    
    /// Test executeRecoveryAction dismisses error.
    func testExecuteRecoveryActionDismissesError() {
        sut.handleError(.blackHoleNotInstalled)
        
        sut.executeRecoveryAction()
        
        XCTAssertNil(sut.currentError)
        XCTAssertFalse(sut.showErrorModal)
    }
}

// MARK: - Mock Delegate

final class MockErrorHandlerDelegate: ErrorHandlerDelegate {
    var executedAction: RecoveryAction?
    
    func executeRecoveryAction(_ action: RecoveryAction) {
        executedAction = action
    }
}

// MARK: - ErrorLogEntry Tests

final class ErrorLogEntryTests: XCTestCase {
    
    /// Test entry has unique ID.
    func testEntryHasUniqueID() {
        let entry1 = ErrorLogEntry(error: .outOfMemory)
        let entry2 = ErrorLogEntry(error: .outOfMemory)
        
        XCTAssertNotEqual(entry1.id, entry2.id)
    }
    
    /// Test entry stores error correctly.
    func testEntryStoresError() {
        let error = VibeCaptionError.blackHoleNotInstalled
        let entry = ErrorLogEntry(error: error)
        
        XCTAssertEqual(entry.error, error)
    }
    
    /// Test entry stores timestamp.
    func testEntryStoresTimestamp() {
        let timestamp = Date()
        let entry = ErrorLogEntry(error: .outOfMemory, timestamp: timestamp)
        
        XCTAssertEqual(entry.timestamp, timestamp)
    }
}
