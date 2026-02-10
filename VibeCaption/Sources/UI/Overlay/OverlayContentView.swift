//
//  OverlayContentView.swift
//  VibeCaption
//
//  Scrollable transcript overlay content that auto-scrolls to latest
//  blocks and styles based on user settings.
//

import SwiftUI
import AppKit
import os.log

struct OverlayContentView: View {
    @ObservedObject var transcriptManager: TranscriptManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var pipeline: CaptionPipeline
    @ObservedObject var overlayViewModel: OverlayViewModel
    
    // Default visible lines count; used to shape suggested height
    let visibleLines: Int
    
    // Optional test callback for verifying auto-scroll behavior
    var onAutoScroll: ((UUID) -> Void)? = nil
    
    @StateObject private var autoHideController: OverlayAutoHideController
    @State private var keyEventMonitor: Any?
    @State private var showKeypressFeedback: Bool = false
    @State private var keypressResetTask: DispatchWorkItem?
    @State private var showClearPopup: Bool = false
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption",
        category: "OverlayContentView"
    )
    
    init(
        transcriptManager: TranscriptManager,
        settingsManager: SettingsManager,
        appStateManager: AppStateManager,
        pipeline: CaptionPipeline,
        overlayViewModel: OverlayViewModel,
        visibleLines: Int = 10,
        onAutoScroll: ((UUID) -> Void)? = nil
    ) {
        self.transcriptManager = transcriptManager
        self.settingsManager = settingsManager
        self.appStateManager = appStateManager
        self.pipeline = pipeline
        self.overlayViewModel = overlayViewModel
        self.visibleLines = visibleLines
        self.onAutoScroll = onAutoScroll
        _autoHideController = StateObject(
            wrappedValue: OverlayAutoHideController(
                inactivityInterval: TimeInterval(settingsManager.overlayAutoHideSeconds)
            )
        )
    }
    
    private var containerMaxWidth: CGFloat { settingsManager.overlayMaxWidth }
    
    // Suggest height based on visible lines and font size
    private var suggestedHeight: CGFloat {
        let lineHeight = OverlayLayoutConfig.lineHeight(for: settingsManager.overlayFontSize)
        // Two lines per block typically (JP + EN). We keep visibleLines literal (lines, not blocks)
        let verticalPadding: CGFloat = 16 // padding room in ScrollView
        return CGFloat(visibleLines) * lineHeight + verticalPadding
    }
    
    private var hasDisplayableContent: Bool {
        !transcriptManager.displayableBlocks.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(transcriptManager.displayableBlocks) { block in
                            CaptionBlockView(
                                block: block,
                                fontSize: settingsManager.overlayFontSize
                            )
                            .id(block.id)
                            .animation(.easeInOut(duration: 0.25), value: transcriptManager.displayableBlocks.count)
                        }
                        
                        // Live in-progress block (partial streaming result)
                        if let liveBlock = transcriptManager.liveBlock {
                            CaptionBlockView(
                                block: liveBlock,
                                fontSize: settingsManager.overlayFontSize
                            )
                            .id("live-block")
                            .opacity(0.7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: containerMaxWidth, alignment: .leading)
                    .onChange(of: transcriptManager.displayableBlocks.last?.id) { newID in
                        guard let newID else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(newID, anchor: .bottom)
                        }
                        autoHideController.recordActivity()
                        onAutoScroll?(newID)
                    }
                    .onChange(of: transcriptManager.liveBlock?.id) { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("live-block", anchor: .bottom)
                        }
                        autoHideController.recordActivity()
                    }
                }
                .frame(maxWidth: containerMaxWidth, minHeight: suggestedHeight)
            }
            
            OverlayControlsView(
                appStateManager: appStateManager,
                showKeypressFeedback: showKeypressFeedback,
                hasContent: hasDisplayableContent,
                onPause: handlePause,
                onResume: handleResume,
                onClear: handleClearTapped
            )
            .padding(.leading, 8)
            .padding(.top, 8)
            
            ClearCaptionsPopupOverlay(
                isPresented: $showClearPopup,
                anchorAlignment: .topLeading,
                onClearDisplayOnly: handleClearDisplayOnly,
                onClearAndDiscard: handleClearAndDiscard
            )
        }
        .onAppear {
            configureAutoHide()
            handleOverlayVisibilityChange(appStateManager.isOverlayVisible)
            startKeyMonitoring()
        }
        .onDisappear {
            stopKeyMonitoring()
            autoHideController.stop()
        }
        .onChange(of: appStateManager.isOverlayVisible) { isVisible in
            handleOverlayVisibilityChange(isVisible)
        }
        .onChange(of: settingsManager.overlayAutoHideSeconds) { newValue in
            autoHideController.updateInterval(TimeInterval(newValue))
        }
    }
    
    private func configureAutoHide() {
        autoHideController.onHide = { [appStateManager] in
            DispatchQueue.main.async {
                appStateManager.overlayWillHide()
            }
        }
    }
    
    private func handleOverlayVisibilityChange(_ isVisible: Bool) {
        if isVisible {
            autoHideController.recordActivity()
            autoHideController.start()
        } else {
            autoHideController.stop()
        }
    }
    
    private func handlePause() {
        autoHideController.recordActivity()
        pipeline.pause()
    }
    
    private func handleResume() {
        autoHideController.recordActivity()
        pipeline.resume()
    }
    
    private func startKeyMonitoring() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let handled = OverlayKeyCommandHandler.handleKeyDown(
                event,
                isFocused: overlayViewModel.isFocused
            ) {
                handleSpaceKey()
            }
            return handled ? nil : event
        }
    }
    
    private func stopKeyMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    private func handleSpaceKey() {
        triggerKeypressFeedback()
        autoHideController.recordActivity()
        switch appStateManager.currentState {
        case .idle:
            Task {
                do {
                    try await pipeline.start()
                } catch {
                    logger.error("Space toggle failed: \(error.localizedDescription)")
                }
            }
        case .listening, .translating, .paused:
            pipeline.stop(trigger: .manualStop)
        }
    }
    
    private func triggerKeypressFeedback() {
        keypressResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.1)) {
            showKeypressFeedback = true
        }
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showKeypressFeedback = false
            }
        }
        keypressResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }
    
    private func handleClearTapped() {
        autoHideController.recordActivity()
        showClearPopup = true
    }
    
    private func handleClearDisplayOnly() {
        transcriptManager.clearDisplay()
        logger.info("Cleared display only (data preserved)")
    }
    
    private func handleClearAndDiscard() {
        transcriptManager.clearAndDiscard()
        logger.info("Cleared and discarded data")
    }
}

