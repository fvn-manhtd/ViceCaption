//
//  AudioRoutingStepView.swift
//  VibeCaption
//
//  Step 3: Instructions for routing audio to BlackHole.
//

import SwiftUI

struct AudioRoutingStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Audio Routing")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To capture audio, you need to set the Output Device of your meeting app to 'BlackHole 2ch'.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 500)
            
            TabView {
                // Zoom
                RoutingInstructionView(
                    appName: "Zoom",
                    iconName: "video.fill",
                    color: .blue,
                    steps: [
                        "Open Zoom Settings (Cmd+,)",
                        "Go to the 'Audio' tab",
                        "Under 'Speaker', select 'BlackHole 2ch'",
                        "Close Settings"
                    ]
                )
                .tabItem { Text("Zoom") }
                
                // Google Meet / Chrome
                RoutingInstructionView(
                    appName: "Chrome / Meet",
                    iconName: "globe",
                    color: .red,
                    steps: [
                        "Open macOS System Settings",
                        "Go to Sound -> Output",
                        "Select 'BlackHole 2ch'",
                        "Note: This routes all system audio to the app"
                    ]
                )
                .tabItem { Text("Chrome / System") }
                
                // Teams
                RoutingInstructionView(
                    appName: "Microsoft Teams",
                    iconName: "person.2.fill",
                    color: .indigo,
                    steps: [
                        "Click '...' (More options) in meeting controls",
                        "Select 'Device settings'",
                        "Under 'Speaker', select 'BlackHole 2ch'"
                    ]
                )
                .tabItem { Text("Teams") }
            }
            .frame(height: 220)
            .padding(.horizontal)
            
            HStack {
                Image(systemName: "info.circle")
                Text("VibeCaption will listen to BlackHole and relay audio to your speakers so you can still hear it.")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
        }
    }
}

struct RoutingInstructionView: View {
    let appName: String
    let iconName: String
    let color: Color
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconName)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 40)
                Text(appName)
                    .font(.headline)
            }
            .padding(.bottom, 8)
            
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(steps[index])
                        .font(.body)
                }
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
