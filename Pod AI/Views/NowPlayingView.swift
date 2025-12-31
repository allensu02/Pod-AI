//
//  NowPlayingView.swift
//  Pod AI
//

import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @Environment(TakeawayService.self) private var takeawayService
    @StateObject private var realtimeService = OpenAIRealtimeService()
    @State private var isVoiceInteractionActive = false
    @State private var showTakeawaysSheet = false
    @State private var showToast = false
    @State private var isBookmarking = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange.opacity(0.6), Color.black],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                if let episode = audioPlayer.currentEpisode {
                    // Artwork
                    AsyncImage(url: episode.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 320, height: 320)
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .padding(.top, 40)

                    // Episode info
                    HStack(spacing: 12) {
                        AsyncImage(url: episode.artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.formattedDate)
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text(episode.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(audioPlayer.currentPodcast?.title ?? "Podcast")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Seek bar
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.seek(to: $0) }
                            ),
                            in: 0...max(audioPlayer.duration, 1)
                        )
                        .accentColor(.white)

                        HStack {
                            Text(audioPlayer.formattedCurrentTime)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(audioPlayer.formattedRemainingTime)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Playback controls
                    HStack(spacing: 48) {
                        Button(action: {
                            audioPlayer.skipBackward()
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            audioPlayer.togglePlayPause()
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            audioPlayer.skipForward()
                        }) {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 24)

                    Spacer()

                    // Transcript status
                    if audioPlayer.isLoadingTranscript {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Loading transcript...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 8)
                    } else if !audioPlayer.currentTranscript.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Transcript ready")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 8)
                    }

                    // Bottom toolbar with AI voice button
                    HStack(spacing: 48) {
                        Button(action: addBookmark) {
                            if isBookmarking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bookmark")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(isBookmarking || audioPlayer.currentTranscript.isEmpty)

                        // AI Voice Button
                        GlowyMicButton(
                            voiceState: realtimeService.voiceState,
                            isVoiceInteractionActive: isVoiceInteractionActive,
                            onTap: {
                                activateVoiceInteraction()
                            }
                        )
                        .scaleEffect(1.4) // Larger in NowPlayingView

                        Button(action: {
                            showTakeawaysSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.title2)
                                if takeawayService.takeaways.count > 0 {
                                    Text("\(takeawayService.takeaways.count)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .foregroundColor(takeawayService.takeaways.isEmpty ? .gray : .orange)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showTakeawaysSheet) {
            TakeawaysSheet(episodeName: audioPlayer.currentEpisode?.title ?? "Episode")
        }
        .overlay(alignment: .top) {
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
                .background(Color.black.opacity(0.8))
                .cornerRadius(24)
                .padding(.top, 60)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showToast)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            setupFunctionCallHandler()
            if let episodeId = audioPlayer.currentEpisode?.id {
                takeawayService.loadTakeaways(for: episodeId)
            }
        }
        .onDisappear {
            if isVoiceInteractionActive {
                endVoiceInteraction()
            }
        }
    }

    // MARK: - Voice Interaction

    private func setupFunctionCallHandler() {
        realtimeService.onFunctionCall = { [self] name, args in
            handleFunctionCall(name: name, args: args)
        }
    }

    private func startVoiceInteraction() {
        print("🎙️ [NOW PLAYING] Starting voice interaction")
        isVoiceInteractionActive = true

        // Pause podcast
        audioPlayer.pause()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Connect to OpenAI Realtime
        let podcastName = audioPlayer.currentPodcast?.title ?? "Podcast"
        realtimeService.connect(withTranscript: audioPlayer.currentTranscript, podcastName: podcastName)

        // Start listening after connection is established
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔍 [DEBUG] 0.5s timer fired, connectionState = \(realtimeService.connectionState)")
            if realtimeService.connectionState == .connected {
                realtimeService.startListening { }
            } else {
                print("❌ [DEBUG] Not connected after 0.5s, skipping startListening")
            }
        }
    }

    private func endVoiceInteraction() {
        print("🎙️ [NOW PLAYING] Ending voice interaction")
        isVoiceInteractionActive = false

        // Disconnect from OpenAI
        realtimeService.disconnect()

        // Resume podcast
        audioPlayer.resume()
    }

    private func handleFunctionCall(name: String, args: [String: Any]) {
        print("🎙️ [NOW PLAYING] Function call: \(name)")
        switch name {
        case "resume_podcast":
            endVoiceInteraction()

        case "skip_forward":
            let seconds = args["seconds"] as? Int ?? 30
            audioPlayer.skipForward(TimeInterval(seconds))
            endVoiceInteraction()

        case "skip_backward":
            let seconds = args["seconds"] as? Int ?? 15
            audioPlayer.skipBackward(TimeInterval(seconds))
            endVoiceInteraction()

        default:
            break
        }
    }

    private func activateVoiceInteraction() {
        if !isVoiceInteractionActive {
            startVoiceInteraction()
        }
    }

    // MARK: - Bookmark

    private func addBookmark() {
        guard let episodeId = audioPlayer.currentEpisode?.id,
              !audioPlayer.currentTranscript.isEmpty else { return }

        isBookmarking = true

        // Get transcript snippet around current time
        let snippet = getTranscriptSnippet()

        Task {
            do {
                // Distill the snippet into a one-line takeaway
                let distilledText = try await takeawayService.distillTakeaway(from: snippet)

                // Create and save the takeaway
                let takeaway = Takeaway(
                    episodeId: episodeId,
                    text: distilledText,
                    timestamp: audioPlayer.currentTime,
                    sourceType: .bookmark,
                    transcriptSnippet: snippet,
                    questionText: nil
                )

                await MainActor.run {
                    takeawayService.addTakeaway(takeaway)
                    isBookmarking = false

                    // Show toast
                    withAnimation {
                        showToast = true
                    }

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
            } catch {
                await MainActor.run {
                    isBookmarking = false
                    print("Failed to distill takeaway: \(error)")
                }
            }
        }
    }

    private func getTranscriptSnippet() -> String {
        let transcript = audioPlayer.currentTranscript
        guard !transcript.isEmpty else { return "" }

        // Get ~300 chars around the current position
        let totalDuration = audioPlayer.duration
        guard totalDuration > 0 else { return String(transcript.prefix(300)) }

        let progress = audioPlayer.currentTime / totalDuration
        let estimatedPosition = Int(Double(transcript.count) * progress)

        let start = max(0, estimatedPosition - 150)
        let end = min(transcript.count, estimatedPosition + 150)

        let startIndex = transcript.index(transcript.startIndex, offsetBy: start)
        let endIndex = transcript.index(transcript.startIndex, offsetBy: end)

        return String(transcript[startIndex..<endIndex])
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(AudioPlayerService())
        .environment(TakeawayService())
}
