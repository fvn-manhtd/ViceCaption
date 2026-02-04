//
//  SetupWizardWindow.swift
//  VibeCaption
//
//  NSWindow subclass for the first-run Setup Wizard.
//

import AppKit
import SwiftUI

/// Custom NSWindow for the Setup Wizard.
///
/// Manages the wizard window lifecycle and hosts the SwiftUI SetupWizardView.
public final class SetupWizardWindow: NSWindow {
    
    // MARK: - Properties
    
    private var settingsManager: SettingsManager
    private var audioDeviceManager: AudioDeviceManager
    private var completionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new SetupWizardWindow with required dependencies.
    ///
    /// - Parameters:
    ///   - settingsManager: The settings manager for persistence
    ///   - audioDeviceManager: The audio device manager for device enumeration
    ///   - completionHandler: Optional closure called when wizard completes
    public init(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        completionHandler: (() -> Void)? = nil
    ) {
        self.settingsManager = settingsManager
        self.audioDeviceManager = audioDeviceManager
        self.completionHandler = completionHandler
        
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 500)
        
        super.init(
            contentRect: contentRect,
            // Not closable by default to encourage completion, but minimizable
            styleMask: [.titled, .miniaturizable], 
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        attachContent()
    }
    
    // MARK: - Configuration
    
    private func configureWindow() {
        self.title = "VibeCaption Setup"
        self.center()
        self.isReleasedWhenClosed = false
        
        // Fixed size for wizard
        self.minSize = NSSize(width: 600, height: 500)
        self.maxSize = NSSize(width: 600, height: 500)
        
        // Standard window behavior
        self.collectionBehavior = [.managed, .fullScreenAuxiliary]
    }
    
    private func attachContent() {
        let wizardView = SetupWizardView(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            onClose: { [weak self] in
                self?.close()
            },
            onComplete: { [weak self] in
                self?.completionHandler?()
                self?.close()
            }
        )
        
        let hostingView = NSHostingView(rootView: wizardView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hostingView
    }
    
    // MARK: - Factory Method
    
    /// Creates and configures a SetupWizardWindow instance.
    ///
    /// - Parameters:
    ///   - settingsManager: The settings manager
    ///   - audioDeviceManager: The audio device manager
    ///   - completionHandler: Optional closure called when wizard completes
    /// - Returns: A configured SetupWizardWindow ready for display
    public static func create(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        completionHandler: (() -> Void)? = nil
    ) -> SetupWizardWindow {
        return SetupWizardWindow(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            completionHandler: completionHandler
        )
    }
    
    // MARK: - Public Methods
    
    /// Shows the wizard window and brings it to front.
    public func showWizard() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
