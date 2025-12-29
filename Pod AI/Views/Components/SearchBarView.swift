//
//  SearchBarView.swift
//  Pod AI
//

import SwiftUI

struct SearchBarView: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))

                Text("Podcasts")
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(searchBarBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var searchBarBackground: some View {
        if #available(iOS 26.0, *) {
            // Use Liquid Glass effect on iOS 26+
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.interactive())
        } else {
            // Fallback for older iOS versions
            Capsule()
                .fill(Color(white: 0.2).opacity(0.8))
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack {
            Spacer()
            SearchBarView {
                print("Search tapped")
            }
            .padding()
        }
    }
}
