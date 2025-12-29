//
//  Category.swift
//  Pod AI
//

import Foundation
import SwiftUI

struct Category: Identifiable {
    let id: String
    let name: String
    let color: Color
    let icon: String // SF Symbol name or emoji

    static let allCategories: [Category] = [
        Category(id: "top-charts", name: "Top Charts", color: Color(red: 0.7, green: 0.75, blue: 0.2), icon: "chart.bar.fill"),
        Category(id: "2025-review", name: "2025 in Review", color: Color(red: 0.15, green: 0.15, blue: 0.2), icon: "sparkles"),
        Category(id: "comedy", name: "Comedy", color: .orange, icon: "face.smiling.fill"),
        Category(id: "comedy-interviews", name: "Comedy Interviews", color: .orange, icon: "cup.and.saucer.fill"),
        Category(id: "improv", name: "Improv", color: .orange, icon: "burst.fill"),
        Category(id: "stand-up", name: "Stand-Up", color: .orange, icon: "mic.fill"),
        Category(id: "music-interviews", name: "Music Interviews", color: Color(red: 0.9, green: 0.3, blue: 0.4), icon: "music.mic"),
        Category(id: "performing-arts", name: "Performing Arts", color: Color(red: 0.85, green: 0.25, blue: 0.45), icon: "theatermasks.fill"),
        Category(id: "series", name: "Series", color: Color(red: 0.8, green: 0.2, blue: 0.3), icon: "square.stack.fill"),
        Category(id: "spanish", name: "Podcasts in Spanish", color: Color(red: 0.85, green: 0.3, blue: 0.5), icon: "globe.americas.fill")
    ]
}
