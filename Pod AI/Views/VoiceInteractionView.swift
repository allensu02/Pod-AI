//
//  VoiceInteractionView.swift
//  Pod AI
//

import SwiftUI

struct VoiceInteractionView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(TakeawayService.self) private var takeawayService
    @StateObject private var realtimeService = OpenAIRealtimeService()
    @Environment(\.dismiss) private var dismiss

    var transcript: String = ""
    var onDismiss: (() -> Void)? = nil

    @State private var showCTA = false
    @State private var showToast = false
    @State private var ctaTimer: Timer?
    @State private var lastQuestionText: String = ""

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

            // Ephemeral "Add to Takeaways" CTA
            if showCTA && !realtimeService.pendingTakeaways.isEmpty {
                Button(action: addTakeaways) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.subheadline)
                        Text("Add to Takeaways")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.9))
                    .cornerRadius(24)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
        .overlay(alignment: .bottom) {
            // Toast overlay
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Added to Takeaways")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.9))
                .cornerRadius(24)
                .padding(.bottom, 100)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCTA)
        .animation(.easeInOut(duration: 0.3), value: showToast)
        .onAppear {
            connectToRealtime()
        }
        .onDisappear {
            ctaTimer?.invalidate()
            realtimeService.disconnect()
        }
        .onChange(of: realtimeService.hasCompletedResponse) { _, hasCompleted in
            if hasCompleted && !realtimeService.pendingTakeaways.isEmpty {
                // Capture the question text before showing CTA
                lastQuestionText = realtimeService.transcribedText

                // Show CTA with animation
                withAnimation {
                    showCTA = true
                }

                // Auto-hide after 2.5 seconds
                ctaTimer?.invalidate()
                ctaTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                    withAnimation {
                        showCTA = false
                    }
                    realtimeService.clearPendingTakeaways()
                }
            }
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

    private func addTakeaways() {
        guard let episodeId = audioPlayer.currentEpisode?.id else { return }

        // Cancel the auto-hide timer
        ctaTimer?.invalidate()

        // Get transcript snippet around current time
        let transcriptSnippet = getTranscriptSnippet()

        // Save each takeaway candidate
        for text in realtimeService.pendingTakeaways {
            let takeaway = Takeaway(
                episodeId: episodeId,
                text: text,
                timestamp: audioPlayer.currentTime,
                sourceType: .question,
                transcriptSnippet: transcriptSnippet,
                questionText: lastQuestionText.isEmpty ? nil : lastQuestionText
            )
            takeawayService.addTakeaway(takeaway)
        }

        // Hide CTA and show toast
        withAnimation {
            showCTA = false
            showToast = true
        }

        // Clear pending takeaways
        realtimeService.clearPendingTakeaways()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Hide toast after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showToast = false
            }
        }
    }

    private func getTranscriptSnippet() -> String? {
        guard !transcript.isEmpty else { return nil }

        // Get ~200 chars around the current position (rough estimate based on time)
        let totalDuration = audioPlayer.duration
        guard totalDuration > 0 else { return String(transcript.prefix(200)) }

        let progress = audioPlayer.currentTime / totalDuration
        let estimatedPosition = Int(Double(transcript.count) * progress)

        let start = max(0, estimatedPosition - 100)
        let end = min(transcript.count, estimatedPosition + 100)

        let startIndex = transcript.index(transcript.startIndex, offsetBy: start)
        let endIndex = transcript.index(transcript.startIndex, offsetBy: end)

        return String(transcript[startIndex..<endIndex])
    }
}

#Preview {
    VoiceInteractionView()
        .environmentObject(AudioPlayerService())
        .environment(TakeawayService())
}
