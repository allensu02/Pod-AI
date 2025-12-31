//
//  ContentView.swift
//  Pod AI
//
//  Created by Allen Su on 12/27/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService

    var body: some View {
        NavigationStack {
            BrowseView()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerService())
}
