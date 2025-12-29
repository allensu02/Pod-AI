//
//  YouTubeTranscriptService.swift
//  Pod AI
//
//  Fetches transcripts from YouTube videos using the YoutubeTranscript library
//

import Foundation
import YoutubeTranscript

class YouTubeTranscriptService {

    static let shared = YouTubeTranscriptService()

    private let searchEndpoint = "https://www.googleapis.com/youtube/v3/search"

    private init() {}

    // MARK: - Video Search

    /// Search YouTube for a video matching the query and return the video ID
    /// - Parameters:
    ///   - query: Search query (e.g., episode title)
    ///   - channelId: Optional channel ID to restrict search
    /// - Returns: Video ID of the first matching result, or nil
    func searchVideoId(query: String, channelId: String? = nil) async -> String? {
        guard let apiKey = SecretsManager.youtubeAPIKey else {
            print("YouTube API key not configured")
            return nil
        }

        var components = URLComponents(string: searchEndpoint)!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "1"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        if let channelId = channelId {
            queryItems.append(URLQueryItem(name: "channelId", value: channelId))
        }

        components.queryItems = queryItems

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("YouTube search failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            let result = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
            return result.items.first?.id.videoId
        } catch {
            print("YouTube search error: \(error)")
            return nil
        }
    }

    // MARK: - Transcript Fetching

    /// Fetch transcript from YouTube video
    /// - Parameter videoId: YouTube video ID (e.g., "TwDJhUJL-5o")
    /// - Returns: Full transcript as a single string, or nil if unavailable
    func fetchTranscript(videoId: String) async -> String? {
        do {
            let config = TranscriptConfig(lang: "en")
            let entries = try await YoutubeTranscript.fetchTranscript(for: videoId, config: config)

            // Combine all transcript entries into a single string
            let transcript = entries.map { $0.text }.joined(separator: " ")
            return transcript.isEmpty ? nil : transcript
        } catch {
            print("YouTube transcript error: \(error)")
            return nil
        }
    }

    /// Search for video and fetch its transcript in one call
    /// - Parameters:
    ///   - query: Search query (e.g., episode title)
    ///   - channelId: Optional channel ID to restrict search
    /// - Returns: Tuple of (videoId, transcript) or nil
    func searchAndFetchTranscript(query: String, channelId: String? = nil) async -> (videoId: String, transcript: String)? {
        guard let videoId = await searchVideoId(query: query, channelId: channelId) else {
            return nil
        }

        guard let transcript = await fetchTranscript(videoId: videoId) else {
            return nil
        }

        return (videoId, transcript)
    }

    // MARK: - Helpers

    /// Try to extract YouTube video ID from various URL formats
    static func extractVideoId(from url: String) -> String? {
        if let urlComponents = URLComponents(string: url) {
            // Standard watch URL
            if let videoId = urlComponents.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoId
            }

            // Short URL or embed/shorts format
            let pathComponents = urlComponents.path.split(separator: "/")
            if let lastComponent = pathComponents.last {
                let videoId = String(lastComponent)
                if videoId.count == 11 {
                    return videoId
                }
            }
        }
        return nil
    }
}

// MARK: - YouTube API Response Models

private struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

private struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
}

private struct YouTubeVideoId: Codable {
    let videoId: String
}
