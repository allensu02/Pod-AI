//
//  Episode.swift
//  Pod AI
//

import Foundation

struct Episode: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let publishDate: Date
    let duration: TimeInterval
    let audioURL: URL
    let artworkURL: URL?
    var youtubeVideoId: String?
    var transcript: String?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: publishDate)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}
