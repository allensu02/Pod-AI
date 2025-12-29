//
//  GlowyMicButton.swift
//  Pod AI
//
//  Animated glowing microphone button for wake word indication
//

import SwiftUI

struct GlowyMicButton: View {
    let state: WakeWordState
    let voiceState: RealtimeVoiceState
    var isVoiceInteractionActive: Bool = false  // NEW: tracks if voice interaction started
    var onTap: (() -> Void)? = nil

    @State private var glowAnimation = false
    @State private var pulseAnimation = false

    private var isActive: Bool {
        // Always active (wake word always listening) unless error
        if case .error = state { return false }
        return true
    }

    private var isVoiceActive: Bool {
        // Voice is active if interaction started OR voiceState is not idle
        if isVoiceInteractionActive { return true }
        switch voiceState {
        case .listening, .processing, .speaking:
            return true
        case .idle:
            return false
        }
    }

    private var glowColor: Color {
        // If voice interaction is active, show voice state colors
        if isVoiceInteractionActive || isVoiceActive {
            switch voiceState {
            case .listening: return .purple
            case .processing: return .orange
            case .speaking: return .green
            case .idle: return .purple  // Connecting/starting - show purple
            }
        }

        // Error state
        if case .error = state {
            return .red
        }

        // Default: always purple (wake word always listening)
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
                // Outer glow rings
                if isActive || isVoiceActive {
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
                    .blur(radius: isActive || isVoiceActive ? 12 : 4)
                    .opacity(isActive || isVoiceActive ? 0.8 : 0.3)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
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
                    .scaleEffect(state == .detected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: state == .detected)
            }
        }
        .onAppear {
            glowAnimation = true
            pulseAnimation = true
        }
    }
}

// Floating overlay version for use on top of other views
struct FloatingMicOverlay: View {
    @ObservedObject var wakeWordService: WakeWordService
    let voiceState: RealtimeVoiceState
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GlowyMicButton(
                    state: wakeWordService.state,
                    voiceState: voiceState,
                    onTap: onTap
                )
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Above mini player
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            GlowyMicButton(state: .inactive, voiceState: .idle)
            GlowyMicButton(state: .listening, voiceState: .idle)
            GlowyMicButton(state: .detected, voiceState: .idle)
            GlowyMicButton(state: .listening, voiceState: .listening)
            GlowyMicButton(state: .listening, voiceState: .speaking)
        }
    }
}
