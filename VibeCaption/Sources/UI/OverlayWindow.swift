//
//  OverlayWindow.swift
//  VibeCaption
//
//  A floating, always-on-top window that displays captions.
//  Supports click-through behavior when not focused.
//

import AppKit
import SwiftUI
import Combine

/// Custom NSWindow for the caption overlay.
class OverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    private let viewModel: OverlayViewModel
    private var cancellables = Set<AnyCancellable>()
    // Deterministic visibility flag for tests and diagnostics (does not rely on WindowServer)
    internal private(set) var isPresentedForTest: Bool = false
    private let isRunningTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    
    // MARK: - Initialization
    
    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
        
        // Start with a default rect, will be updated by ViewModel
        let contentRect = NSRect(
            origin: viewModel.position,
            size: viewModel.size
        )
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        setupBindings()
    }
    
    // MARK: - Configuration
    
    private func configureWindow() {
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false // Shadow might interfere with transparency/click-through visually
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Avoid auto-release-on-close in tests to prevent unexpected dealloc ordering
        self.isReleasedWhenClosed = false
        
        // Ensure we can actually see it initially to debug, though it starts hidden
        self.alphaValue = 1.0
    }
    
    private func setupBindings() {
        // Observe Visibility
        viewModel.$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                guard let self = self else { return }
                if self.isRunningTests {
                    // Avoid WindowServer interactions in xcodebuild runs
                    self.isPresentedForTest = isVisible
                    return
                }
                if isVisible {
                    self.orderFront(nil)
                    self.isPresentedForTest = true
                } else {
                    self.orderOut(nil)
                    self.isPresentedForTest = false
                }
            }
            .store(in: &cancellables)
            
        // Observe Frame Changes (External updates to ViewModel)
        // Note: We need to be careful not to create a loop if we bind window frame back to VM
        viewModel.$position
            .combineLatest(viewModel.$size)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (pos, size) in
                guard let self = self else { return }
                
                // Only update if significantly different to avoid loop jitter
                let currentFrame = self.frame
                let newFrame = NSRect(origin: pos, size: size)
                
                if abs(currentFrame.origin.x - pos.x) > 1 ||
                   abs(currentFrame.origin.y - pos.y) > 1 ||
                   abs(currentFrame.width - size.width) > 1 ||
                   abs(currentFrame.height - size.height) > 1 {
                    self.setFrame(newFrame, display: true)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Window Lifecycle
    
    /// Updates ViewModel when the window stops moving/resizing.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // Persist new frame
        viewModel.updatePosition(self.frame.origin)
        viewModel.updateSize(self.frame.size)
    }
    
    // Focus tracking
    override func becomeKey() {
        super.becomeKey()
        viewModel.isFocused = true
    }
    
    override func resignKey() {
        super.resignKey()
        viewModel.isFocused = false
    }
    
    // MARK: - Test-Safe Overrides
    
    override func orderFront(_ sender: Any?) {
        if isRunningTests {
            isPresentedForTest = true
            return
        }
        super.orderFront(sender)
        isPresentedForTest = true
    }
    
    override func orderOut(_ sender: Any?) {
        if isRunningTests {
            isPresentedForTest = false
            return
        }
        super.orderOut(sender)
        isPresentedForTest = false
    }
    
    override func close() {
        if isRunningTests {
            // Prevent hitting WindowServer during tests
            isPresentedForTest = false
            cancellables.removeAll()
            return
        }
        super.close()
    }
    

}
