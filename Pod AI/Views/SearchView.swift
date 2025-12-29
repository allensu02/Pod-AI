//
//  SearchView.swift
//  Pod AI
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @StateObject private var searchService = PodcastSearchService()
    @State private var searchText = ""
    @State private var selectedPodcast: Podcast?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Content based on search state
                if searchText.isEmpty {
                    emptyStateView
                } else if searchService.isLoading && searchService.results.isEmpty {
                    loadingView
                } else if !searchText.isEmpty {
                    searchResultsContent
                }

                Spacer()
            }
            .background(Color.black)

            // Bottom search bar
            VStack(spacing: 0) {
                if audioPlayer.currentEpisode != nil {
                    MiniPlayerView()
                }
                bottomSearchBar
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .sheet(item: $selectedPodcast) { podcast in
            NavigationStack {
                ShowPageView(podcast: podcast)
            }
        }
    }

    // MARK: - Search Results Content

    private var searchResultsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Search suggestions (shown as the user types)
                if !searchText.isEmpty {
                    searchSuggestionRow(text: searchText.lowercased())
                }

                // Podcast results
                ForEach(searchService.results) { podcast in
                    PodcastSearchResultRow(podcast: podcast) {
                        selectedPodcast = podcast
                    }
                }
            }
            .padding(.bottom, audioPlayer.currentEpisode != nil ? 140 : 80)
        }
    }

    private func searchSuggestionRow(text: String) -> some View {
        Button {
            searchService.search(query: text)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.body)

                Text(text)
                    .foregroundColor(.white)
                    .font(.body)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Bottom Search Bar

    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        searchService.search(query: newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchService.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(white: 0.2))
            .cornerRadius(10)

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .padding(10)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Empty States

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Search for podcasts")
                .font(.headline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
}

// MARK: - Podcast Search Result Row

struct PodcastSearchResultRow: View {
    let podcast: Podcast
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Podcast artwork
                AsyncImage(url: podcast.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)

                // Podcast info
                VStack(alignment: .leading, spacing: 2) {
                    Text(podcast.title)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("Show · \(podcast.author)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Add button
                Button {
                    // Follow podcast action (not implemented yet)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView()
        .environmentObject(AudioPlayerService())
}
