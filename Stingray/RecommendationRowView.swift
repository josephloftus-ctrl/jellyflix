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
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.title)
                .font(.title2.bold())

            Text(row.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 24) {
                    ForEach(row.media) { media in
                        MediaCard(media: media, streamingService: streamingService) {
                            navigation.append(media)
                        }
                    }
                }
            }
        }
        .focusSection()
        .padding(.vertical)
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
