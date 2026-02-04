//
//  VibeCaptionApp.swift
//  VibeCaption
//
//  A macOS menu bar app that captures system audio, performs on-device
//  Japanese speech recognition, and translates to English with a floating overlay.
//

import SwiftUI
import AppKit
import Combine
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
    
    /// The transcript manager powering the overlay content
    private(set) var transcriptManager: TranscriptManager!
    
    /// The menu bar controller
    private var menuBarController: MenuBarController?
    
    /// The overlay window components
    private var overlayViewModel: OverlayViewModel?
    private var overlayWindow: OverlayWindow?
    
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("VibeCaption launched")
        
        // Hide dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the state manager
        setupManagers()
        
        // Initialize audio device detection
        setupAudioDevices()
        
        // Setup Overlay
        setupOverlay()
        
        // Setup Menu Bar Controller
        menuBarController = MenuBarController(
            appStateManager: appStateManager,
            settingsManager: settingsManager
        )
        
        // Check for first launch
        checkFirstLaunch()
    }
    
    private func checkFirstLaunch() {
        if !settingsManager.setupWizardCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.menuBarController?.runWizard()
            }
        }
    }
    
    /// Sets up the AppStateManager and SettingsManager
    private func setupManagers() {
        // Initialize Settings Manager
        settingsManager = SettingsManager()
        
        // Initialize App State Manager
        appStateManager = AppStateManager()
        
        // Initialize Transcript Manager
        transcriptManager = TranscriptManager(settingsManager: settingsManager)
        
        // Subscribe to state changes for debugging
        appStateManager.onStateChange = { [weak self] oldState, newState in
            self?.logger.info("App state changed: \(oldState.displayName) → \(newState.displayName)")
        }
        
        logger.debug("Managers initialized, current state: \(self.appStateManager.currentState.displayName)")
    }
    
    private func setupOverlay() {
        let viewModel = OverlayViewModel()
        self.overlayViewModel = viewModel
        self.overlayWindow = OverlayWindow(viewModel: viewModel)
        
        // Attach SwiftUI content to the overlay window
        if let overlayWindow, let transcriptManager, let settingsManager {
            overlayWindow.attachContent(
                transcriptManager: transcriptManager,
                settingsManager: settingsManager,
                appStateManager: appStateManager,
                overlayViewModel: viewModel,
                visibleLines: 10
            )
        }
        
        // Bind AppStateManager.isOverlayVisible <-> OverlayViewModel.isVisible
        
        // 1. Manager -> ViewModel
        appStateManager.$isOverlayVisible
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak viewModel] isVisible in
                if viewModel?.isVisible != isVisible {
                    if isVisible { viewModel?.show() }
                    else { viewModel?.hide() }
                }
            }
            .store(in: &cancellables)
            
        // 2. ViewModel -> Manager
        // This handles if the window is closed via other means (e.g. logic inside VM)
        viewModel.$isVisible
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                guard let self = self else { return }
                if self.appStateManager.isOverlayVisible != isVisible {
                    if isVisible { self.appStateManager.overlayWillShow() }
                    else { self.appStateManager.overlayWillHide() }
                }
            }
            .store(in: &cancellables)
            
        logger.info("Overlay components initialized")
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
