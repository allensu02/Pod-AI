//
//  Pod_AIApp.swift
//  Pod AI
//
//  Created by Allen Su on 12/27/25.
//

import SwiftUI

@main
struct Pod_AIApp: App {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var wakeWordService = WakeWordService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(wakeWordService)
        }
    }
}
