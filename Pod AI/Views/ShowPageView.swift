//
//  ShowPageView.swift
//  Pod AI
//

import SwiftUI

struct ShowPageView: View {
    let podcast: Podcast
    @StateObject private var feedService = RSSFeedService()
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @State private var selectedEpisode: Episode?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Latest Episode Button
                    latestEpisodeButton

                    // Podcast Info
                    podcastInfo

                    // Episodes Section
                    episodesSection
                }
                .padding(.bottom, audioPlayer.currentEpisode != nil ? 80 : 0)
            }
            .background(Color.black)

            // Mini Player
            if audioPlayer.currentEpisode != nil {
                MiniPlayerView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await feedService.fetchEpisodes(from: podcast.feedURL)
        }
        .sheet(item: $selectedEpisode) { episode in
            EpisodeDetailView(episode: episode, podcast: podcast)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            AsyncImage(url: podcast.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 180, height: 180)
            .cornerRadius(12)
            .shadow(radius: 10)

            Text(podcast.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Image(systemName: "y.square.fill")
                    .foregroundColor(.orange)
                Text(podcast.author)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Latest Episode Button

    private var latestEpisodeButton: some View {
        Button(action: {
            if let firstEpisode = feedService.episodes.first {
                audioPlayer.play(episode: firstEpisode, from: podcast)
            }
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Latest Episode")
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(24)
        }
        .padding(.top, 20)
    }

    // MARK: - Podcast Info

    private var podcastInfo: some View {
        VStack(spacing: 4) {
            Text(podcast.description)
                .font(.subheadline)
                .foregroundColor(.white)

            Text(podcast.category ?? "")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top, 16)
        .padding(.horizontal)
    }

    // MARK: - Episodes Section

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Episodes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 24)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.top, 8)

            if feedService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(feedService.episodes) { episode in
                        EpisodeRowView(episode: episode, fallbackArtworkURL: podcast.artworkURL)
                            .onTapGesture {
                                selectedEpisode = episode
                            }
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShowPageView(podcast: .lightcone)
            .environmentObject(AudioPlayerService())
    }
}
