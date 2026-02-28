//
//  RecommendationRowView.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import SwiftUI

/// A single horizontal row of recommended media
struct RecommendationRowView: View {
    let row: LoadedRow
    var rowIndex: Int = 0
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: StingraySpacing.xs) {
            Text(row.title)
                .font(StingrayFont.sectionTitle)
                .padding(.horizontal, StingraySpacing.xs)
                .padding(.vertical, 6)
                .glassBackground(cornerRadius: 12, padding: 8)

            Text(row.reason)
                .font(.subheadline)
                .foregroundStyle(StingrayColors.textSecondary)
                .lineLimit(2)

            ScrollView(.horizontal) {
                LazyHStack(spacing: StingraySpacing.md) {
                    ForEach(Array(row.media.enumerated()), id: \.element.id) { index, media in
                        MediaCard(media: media, streamingService: streamingService) {
                            navigation.append(media)
                        }
                        .entranceAnimation(index: index)
                    }
                }
            }
        }
        .focusSection()
        .padding(.vertical)
        .entranceAnimation(index: rowIndex + 1)
    }
}

/// A resolved recommendation row with loaded media
struct LoadedRow: Identifiable {
    let id = UUID()
    let title: String
    let reason: String
    let media: [SlimMedia]
    let type: String
}
