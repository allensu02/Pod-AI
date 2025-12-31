//
//  TakeawaysSheet.swift
//  Pod AI
//

import SwiftUI

struct TakeawaysSheet: View {
    @Environment(TakeawayService.self) private var takeawayService
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    let episodeName: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if takeawayService.takeaways.isEmpty {
                    emptyState
                } else {
                    takeawaysList
                }
            }
            .navigationTitle("Your Takeaways")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No takeaways yet")
                .font(.headline)
                .foregroundColor(.white)

            Text("Tap the bookmark button or ask a question to save insights from this episode.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var takeawaysList: some View {
        List {
            ForEach(takeawayService.takeaways) { takeaway in
                TakeawayRow(takeaway: takeaway) {
                    audioPlayer.seek(to: takeaway.timestamp)
                    dismiss()
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let takeaway = takeawayService.takeaways[index]
                    takeawayService.deleteTakeaway(id: takeaway.id)
                }
            }
            .listRowBackground(Color.gray.opacity(0.15))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct TakeawayRow: View {
    let takeaway: Takeaway
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Text(takeaway.formattedTimestamp)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(takeaway.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: takeaway.sourceType == .question ? "questionmark.bubble" : "bookmark")
                            .font(.caption2)
                        Text(takeaway.sourceType == .question ? "From question" : "Bookmarked")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    TakeawaysSheet(episodeName: "Sample Episode")
        .environment(TakeawayService())
        .environmentObject(AudioPlayerService())
}
