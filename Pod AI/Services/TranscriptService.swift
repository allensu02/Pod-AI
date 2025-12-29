//
//  TranscriptService.swift
//  Pod AI
//
//  Fetches and caches transcripts for podcast episodes
//  Priority: Cache -> YouTube -> Whisper API
//

import Foundation
import Combine

class TranscriptService: ObservableObject {
    @Published var isTranscribing = false
    @Published var progress: Double = 0
    @Published var transcriptSource: TranscriptSource = .none

    enum TranscriptSource {
        case none
        case cache
        case youtube
        case whisper
    }

    private let cacheDirectory: URL
    private let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let youtubeService = YouTubeTranscriptService.shared

    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("Transcripts")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Get transcript for episode: Cache -> YouTube (by ID or search) -> Whisper
    func getTranscript(for episode: Episode) async -> String? {
        // Check cache first
        if let cached = loadFromCache(episodeId: episode.id) {
            await MainActor.run { transcriptSource = .cache }
            return cached
        }

        // Try YouTube if we have a video ID
        if let videoId = episode.youtubeVideoId {
            if let transcript = await youtubeService.fetchTranscript(videoId: videoId) {
                saveToCache(episodeId: episode.id, transcript: transcript)
                await MainActor.run { transcriptSource = .youtube }
                return transcript
            }
        }

        // Try searching YouTube by episode title
        if let result = await youtubeService.searchAndFetchTranscript(query: episode.title) {
            saveToCache(episodeId: episode.id, transcript: result.transcript)
            await MainActor.run { transcriptSource = .youtube }
            return result.transcript
        }

        // Fall back to Whisper
        if let transcript = await transcribeEpisode(episode) {
            await MainActor.run { transcriptSource = .whisper }
            return transcript
        }

        return nil
    }

    /// Check if transcript exists in cache
    func hasTranscript(for episode: Episode) -> Bool {
        let cacheFile = cacheDirectory.appendingPathComponent("\(episode.id).txt")
        return FileManager.default.fileExists(atPath: cacheFile.path)
    }

    // MARK: - Cache Management

    private func loadFromCache(episodeId: String) -> String? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(episodeId).txt")
        return try? String(contentsOf: cacheFile, encoding: .utf8)
    }

    private func saveToCache(episodeId: String, transcript: String) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(episodeId).txt")
        try? transcript.write(to: cacheFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Whisper Transcription

    private func transcribeEpisode(_ episode: Episode) async -> String? {
        await MainActor.run {
            isTranscribing = true
            progress = 0
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
                progress = 0
            }
        }

        // Download audio file
        guard let audioData = await downloadAudio(from: episode.audioURL) else {
            print("Failed to download audio")
            return nil
        }

        await MainActor.run { progress = 0.3 }

        // Transcribe with Whisper
        guard let transcript = await transcribeWithWhisper(audioData: audioData, filename: "episode.mp3") else {
            print("Failed to transcribe")
            return nil
        }

        await MainActor.run { progress = 1.0 }

        // Cache the result
        saveToCache(episodeId: episode.id, transcript: transcript)

        return transcript
    }

    private func downloadAudio(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            print("Download error: \(error)")
            return nil
        }
    }

    private func transcribeWithWhisper(audioData: Data, filename: String) async -> String? {
        guard let url = URL(string: whisperEndpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SecretsManager.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            if httpResponse.statusCode == 200 {
                return String(data: data, encoding: .utf8)
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Whisper API error (\(httpResponse.statusCode)): \(errorText)")
                return nil
            }
        } catch {
            print("Transcription request error: \(error)")
            return nil
        }
    }
}
