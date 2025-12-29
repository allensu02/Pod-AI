//
//  EpisodeRowView.swift
//  Pod AI
//

import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    var fallbackArtworkURL: URL?
    @EnvironmentObject var audioPlayer: AudioPlayerService

    private var displayArtworkURL: URL? {
        episode.artworkURL ?? fallbackArtworkURL
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(episode.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(episode.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            AsyncImage(url: displayArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    EpisodeRowView(episode: Episode(
        id: "1",
        title: "What Founders Have To Unlearn To Become Great CEOs",
        description: "Spenser Skates has spent more than a decade building Amplitude...",
        publishDate: Date(),
        duration: 2661,
        audioURL: URL(string: "https://example.com/audio.mp3")!,
        artworkURL: URL(string: "https://example.com/art.jpg"),
        transcript: nil
    ))
    .background(Color.black)
    .environmentObject(AudioPlayerService())
}
