//
//  MiniPlayerView.swift
//  Pod AI
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @State private var showNowPlaying = false

    var body: some View {
        if let episode = audioPlayer.currentEpisode {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * progress, height: 2)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Artwork
                    AsyncImage(url: episode.artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)

                    // Episode info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(episode.formattedDate)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Play/Pause button
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)

                    // Forward 30s
                    Button(action: {
                        audioPlayer.skipForward()
                    }) {
                        Image(systemName: "goforward.30")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(white: 0.15))
            .onTapGesture {
                showNowPlaying = true
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
        }
    }

    private var progress: CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        return CGFloat(audioPlayer.currentTime / audioPlayer.duration)
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
    }
    .background(Color.black)
    .environmentObject(AudioPlayerService())
    .environmentObject(WakeWordService())
}
