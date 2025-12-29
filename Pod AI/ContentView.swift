//
//  ContentView.swift
//  Pod AI
//
//  Created by Allen Su on 12/27/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var wakeWordService: WakeWordService

    var body: some View {
        NavigationStack {
            BrowseView()
        }
        .preferredColorScheme(.dark)
        .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
            handlePlaybackStateChange(isPlaying: isPlaying)
        }
        .onChange(of: audioPlayer.currentTranscript) { _, transcript in
            // Start wake word when transcript is ready
            if !transcript.isEmpty && audioPlayer.isPlaying {
                startWakeWordListening()
            }
        }
    }

    private func handlePlaybackStateChange(isPlaying: Bool) {
        if isPlaying && !audioPlayer.currentTranscript.isEmpty {
            startWakeWordListening()
        } else if !isPlaying {
            // Only pause if wake word is actually enabled and we're not in voice interaction
            // Voice interaction will manage its own pause/resume
        }
    }

    private func startWakeWordListening() {
        print("🔵 [CONTENT] startWakeWordListening called, isEnabled=\(wakeWordService.isEnabled)")
        guard !wakeWordService.isEnabled else {
            print("🔵 [CONTENT] Already enabled, skipping")
            return
        }

        wakeWordService.startListening {
            print("🔵 [CONTENT] Wake word detected!")
            // NowPlayingView observes wakeWordService.state and will handle the interaction
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService())
        .environmentObject(WakeWordService())
}
