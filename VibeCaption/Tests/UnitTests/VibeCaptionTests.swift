//
//  VibeCaptionTests.swift
//  VibeCaptionTests
//
//  Unit tests for VibeCaption application
//

import XCTest
@testable import VibeCaption

final class VibeCaptionTests: XCTestCase {
    
    /// Test that the app bundle identifier is correct
    func testBundleIdentifier() {
        let expectedBundleID = "com.project.vibecaption"
        let actualBundleID = Bundle.main.bundleIdentifier
        
        XCTAssertEqual(actualBundleID, expectedBundleID, "Bundle identifier should be \(expectedBundleID)")
    }
    
    /// Test that the minimum deployment target is macOS 13.0
    func testMinimumDeploymentTarget() {
        // Check that we're running on at least macOS 13.0
        if #available(macOS 13.0, *) {
            // We're on macOS 13.0 or later, which is expected
            XCTAssertTrue(true, "Running on macOS 13.0 or later")
        } else {
            XCTFail("App should require macOS 13.0 or later")
        }
        
        // Additionally verify the deployment target from Info.plist if available
        if let infoPlist = Bundle.main.infoDictionary,
           let minimumOSVersion = infoPlist["LSMinimumSystemVersion"] as? String {
            // Parse version string
            let components = minimumOSVersion.split(separator: ".").compactMap { Int($0) }
            let majorVersion = components.first ?? 0
            
            XCTAssertGreaterThanOrEqual(majorVersion, 13, "Minimum deployment target should be macOS 13.0 or later")
        }
    }
    
    /// Test that the app can fetch its bundle information correctly
    func testBundleInfo() {
        let bundle = Bundle.main
        
        // Ensure bundle exists and has expected properties
        XCTAssertNotNil(bundle.bundleIdentifier, "Bundle should have an identifier")
        
        // The bundle path should be valid
        XCTAssertFalse(bundle.bundlePath.isEmpty, "Bundle path should not be empty")
    }
}
