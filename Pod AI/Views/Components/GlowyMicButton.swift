//
//  GlowyMicButton.swift
//  Pod AI
//
//  Animated glowing microphone button for voice interaction
//

import SwiftUI

struct GlowyMicButton: View {
    let voiceState: RealtimeVoiceState
    var isVoiceInteractionActive: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var glowAnimation = false
    @State private var pulseAnimation = false

    private var isVoiceActive: Bool {
        if isVoiceInteractionActive { return true }
        switch voiceState {
        case .listening, .processing, .speaking:
            return true
        case .idle:
            return false
        }
    }

    private var glowColor: Color {
        if isVoiceInteractionActive || isVoiceActive {
            switch voiceState {
            case .listening: return .purple
            case .processing: return .orange
            case .speaking: return .green
            case .idle: return .purple
            }
        }
        return .purple
    }

    private var iconName: String {
        if isVoiceActive {
            switch voiceState {
            case .listening: return "waveform"
            case .processing: return "ellipsis"
            case .speaking: return "speaker.wave.2.fill"
            case .idle: return "mic.fill"
            }
        }
        return "mic.fill"
    }

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                // Outer glow rings when active
                if isVoiceActive {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(glowColor.opacity(glowAnimation ? 0.4 : 0.1), lineWidth: 2)
                            .frame(width: CGFloat(50 + i * 16), height: CGFloat(50 + i * 16))
                            .scaleEffect(glowAnimation ? 1.15 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                                value: glowAnimation
                            )
                    }
                }

                // Glow effect behind button
                Circle()
                    .fill(glowColor)
                    .frame(width: 44, height: 44)
                    .blur(radius: isVoiceActive ? 12 : 4)
                    .opacity(isVoiceActive ? 0.8 : 0.3)
                    .scaleEffect(pulseAnimation && isVoiceActive ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )

                // Main button circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [glowColor, glowColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: glowColor.opacity(0.5), radius: 8, x: 0, y: 2)

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            glowAnimation = true
            pulseAnimation = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            GlowyMicButton(voiceState: .idle)
            GlowyMicButton(voiceState: .listening, isVoiceInteractionActive: true)
            GlowyMicButton(voiceState: .processing, isVoiceInteractionActive: true)
            GlowyMicButton(voiceState: .speaking, isVoiceInteractionActive: true)
        }
    }
}
