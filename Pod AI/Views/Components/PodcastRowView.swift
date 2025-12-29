//
//  PodcastRowView.swift
//  Pod AI
//

import SwiftUI

struct PodcastRowView: View {
    let podcast: Podcast

    var body: some View {
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
            .frame(width: 60, height: 60)
            .cornerRadius(8)

            // Podcast info
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)

                if let category = podcast.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        PodcastRowView(podcast: .lightcone)
        Divider().background(Color.gray.opacity(0.3))
        PodcastRowView(podcast: .lightcone)
    }
    .background(Color.black)
}
