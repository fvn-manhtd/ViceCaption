//
//  MenuBarController.swift
//  VibeCaption
//
//  Manages the menu bar status item and its menu.
//

import AppKit
import Combine
import SwiftUI

/// Manages the menu bar status item and its associated menu.
///
/// This controller handles:
/// - The status item icon and its states
/// - The menu structure
/// - Dynamic updates to menu items based on application state
/// - Wiring menu actions to the AppStateManager and SettingsManager
class MenuBarController: NSObject {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem!
    private let appStateManager: AppStateManager
    private let settingsManager: SettingsManager
    private let pipeline: CaptionPipeline
    private let openURLHandler: (URL) -> Bool
    private let presentAlert: (String, String) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    // Window Controllers
    private var setupWizardWindow: SetupWizardWindow?
    
    // Menu Items References for dynamic updates
    private weak var toggleOverlayItem: NSMenuItem?
    private weak var toggleListeningItem: NSMenuItem?
    
    // MARK: - Initialization
    
    init(
        appStateManager: AppStateManager,
        settingsManager: SettingsManager,
        pipeline: CaptionPipeline,
        openURLHandler: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        presentAlert: @escaping (String, String) -> Void = { title, message in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    ) {
        self.appStateManager = appStateManager
        self.settingsManager = settingsManager
        self.pipeline = pipeline
        self.openURLHandler = openURLHandler
        self.presentAlert = presentAlert
        super.init()
        
        setupStatusItem()
        setupMenu()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use SF Symbol for the menu bar icon
            if let image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "VibeCaption") {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "VibeCaption"
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false // We handle enabled state manually
        
        // 1. Show/Hide Overlay
        let overlayItem = NSMenuItem(
            title: "Show Overlay",
            action: #selector(toggleOverlay),
            keyEquivalent: "o"
        )
        overlayItem.target = self
        menu.addItem(overlayItem)
        self.toggleOverlayItem = overlayItem
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Start/Stop Listening
        let listeningItem = NSMenuItem(
            title: "Start Listening",
            action: #selector(toggleListening),
            keyEquivalent: " " // Space
        )
        listeningItem.target = self
        menu.addItem(listeningItem)
        self.toggleListeningItem = listeningItem
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Settings
        let settingsItem = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 4. Setup Wizard
        let wizardItem = NSMenuItem(
            title: "Run Setup Wizard…",
            action: #selector(runWizard),
            keyEquivalent: ""
        )
        wizardItem.target = self
        menu.addItem(wizardItem)
        
        // 5. Open Transcript Folder
        let transcriptItem = NSMenuItem(
            title: "Open Transcript Folder",
            action: #selector(openTranscriptFolder),
            keyEquivalent: ""
        )
        transcriptItem.target = self
        menu.addItem(transcriptItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit
        let quitItem = NSMenuItem(
            title: "Quit VibeCaption",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func setupBindings() {
        // Observe AppState changes
        appStateManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateMenuState(for: state)
                self?.updateIconState(for: state)
            }
            .store(in: &cancellables)
        
        // Observe Overlay visibility changes
        appStateManager.$isOverlayVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                self?.updateOverlayMenuItem(isVisible: isVisible)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Updates
    
    private func updateMenuState(for state: AppState) {
        guard let item = toggleListeningItem else { return }
        
        switch state {
        case .idle:
            item.title = "Start Listening"
            // We might want to disable this if models aren't loaded,
            // but currently we don't have a direct stream for 'areModelsLoaded'
            // effectively usable here without polling or similar.
            // Assuming AppStateManager handles the error or we can check property.
            // For now, let's keep it enabled as the user might want to try and see the error.
            item.isEnabled = true
            
        case .listening, .translating, .paused:
            item.title = "Stop Listening"
            item.isEnabled = true
        }
    }
    
    private func updateOverlayMenuItem(isVisible: Bool) {
        toggleOverlayItem?.title = isVisible ? "Hide Overlay" : "Show Overlay"
    }
    
    private func updateIconState(for state: AppState) {
        guard let button = statusItem.button else { return }
        
        // Opacity/Appearance based on state
        switch state {
        case .idle:
            button.alphaValue = 1.0
            button.appearsDisabled = false
            
        case .listening, .translating:
            button.alphaValue = 1.0
            button.appearsDisabled = false
            // Ideally we'd set a color here (e.g. red tint), strictly speaking
            // standard NSStatusItem doesn't easily support arbitrary tinting safely
            // without custom drawing, but we can indicate active state.
            // For MVP, default appearance is okay.
            
        case .paused:
            button.alphaValue = 0.6
            button.appearsDisabled = false // or true for dimmed look
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleOverlay() {
        if appStateManager.isOverlayVisible {
            appStateManager.overlayWillHide()
        } else {
            appStateManager.overlayWillShow()
        }
    }
    
    @objc private func toggleListening() {
        switch appStateManager.currentState {
        case .idle:
            Task {
                do {
                    try await pipeline.start()
                } catch {
                    print("Error starting pipeline: \(error)")
                }
            }
        case .listening, .translating, .paused:
            pipeline.stop(trigger: .manualStop)
        }
    }
    
    @objc private func openSettings() {
        // macOS 13+ Settings Link or legacy window controller
        if #available(macOS 13.0, *) {
             NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
             NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    @objc func runWizard() {
        // Create if needed or show existing
        if setupWizardWindow == nil {
            setupWizardWindow = SetupWizardWindow.create(
                settingsManager: settingsManager,
                audioDeviceManager: AudioDeviceManager.shared,
                completionHandler: { [weak self] in
                    self?.settingsManager.setupWizardCompleted = true
                    self?.setupWizardWindow = nil
                }
            )
        }
        
        setupWizardWindow?.showWizard()
    }
    
    @objc private func openTranscriptFolder() {
        let expandedPath = (settingsManager.transcriptStoragePath as NSString).expandingTildeInPath
        guard settingsManager.validatePath(expandedPath) else {
            presentAlert(
                "Unable to Open Transcript Folder",
                "Could not create transcript directory at \(expandedPath)."
            )
            return
        }

        let url = URL(fileURLWithPath: expandedPath, isDirectory: true)
        guard openURLHandler(url) else {
            presentAlert(
                "Unable to Open Transcript Folder",
                "Finder could not open the transcript directory."
            )
            return
        }
    }
    
    @objc private func quitApp() {
        pipeline.stop(trigger: .appQuit)
        NSApplication.shared.terminate(nil)
    }
}
