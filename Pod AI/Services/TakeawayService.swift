//
//  TakeawayService.swift
//  Pod AI
//
//  Manages takeaway storage and distillation for episodes
//

import Foundation
import Observation

@Observable
final class TakeawayService {
    var takeaways: [Takeaway] = []
    var isDistilling = false

    private var currentEpisodeId: String?
    private let storageDirectory: URL
    private let chatEndpoint = "https://api.openai.com/v1/chat/completions"

    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        storageDirectory = paths[0].appendingPathComponent("Takeaways")

        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func loadTakeaways(for episodeId: String) {
        currentEpisodeId = episodeId
        takeaways = loadFromStorage(episodeId: episodeId)
    }

    func addTakeaway(_ takeaway: Takeaway) {
        takeaways.append(takeaway)
        takeaways.sort { $0.timestamp < $1.timestamp }
        saveToStorage(episodeId: takeaway.episodeId, takeaways: takeaways)
    }

    func deleteTakeaway(id: String) {
        takeaways.removeAll { $0.id == id }
        if let episodeId = currentEpisodeId {
            saveToStorage(episodeId: episodeId, takeaways: takeaways)
        }
    }

    func takeawayCount(for episodeId: String) -> Int {
        return loadFromStorage(episodeId: episodeId).count
    }

    // MARK: - Distillation (for bookmark flow)

    func distillTakeaway(from transcriptSnippet: String) async throws -> String {
        await MainActor.run { isDistilling = true }
        defer { Task { @MainActor in isDistilling = false } }

        guard let url = URL(string: chatEndpoint) else {
            throw TakeawayError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SecretsManager.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "Distill this podcast transcript excerpt into a single assertive one-line takeaway (max 15 words). Be direct and specific. You may use a short impactful quote from the transcript if it's particularly striking, but only if it's truly memorable. No hedging or filler."
                ],
                [
                    "role": "user",
                    "content": transcriptSnippet
                ]
            ],
            "max_tokens": 50,
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TakeawayError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TakeawayError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Storage

    private func loadFromStorage(episodeId: String) -> [Takeaway] {
        let file = storageDirectory.appendingPathComponent("\(episodeId).json")
        guard let data = try? Data(contentsOf: file),
              let takeaways = try? JSONDecoder().decode([Takeaway].self, from: data) else {
            return []
        }
        return takeaways
    }

    private func saveToStorage(episodeId: String, takeaways: [Takeaway]) {
        let file = storageDirectory.appendingPathComponent("\(episodeId).json")
        guard let data = try? JSONEncoder().encode(takeaways) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

enum TakeawayError: Error {
    case invalidURL
    case apiError
    case parseError
}
