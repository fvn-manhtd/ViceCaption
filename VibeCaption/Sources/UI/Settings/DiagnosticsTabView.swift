//
//  DiagnosticsTabView.swift
//  VibeCaption
//
//  Diagnostics settings tab with real-time system status.
//

import SwiftUI

/// Diagnostics settings tab view.
///
/// Displays real-time system information:
/// - Selected input/output devices
/// - Audio frames arriving indicator
/// - Model loaded status (ASR, Translation)
/// - CPU/RAM usage
/// - Pipeline state
public struct DiagnosticsTabView: View {
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var modelManager: ModelManager
    
    @State private var cpuUsage: Double = 0.0
    @State private var memoryUsage: UInt64 = 0
    @State private var isAudioReceiving: Bool = false
    @State private var previousCPUTime: TimeInterval?
    @State private var previousCPUSampleDate: Date?
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section("Audio Devices") {
                DiagnosticRow(
                    label: "Input Device",
                    value: currentInputDeviceName
                )
                
                DiagnosticRow(
                    label: "Output Device",
                    value: currentOutputDeviceName
                )
            }
            
            Section("Audio Status") {
                HStack {
                    Text("Audio Frames Arriving")
                    Spacer()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAudioReceiving ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(isAudioReceiving ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Models") {
                DiagnosticRow(
                    label: "ASR Model",
                    value: asrModelStatus,
                    valueColor: asrModelLoaded ? .green : .orange
                )
                
                DiagnosticRow(
                    label: "Translation Model",
                    value: translationModelStatus,
                    valueColor: translationModelLoaded ? .green : .orange
                )
            }
            
            Section("System Resources") {
                DiagnosticRow(
                    label: "CPU Usage",
                    value: formatCPU(cpuUsage),
                    valueColor: cpuUsage <= 30 ? .green : .orange
                )

                DiagnosticRow(
                    label: "Memory Usage",
                    value: formatMemory(memoryUsage)
                )

                DiagnosticRow(
                    label: "Performance Mode",
                    value: settingsManager.performanceModeEnabled ? "On" : "Off",
                    valueColor: settingsManager.performanceModeEnabled ? .orange : .secondary
                )
                
                DiagnosticRow(
                    label: "Pipeline State",
                    value: appStateManager.currentState.displayName,
                    valueColor: pipelineStateColor
                )
            }
        }
        .formStyle(.grouped)
        .padding()
        .onReceive(timer) { _ in
            updateSystemStats()
        }
        .onAppear {
            updateSystemStats()
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentInputDeviceName: String {
        if let deviceID = settingsManager.audioInputDeviceID,
           let device = audioDeviceManager.inputDevices.first(where: { $0.uid == deviceID }) {
            return device.name
        }
        return "System Default"
    }
    
    private var currentOutputDeviceName: String {
        if let deviceID = settingsManager.monitoringOutputDeviceID,
           let device = audioDeviceManager.outputDevices.first(where: { $0.uid == deviceID }) {
            return device.name
        }
        return "System Default"
    }
    
    private var asrModelLoaded: Bool {
        if let asrID = modelManager.getASRModelID() {
            return modelManager.isModelReady(asrID)
        }
        return false
    }
    
    private var asrModelStatus: String {
        asrModelLoaded ? "Loaded" : "Not Loaded"
    }
    
    private var translationModelLoaded: Bool {
        // Check for any downloaded translation model
        return modelManager.models.first { 
            $0.id.contains("nllb") || $0.id.contains("opus") 
        }.map { modelManager.isModelReady($0.id) } ?? false
    }
    
    private var translationModelStatus: String {
        translationModelLoaded ? "Loaded" : "Not Loaded"
    }
    
    private var pipelineStateColor: Color {
        switch appStateManager.currentState {
        case .idle: return .secondary
        case .listening: return .green
        case .translating: return .blue
        case .paused: return .orange
        }
    }
    
    // MARK: - Helpers
    
    private func updateSystemStats() {
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = info.resident_size
        }

        var threadTimesInfo = task_thread_times_info_data_t()
        var threadTimesCount = mach_msg_type_number_t(MemoryLayout<task_thread_times_info_data_t>.size) / 4
        let cpuResult = withUnsafeMutablePointer(to: &threadTimesInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadTimesCount)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_THREAD_TIMES_INFO),
                    $0,
                    &threadTimesCount
                )
            }
        }

        if cpuResult == KERN_SUCCESS {
            let totalCPUTime = TimeInterval(threadTimesInfo.user_time.seconds)
                + (TimeInterval(threadTimesInfo.user_time.microseconds) / 1_000_000)
                + TimeInterval(threadTimesInfo.system_time.seconds)
                + (TimeInterval(threadTimesInfo.system_time.microseconds) / 1_000_000)
            let now = Date()

            if let previousCPUTime, let previousCPUSampleDate {
                let elapsed = now.timeIntervalSince(previousCPUSampleDate)
                if elapsed > 0 {
                    let cpuDelta = max(0, totalCPUTime - previousCPUTime)
                    let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
                    cpuUsage = min(100.0, (cpuDelta / elapsed) * 100.0 / Double(processorCount))
                }
            }

            previousCPUTime = totalCPUTime
            previousCPUSampleDate = now
        }
        
        // Audio receiving would be connected to actual audio pipeline in real implementation
        isAudioReceiving = appStateManager.currentState == .listening || 
                          appStateManager.currentState == .translating
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatCPU(_ value: Double) -> String {
        String(format: "%.1f%%", max(0, value))
    }
}

// MARK: - Diagnostic Row

/// A single diagnostic row with label and value.
struct DiagnosticRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DiagnosticsTabView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsTabView(
            settingsManager: SettingsManager(),
            audioDeviceManager: AudioDeviceManager(),
            appStateManager: AppStateManager(),
            modelManager: ModelManager(settingsManager: SettingsManager())
        )
        .frame(width: 460, height: 400)
    }
}
#endif
