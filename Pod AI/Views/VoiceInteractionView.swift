//
//  VoiceInteractionView.swift
//  Pod AI
//

import SwiftUI

struct VoiceInteractionView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @StateObject private var realtimeService = OpenAIRealtimeService()
    @Environment(\.dismiss) private var dismiss

    var transcript: String = ""
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Ask about this episode")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: closeView) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Connection status
            if case .error(let message) = realtimeService.connectionState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Transcript warning
            if transcript.isEmpty && realtimeService.connectionState == .connected {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("No transcript available - AI may have limited context")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal)
            }

            Spacer()

            // Transcribed text (what user said)
            if !realtimeService.transcribedText.isEmpty {
                Text(realtimeService.transcribedText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            // Response text (what AI is saying)
            if !realtimeService.responseText.isEmpty {
                Text(realtimeService.responseText)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            // Voice animation / status
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(ringColor.opacity(isAnimating ? 0.4 : 0.1), lineWidth: 2)
                        .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                            value: isAnimating
                        )
                }

                // Center button
                Button(action: handleButtonTap) {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: buttonIcon)
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                .disabled(realtimeService.connectionState.isConnecting)
            }

            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            // Hint text
            Text(hintText)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 32)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .background(Color.black)
        .onAppear {
            connectToRealtime()
        }
        .onDisappear {
            realtimeService.disconnect()
        }
    }

    // MARK: - Computed Properties

    private var isAnimating: Bool {
        realtimeService.voiceState == .listening || realtimeService.voiceState == .speaking
    }

    private var ringColor: Color {
        switch realtimeService.voiceState {
        case .listening: return .purple
        case .speaking: return .green
        default: return .gray
        }
    }

    private var buttonColor: Color {
        switch realtimeService.voiceState {
        case .idle: return .purple
        case .listening: return .red
        case .processing: return .orange
        case .speaking: return .green
        }
    }

    private var buttonIcon: String {
        switch realtimeService.voiceState {
        case .idle: return "mic.fill"
        case .listening: return "stop.fill"
        case .processing: return "ellipsis"
        case .speaking: return "waveform"
        }
    }

    private var statusText: String {
        switch realtimeService.connectionState {
        case .connecting:
            return "Connecting..."
        case .error:
            return "Connection error"
        default:
            break
        }

        switch realtimeService.voiceState {
        case .idle: return "Tap to speak"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }

    private var hintText: String {
        if case .error = realtimeService.connectionState {
            return "Check your API key in Secrets.plist"
        }
        return "Ask questions or say \"go back to the podcast\" when done"
    }

    // MARK: - Actions

    private func connectToRealtime() {
        // Set up function call handler
        realtimeService.onFunctionCall = { [self] name, args in
            handleFunctionCall(name: name, args: args)
        }

        let podcastName = audioPlayer.currentPodcast?.title ?? "Podcast"
        realtimeService.connect(withTranscript: transcript, podcastName: podcastName)
    }

    private func handleFunctionCall(name: String, args: [String: Any]) {
        switch name {
        case "resume_podcast":
            closeView()

        case "skip_forward":
            let seconds = args["seconds"] as? Int ?? 30
            audioPlayer.skipForward(TimeInterval(seconds))
            closeView()

        case "skip_backward":
            let seconds = args["seconds"] as? Int ?? 15
            audioPlayer.skipBackward(TimeInterval(seconds))
            closeView()

        default:
            break
        }
    }

    private func handleButtonTap() {
        switch realtimeService.voiceState {
        case .idle:
            realtimeService.startListening { }
        case .listening:
            realtimeService.stopListening()
        case .processing, .speaking:
            break
        }
    }

    private func closeView() {
        realtimeService.disconnect()
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            // Fallback for when opened directly (e.g., from NowPlayingView)
            audioPlayer.resume()
        }
        dismiss()
    }
}

#Preview {
    VoiceInteractionView()
        .environmentObject(AudioPlayerService())
        .environmentObject(WakeWordService())
}
