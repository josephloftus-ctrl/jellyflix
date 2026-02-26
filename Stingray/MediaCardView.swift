//
//  MediaCardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import BlurHashKit
import SwiftUI

struct MediaCard: View {
    let media: any SlimMediaProtocol
    let url: URL?
    let action: @MainActor () -> Void
    @State var showError: Bool = false
    @Environment(\.isFocused) private var isFocused

    static let cardSize = CGSize(width: StingrayCard.standard.width, height: StingrayCard.standard.height)
    static let imageHeight = StingrayCard.standard.imageHeight

    init(media: any SlimMediaProtocol, streamingService: StreamingServiceProtocol, action: @escaping @MainActor () -> Void) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 480)
        self.action = action
    }

    var body: some View {
        Button {
            if self.media.errors == nil { action() }
        }
        label: {
            VStack(spacing: 0) {
                if media.imageTags?.primary != nil {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: Self.cardSize.width, height: Self.imageHeight)
                            .clipped()
                    } placeholder: {
                        if let blurHash = media.imageBlurHashes?.getBlurHash(for: .primary),
                           let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 32)) {
                            Image(uiImage: blurImage)
                                .resizable()
                                .scaledToFill()
                                .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                                .frame(width: Self.cardSize.width, height: Self.imageHeight)
                                .clipped()
                        } else {
                            MediaCardLoading()
                                .frame(height: Self.imageHeight)
                        }
                    }
                } else {
                    MediaCardNoImage()
                        .frame(height: Self.imageHeight)
                }
                Text(media.title)
                    .font(StingrayFont.cardTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.horizontal, StingraySpacing.xs)
                    .padding(.top, StingraySpacing.xs)
                Spacer(minLength: 0)
            }
            .background {
                if !(self.media.errors?.isEmpty ?? true) {
                    Color.red.opacity(0.25)
                }
            }
        }
        .buttonStyle(.card)
        .shadow(color: .black.opacity(isFocused ? 0.4 : 0), radius: 20, y: 10)
        .animation(StingrayAnimation.focusSpring, value: isFocused)
        .contextMenu {
            if self.media.errors != nil {
                Button("Show Error", systemImage: "exclamationmark.octagon", role: .destructive) { self.showError = true }
            }
        }
        .sheet(isPresented: $showError) {
            if let errors = self.media.errors {
                ErrorExpandedView(errorDesc: errors.rDescription)
            }
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .id(media.id) // Stabilize view identity
    }
}

struct MediaCardLoading: View {
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(pulse ? 0.20 : 0.08))
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct MediaCardNoImage: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
            VStack(spacing: StingraySpacing.xs) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                Text("No image available")
                    .multilineTextAlignment(.center)
                    .font(StingrayFont.metadata)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
