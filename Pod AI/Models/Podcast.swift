//
//  Podcast.swift
//  Pod AI
//

import Foundation

struct Podcast: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let description: String
    let artworkURL: URL?
    let feedURL: URL
    let category: String?

    static let lightcone = Podcast(
        id: "lightcone",
        title: "Lightcone Podcast",
        author: "Y Combinator",
        description: "Techno optimism for technical founders",
        artworkURL: URL(string: "https://d3t3ozftmdmh3i.cloudfront.net/staging/podcast_uploaded_nologo/41096716/41096716-1714669077120-3df9a565ae144.jpg"),
        feedURL: URL(string: "https://anchor.fm/s/f58d3330/podcast/rss")!,
        category: "Technology"
    )
}
