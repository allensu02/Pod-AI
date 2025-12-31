//
//  Takeaway.swift
//  Pod AI
//

import Foundation

enum TakeawaySource: String, Codable {
    case question  // From voice Q&A
    case bookmark  // From bookmark button tap
}

struct Takeaway: Identifiable, Codable {
    let id: String
    let episodeId: String
    let text: String
    let timestamp: TimeInterval
    let createdAt: Date
    let sourceType: TakeawaySource
    let transcriptSnippet: String?
    let questionText: String?  // Hidden in MVP UI

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    init(
        id: String = UUID().uuidString,
        episodeId: String,
        text: String,
        timestamp: TimeInterval,
        createdAt: Date = Date(),
        sourceType: TakeawaySource,
        transcriptSnippet: String? = nil,
        questionText: String? = nil
    ) {
        self.id = id
        self.episodeId = episodeId
        self.text = text
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.sourceType = sourceType
        self.transcriptSnippet = transcriptSnippet
        self.questionText = questionText
    }
}
