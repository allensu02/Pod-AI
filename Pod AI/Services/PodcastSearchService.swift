//
//  PodcastSearchService.swift
//  Pod AI
//

import Foundation
import Combine

class PodcastSearchService: ObservableObject {
    @Published var results: [Podcast] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var searchTask: Task<Void, Never>?

    func search(query: String) {
        // Cancel any existing search
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            await MainActor.run { isLoading = true }

            do {
                let podcasts = try await performSearch(query: trimmedQuery)
                await MainActor.run {
                    self.results = podcasts
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                    }
                }
            }
        }
    }

    private func performSearch(query: String) async throws -> [Podcast] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&limit=25") else {
            throw SearchError.invalidQuery
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

        return response.results.map { item in
            Podcast(
                id: String(item.collectionId),
                title: item.collectionName,
                author: item.artistName,
                description: "", // iTunes API doesn't include description in search
                artworkURL: URL(string: item.artworkUrl600 ?? item.artworkUrl100),
                feedURL: URL(string: item.feedUrl ?? "") ?? URL(string: "about:blank")!,
                category: item.primaryGenreName
            )
        }
    }

    func clearResults() {
        searchTask?.cancel()
        results = []
        error = nil
    }

    enum SearchError: LocalizedError {
        case invalidQuery

        var errorDescription: String? {
            switch self {
            case .invalidQuery:
                return "Invalid search query"
            }
        }
    }
}

// MARK: - iTunes API Response Models

private struct iTunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [iTunesPodcast]
}

private struct iTunesPodcast: Decodable {
    let collectionId: Int
    let collectionName: String
    let artistName: String
    let artworkUrl100: String
    let artworkUrl600: String?
    let feedUrl: String?
    let primaryGenreName: String?
}
