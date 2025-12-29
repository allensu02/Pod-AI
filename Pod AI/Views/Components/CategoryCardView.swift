//
//  CategoryCardView.swift
//  Pod AI
//

import SwiftUI

struct CategoryCardView: View {
    let category: Category

    var body: some View {
        Button {
            // No action for now
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background color
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color)

                // Icon in top-right area
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: category.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                    }
                    Spacer()
                }

                // Category name at bottom-left
                Text(category.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(12)
            }
            .aspectRatio(1.0, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
        ForEach(Category.allCategories.prefix(4)) { category in
            CategoryCardView(category: category)
        }
    }
    .padding()
    .background(Color.black)
}
