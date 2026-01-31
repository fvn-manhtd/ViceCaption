//
//  VibeCaptionApp.swift
//  VibeCaption
//
//  A macOS menu bar app that captures system audio, performs on-device
//  Japanese speech recognition, and translates to English with a floating overlay.
//

import SwiftUI
import AppKit
import os.log

/// The main entry point for the VibeCaption application.
/// This app runs as a menu bar application without a dock icon.
@main
struct VibeCaptionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Using Settings for a minimal scene - the app is primarily menu bar driven
        Settings {
            EmptyView()
        }
    }
}

/// AppDelegate handles the menu bar functionality and app lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption", category: "AppDelegate")
    
    /// The application state manager - single source of truth for app state.
    private(set) var appStateManager: AppStateManager!
    
    /// The settings manager
    private(set) var settingsManager: SettingsManager!
    
    /// The menu bar controller
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("VibeCaption launched")
        
        // Hide dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the state manager
        setupManagers()
        
        // Initialize audio device detection
        setupAudioDevices()
        
        // Setup Menu Bar Controller
        menuBarController = MenuBarController(
            appStateManager: appStateManager,
            settingsManager: settingsManager
        )
    }
    
    /// Sets up the AppStateManager and SettingsManager
    private func setupManagers() {
        // Initialize Settings Manager
        settingsManager = SettingsManager()
        
        // Initialize App State Manager
        appStateManager = AppStateManager()
        
        // Subscribe to state changes for debugging
        appStateManager.onStateChange = { [weak self] oldState, newState in
            self?.logger.info("App state changed: \(oldState.displayName) → \(newState.displayName)")
        }
        
        logger.debug("Managers initialized, current state: \(self.appStateManager.currentState.displayName)")
    }
    
    /// Sets up audio device detection and logs available devices
    private func setupAudioDevices() {
        let audioManager = AudioDeviceManager.shared
        
        // Refresh devices (also done automatically on init, but ensures latest)
        audioManager.refreshDevices()
        
        // Log detected devices
        logger.info("=== Audio Devices Detected ===")
        
        logger.info("Input Devices (\(audioManager.inputDevices.count)):")
        for device in audioManager.inputDevices {
            let blackHoleTag = device.isBlackHole ? " (BlackHole)" : ""
            logger.info("  - \(device.name) [\(device.uid)]\(blackHoleTag)")
        }
        
        logger.info("Output Devices (\(audioManager.outputDevices.count)):")
        for device in audioManager.outputDevices {
            logger.info("  - \(device.name) [\(device.uid)]")
        }
        
        // Log BlackHole status
        if audioManager.isBlackHoleInstalled() {
            if let blackHoleDevice = audioManager.getBlackHoleInputDevice() {
                logger.info("✓ BlackHole detected: \(blackHoleDevice.name)")
            }
        } else {
            logger.warning("⚠ BlackHole is NOT installed. System audio capture will not work.")
        }
        
        // Log default devices
        if let defaultInput = audioManager.getDefaultInputDevice() {
            logger.debug("Default input device: \(defaultInput.name)")
        }
        if let defaultOutput = audioManager.getDefaultOutputDevice() {
            logger.debug("Default output device: \(defaultOutput.name)")
        }
        
        logger.info("=== End Audio Devices ===")
    }
}
