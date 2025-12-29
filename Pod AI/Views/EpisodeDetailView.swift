//
//  EpisodeDetailView.swift
//  Pod AI
//

import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var showNowPlaying = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Episode Artwork
                        AsyncImage(url: episode.artworkURL ?? podcast.artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 300)
                        .clipped()

                        VStack(alignment: .leading, spacing: 12) {
                            // Date
                            Text("\(episode.formattedDate) · E")
                                .font(.caption)
                                .foregroundColor(.gray)

                            // Title
                            Text(episode.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            // Podcast name
                            HStack(spacing: 8) {
                                AsyncImage(url: podcast.artworkURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())

                                Text(podcast.title)
                                    .font(.subheadline)
                                    .foregroundColor(.white)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            // Play button and actions
                            HStack(spacing: 16) {
                                Button(action: {
                                    audioPlayer.play(episode: episode, from: podcast)
                                    showNowPlaying = true
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text(episode.formattedDuration)
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.purple)
                                    .cornerRadius(20)
                                }

                                Button(action: {}) {
                                    Image(systemName: "arrow.down")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                }

                                Button(action: {}) {
                                    Image(systemName: "bookmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.gray.opacity(0.3))
                                        .clipShape(Circle())
                                }

                                Spacer()
                            }
                            .padding(.top, 8)

                            // Description
                            Text(episode.description)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 16)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, audioPlayer.currentEpisode != nil ? 100 : 20)
                }
                .background(Color.black)

                // Mini Player
                if audioPlayer.currentEpisode != nil {
                    MiniPlayerView()
                        .onTapGesture {
                            showNowPlaying = true
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
        }
    }
}

#Preview {
    EpisodeDetailView(
        episode: Episode(
            id: "1",
            title: "What Founders Have To Unlearn To Become Great CEOs",
            description: "Spenser Skates has spent more than a decade building Amplitude from a startup to a public company. In this episode, he shares the lessons he's learned...",
            publishDate: Date(),
            duration: 2661,
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            artworkURL: nil,
            transcript: nil
        ),
        podcast: .lightcone
    )
    .environmentObject(AudioPlayerService())
}
