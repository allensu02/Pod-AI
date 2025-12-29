//
//  SecretsManager.swift
//  Pod AI
//

import Foundation

enum SecretsManager {
    private static var secrets: NSDictionary? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        return dict
    }

    static var openAIAPIKey: String {
        guard let key = secrets?["OPENAI_API_KEY"] as? String,
              key != "YOUR_API_KEY_HERE" else {
            fatalError("OpenAI API key not configured. Add your key to Secrets.plist")
        }
        return key
    }

    static var youtubeAPIKey: String? {
        guard let key = secrets?["YOUTUBE_API_KEY"] as? String,
              !key.isEmpty, key != "YOUR_API_KEY_HERE" else {
            return nil
        }
        return key
    }

    static var picovoiceAccessKey: String? {
        guard let key = secrets?["PICOVOICE_ACCESS_KEY"] as? String,
              !key.isEmpty, key != "YOUR_ACCESS_KEY_HERE" else {
            return nil
        }
        return key
    }
}
