//
//  WelcomeStepView.swift
//  VibeCaption
//
//  Step 1: Welcome screen.
//

import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "captions.bubble.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text("Welcome to VibeCaption")
                .font(.system(size: 28, weight: .bold))
            
            // Description
            Text("VibeCaption provides real-time Japanese-to-English translation for your video calls and meetings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)
            
            Divider()
                .frame(width: 200)
            
            // What we'll do
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check Components")
                            .font(.headline)
                        Text("Ensure required audio drivers are installed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configure Routing")
                            .font(.headline)
                        Text("Set up audio output from your meeting apps.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Test Audio")
                            .font(.headline)
                        Text("Verify VibeCaption can hear the audio.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

#if DEBUG
struct WelcomeStepView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeStepView()
            .frame(width: 600, height: 400)
    }
}
#endif
