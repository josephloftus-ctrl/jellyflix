//
//  HeroView.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import BlurHashKit
import SwiftUI

/// Cinematic hero banner for the AI home screen
struct HeroView: View {
    let media: SlimMedia
    let streamingService: StreamingServiceProtocol
    let onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            AsyncImage(url: streamingService.getImageURL(imageType: .backdrop, mediaID: media.id, width: 1920)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                if let blurHash = media.imageBlurHashes?.getBlurHash(for: .backdrop),
                   let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 18)) {
                    Image(uiImage: blurImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                }
            }
            .frame(height: 700)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 16) {
                Text(media.title)
                    .font(.largeTitle.bold())

                if let overview = media.overview {
                    Text(overview)
                        .font(.body)
                        .lineLimit(3)
                        .frame(maxWidth: 800, alignment: .leading)
                }

                Button {
                    onPlay()
                } label: {
                    Label("View Details", systemImage: "info.circle")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(64)
        }
        .frame(height: 700)
    }
}
