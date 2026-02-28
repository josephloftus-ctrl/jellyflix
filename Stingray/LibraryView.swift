//
//  LibraryView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import SwiftUI

public struct LibraryView: View {
    @State var library: any LibraryProtocol

    @Binding var navigation: NavigationPath

    let streamingService: StreamingServiceProtocol

    public var body: some View {
        ScrollView {
            switch library.media {
            case .unloaded, .waiting:
                ProgressView()
            case .error(let err):
                ErrorView(error: err, summary: "The server formatted the library's media unexpectedly.")
            case .available(let allMedia), .complete(let allMedia):
                if !allMedia.isEmpty {
                    MediaGridView(allMedia: allMedia, streamingService: streamingService, navigation: $navigation)
                } else {
                    VStack(alignment: .center, spacing: StingraySpacing.sm) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("This library appears to be empty.")
                        Text("Media types like collections, playlists, and music aren't yet supported.")
                            .foregroundStyle(StingrayColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, StingraySpacing.xl)
                }
            }
        }
    }
}

public struct MediaGridView: View {
    static let cardSpacing: CGFloat = 50.0
    let allMedia: [any MediaProtocol]
    let streamingService: any StreamingServiceProtocol

    @Binding public var navigation: NavigationPath

    public var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: StingrayCard.standard.width, maximum: StingrayCard.standard.height), spacing: Self.cardSpacing)
        ]
        LazyVGrid(columns: columns, spacing: Self.cardSpacing) {
            ForEach(Array(allMedia.enumerated()), id: \.element.id) { index, media in
                MediaCard(media: media, streamingService: streamingService) { navigation.append(AnyMedia(media: media)) }
                    .entranceAnimation(index: index)
            }
        }
    }
}
