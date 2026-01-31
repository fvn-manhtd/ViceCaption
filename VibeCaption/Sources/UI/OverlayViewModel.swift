//
//  OverlayViewModel.swift
//  VibeCaption
//
//  Manages the state and persistence of the overlay window.
//

import Combine
import SwiftUI

/// View model controlling the overlay window's state.
///
/// Handles:
/// - Visibility state (synced with AppState)
/// - Window position and size persistence
/// - Focus state tracking
class OverlayViewModel: ObservableObject {
    
    // MARK: - Constants
    
    private enum StorageKeys {
        static let positionX = "OverlayWindowPositionX"
        static let positionY = "OverlayWindowPositionY"
        static let width = "OverlayWindowWidth"
        static let height = "OverlayWindowHeight"
    }
    
    private let defaultSize = CGSize(width: 800, height: 200)
    
    // MARK: - Published Properties
    
    /// Whether the overlay should be visible on screen.
    @Published var isVisible: Bool = false
    
    /// The current position of the window (bottom-left origin).
    @Published var position: CGPoint
    
    /// The current size of the window.
    @Published var size: CGSize
    
    /// Whether the window currently has focus.
    @Published var isFocused: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load persisted state
        let savedX = userDefaults.double(forKey: StorageKeys.positionX)
        let savedY = userDefaults.double(forKey: StorageKeys.positionY)
        let savedW = userDefaults.double(forKey: StorageKeys.width)
        let savedH = userDefaults.double(forKey: StorageKeys.height)
        
        // Initialize position
        // If keys don't exist, doubles return 0.0.
        // We'll validate this later to center if needed, or check if keys exist.
        // For simplicity, we trust the OS to reposition if 0,0 is off-screen,
        // or we can implement a "first run" check.
        // Let's use a meaningful default if both are 0 (likely uninitialized).
        if savedX == 0 && savedY == 0 {
             // Centerish default - actual screen dependent, logic deferred to WindowController or we set nil/zero and handle launch
             self.position = .zero 
        } else {
             self.position = CGPoint(x: savedX, y: savedY)
        }
        
        // Initialize size
        if savedW > 0 && savedH > 0 {
            self.size = CGSize(width: savedW, height: savedH)
        } else {
            self.size = defaultSize
        }
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Persist changes
        $position
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] newPos in
                self?.savePosition(newPos)
            }
            .store(in: &cancellables)
            
        $size
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] newSize in
                self?.saveSize(newSize)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func savePosition(_ point: CGPoint) {
        userDefaults.set(point.x, forKey: StorageKeys.positionX)
        userDefaults.set(point.y, forKey: StorageKeys.positionY)
    }
    
    private func saveSize(_ size: CGSize) {
        userDefaults.set(size.width, forKey: StorageKeys.width)
        userDefaults.set(size.height, forKey: StorageKeys.height)
    }
    
    // MARK: - Public Actions
    
    func show() {
        isVisible = true
    }
    
    func hide() {
        isVisible = false
    }
    
    func toggle() {
        isVisible.toggle()
    }
    
    func updatePosition(_ point: CGPoint) {
        position = point
    }
    
    func updateSize(_ newSize: CGSize) {
        size = newSize
    }
}