// MARK: - Layout Config (Testable)

enum OverlayLayoutConfig {
    static func lineHeight(for font: FontSize) -> CGFloat {
        // Heuristic line height multiplier
        let base = font.fontSize
        return base * 1.25
    }
    
    static func latestID(in blocks: [TranscriptBlock]) -> UUID? {
        blocks.last?.id
    }
}

// MARK: - Auto Hide Controller (Testable)

final class OverlayAutoHideController: ObservableObject {
    private(set) var lastActivity: Date
    private var timer: Timer?
    var inactivityInterval: TimeInterval
    var onHide: (() -> Void)?
    
    init(inactivityInterval: TimeInterval, lastActivity: Date = Date()) {
        self.inactivityInterval = inactivityInterval
        self.lastActivity = lastActivity
    }
    
    func start() {
        resetTimer()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateInterval(_ interval: TimeInterval) {
        inactivityInterval = interval
        resetTimer()
    }
    
    func recordActivity(date: Date = Date()) {
        lastActivity = date
        resetTimer()
    }
    
    func shouldHide(now: Date = Date()) -> Bool {
        guard inactivityInterval > 0 else { return false }
        return now.timeIntervalSince(lastActivity) >= inactivityInterval
    }
    
    private func resetTimer() {
        timer?.invalidate()
        guard inactivityInterval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: inactivityInterval, repeats: false) { [weak self] _ in
            self?.handleTimerFired()
        }
    }
    
    private func handleTimerFired(now: Date = Date()) {
        guard shouldHide(now: now) else {
            resetTimer()
            return
        }
        onHide?()
        stop()
    }
}

// MARK: - Key Handling (Testable)

enum OverlayKeyCommandHandler {
    static func isSpaceKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 49 {
            return true
        }
        return event.charactersIgnoringModifiers == " "
    }
    
    @discardableResult
    static func handleKeyDown(
        _ event: NSEvent,
        isFocused: Bool,
        onSpace: () -> Void
    ) -> Bool {
        guard isFocused, isSpaceKey(event) else { return false }
        onSpace()
        return true
    }
}
