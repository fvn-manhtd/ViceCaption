//
//  SettingsWindow.swift
//  VibeCaption
//
//  NSWindow subclass for the Settings panel.
//

import AppKit
import SwiftUI

/// Custom NSWindow for the Settings panel.
///
/// Manages the settings window lifecycle and hosts the SwiftUI SettingsView.
public final class SettingsWindow: NSWindow {
    
    // MARK: - Properties
    
    private var settingsManager: SettingsManager
    private var audioDeviceManager: AudioDeviceManager
    private var modelManager: ModelManager
    private var appStateManager: AppStateManager
    
    // MARK: - Initialization
    
    /// Creates a new SettingsWindow with required dependencies.
    ///
    /// - Parameters:
    ///   - settingsManager: The settings manager for persistence
    ///   - audioDeviceManager: The audio device manager for device enumeration
    ///   - modelManager: The model manager for AI model management
    ///   - appStateManager: The app state manager for state tracking
    public init(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        modelManager: ModelManager,
        appStateManager: AppStateManager
    ) {
        self.settingsManager = settingsManager
        self.audioDeviceManager = audioDeviceManager
        self.modelManager = modelManager
        self.appStateManager = appStateManager
        
        let contentRect = NSRect(x: 0, y: 0, width: 520, height: 420)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        attachContent()
    }
    
    // MARK: - Configuration
    
    private func configureWindow() {
        self.title = "VibeCaption Settings"
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 480, height: 380)
        self.maxSize = NSSize(width: 700, height: 600)
        
        // Standard window behavior
        self.collectionBehavior = [.managed]
    }
    
    private func attachContent() {
        let settingsView = SettingsView(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            modelManager: modelManager,
            appStateManager: appStateManager
        )
        
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hostingView
    }
    
    // MARK: - Factory Method
    
    /// Creates and configures a SettingsWindow instance.
    ///
    /// - Parameters:
    ///   - settingsManager: The settings manager
    ///   - audioDeviceManager: The audio device manager
    ///   - modelManager: The model manager
    ///   - appStateManager: The app state manager
    /// - Returns: A configured SettingsWindow ready for display
    public static func create(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        modelManager: ModelManager,
        appStateManager: AppStateManager
    ) -> SettingsWindow {
        return SettingsWindow(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            modelManager: modelManager,
            appStateManager: appStateManager
        )
    }
    
    // MARK: - Public Methods
    
    /// Shows the settings window and brings it to front.
    public func showSettings() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
