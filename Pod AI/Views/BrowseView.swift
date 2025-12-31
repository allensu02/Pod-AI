//
//  BrowseView.swift
//  Pod AI
//

import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @State private var showSearchView = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with title and profile
                    headerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, audioPlayer.currentEpisode != nil ? 80 : 16)
            }
            .background(Color.black)

            // Bottom area with mini player and search bar
            VStack(spacing: 0) {
                if audioPlayer.currentEpisode != nil {
                    MiniPlayerView()
                }
                SearchBarView {
                    showSearchView = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black)
        }
        .background(Color.black)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showSearchView) {
            SearchView()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Text("Search")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            // Profile avatar placeholder
            Button(action: {
                // No action for now
            }) {
                Circle()
                    .fill(Color(red: 0.4, green: 0.5, blue: 0.7))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("AS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.top, 16)
    }

}

#Preview {
    NavigationStack {
        BrowseView()
            .environmentObject(AudioPlayerService())
    }
}
