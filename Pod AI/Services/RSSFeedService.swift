//
//  RSSFeedService.swift
//  Pod AI
//

import Foundation
import Combine

class RSSFeedService: NSObject, ObservableObject, XMLParserDelegate {
    @Published var episodes: [Episode] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentDuration = ""
    private var currentAudioURL = ""
    private var currentArtworkURL = ""
    private var currentGUID = ""
    private var isInItem = false

    func fetchEpisodes(from url: URL) async {
        await MainActor.run { isLoading = true }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentDescription = ""
            currentPubDate = ""
            currentDuration = ""
            currentAudioURL = ""
            currentArtworkURL = ""
            currentGUID = ""
        }

        if elementName == "enclosure", let url = attributeDict["url"] {
            currentAudioURL = url
        }

        if elementName == "itunes:image", let href = attributeDict["href"] {
            currentArtworkURL = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isInItem else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "description":
            currentDescription += trimmed
        case "pubDate":
            currentPubDate += trimmed
        case "itunes:duration":
            currentDuration += trimmed
        case "guid":
            currentGUID += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false

            let episode = Episode(
                id: currentGUID.isEmpty ? UUID().uuidString : currentGUID,
                title: currentTitle,
                description: cleanDescription(currentDescription),
                publishDate: parseDate(currentPubDate),
                duration: parseDuration(currentDuration),
                audioURL: URL(string: currentAudioURL) ?? URL(string: "about:blank")!,
                artworkURL: URL(string: currentArtworkURL),
                youtubeVideoId: nil,
                transcript: nil
            )

            DispatchQueue.main.async {
                self.episodes.append(episode)
            }
        }
    }

    // MARK: - Helpers

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString) ?? Date()
    }

    private func parseDuration(_ durationString: String) -> TimeInterval {
        let components = durationString.split(separator: ":").compactMap { Int($0) }

        switch components.count {
        case 3: // HH:MM:SS
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        case 2: // MM:SS
            return TimeInterval(components[0] * 60 + components[1])
        case 1: // Seconds only
            return TimeInterval(components[0])
        default:
            return 0
        }
    }

    private func cleanDescription(_ html: String) -> String {
        // Remove HTML tags and decode entities
        var result = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
