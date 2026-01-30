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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("VibeCaption launched")
        
        // Hide dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the state manager
        setupStateManager()
        
        setupMenuBar()
    }
    
    /// Sets up the AppStateManager and subscribes to state changes
    private func setupStateManager() {
        appStateManager = AppStateManager()
        
        // Subscribe to state changes for debugging
        appStateManager.onStateChange = { [weak self] oldState, newState in
            self?.logger.info("App state changed: \(oldState.displayName) → \(newState.displayName)")
        }
        
        logger.debug("AppStateManager initialized, current state: \(self.appStateManager.currentState.displayName)")
    }
    
    /// Sets up the menu bar status item with icon and menu
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon
            if let image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "VibeCaption") {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "VibeCaption"
        }
        
        // Create the menu
        let menu = NSMenu()
        
        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit VibeCaption", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    /// Quits the application
    @objc private func quitApp() {
        logger.info("VibeCaption quitting")
        NSApplication.shared.terminate(nil)
    }
}
