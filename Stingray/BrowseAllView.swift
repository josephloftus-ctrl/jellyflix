//
//  BrowseAllView.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import SwiftUI

/// A flat grid of all media with genre filtering
struct BrowseAllView: View {
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    @State private var selectedGenre: String = "All"

    private var allMedia: [any MediaProtocol] {
        switch streamingService.libraryStatus {
        case .available(let libraries), .complete(let libraries):
            return libraries.flatMap { library -> [any MediaProtocol] in
                switch library.media {
                case .available(let media), .complete(let media):
                    return media
                default:
                    return []
                }
            }
        default:
            return []
        }
    }

    private var genres: [String] {
        var genreSet: Set<String> = []
        for media in allMedia {
            genreSet.formUnion(media.genres)
        }
        return ["All"] + genreSet.sorted()
    }

    private var filteredMedia: [any MediaProtocol] {
        if selectedGenre == "All" { return allMedia }
        return allMedia.filter { $0.genres.contains(selectedGenre) }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Genre filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(genres, id: \.self) { genre in
                        Button {
                            selectedGenre = genre
                        } label: {
                            Text(genre)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedGenre == genre ? Color.accentColor : Color.gray.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 48)
            }
            .focusSection()

            // Media grid
            ScrollView {
                MediaGridView(allMedia: filteredMedia, streamingService: streamingService, navigation: $navigation)
                    .padding(.horizontal, 48)
            }
        }
        .navigationTitle("Browse All")
    }
}
