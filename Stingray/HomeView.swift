//
//  HomeView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/9/25.
//

import SwiftUI

struct HomeView: View {
    let streamingService: StreamingServiceProtocol

    @State private var dashboardCache: [String: [SlimMedia]] = [:]
    @Binding var navigation: NavigationPath

    var body: some View {
        VStack(alignment: .leading) {
            DashboardRow(
                title: "Next Up",
                isHero: true,
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveUpNext()
            }
            .focusSection()

            DashboardRow(
                title: "Recently Added",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveRecentlyAdded(.all)
            }
            .focusSection()

            DashboardRow(
                title: "Latest Movies",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveRecentlyAdded(.movie)
            }
            .focusSection()

            DashboardRow(
                title: "Latest Shows",
                streamingService: streamingService,
                cache: $dashboardCache,
                navigation: $navigation
            ) {
                await streamingService.retrieveRecentlyAdded(.tv)
            }
            .focusSection()

            SystemInfoView(streamingService: streamingService)
        }
    }
}

fileprivate struct DashboardRow: View {
    let title: String
    var isHero: Bool = false
    let streamingService: StreamingServiceProtocol
    @Binding var cache: [String: [SlimMedia]]
    @Binding var navigation: NavigationPath
    let fetchMedia: () async -> [SlimMedia]

    @State private var status: DashboardRowStatus = .unstarted

    var body: some View {
        VStack(alignment: .leading) {
            switch status {
            case .empty:
                EmptyView()
            default:
                Text(title)
                    .font(StingrayFont.sectionTitle)
                    .padding(.horizontal, StingraySpacing.xs)
                    .padding(.vertical, 6)
                    .glassBackground(cornerRadius: 12, padding: 8)
                    .task {
                        if let cachedMedia = cache[title] {
                            status = cachedMedia.isEmpty ? .empty : .complete(cachedMedia)
                            return
                        }
                        let response = await fetchMedia()
                        cache[title] = response
                        status = response.isEmpty ? .empty : .complete(response)
                    }
            }

            switch status {
            case .unstarted, .retrieving:
                MediaNavigationLoadingPicker(isHero: isHero)
            case .complete(let newMedia):
                MediaPicker(streamingService: streamingService, pickerMedia: newMedia, isHero: isHero, navigation: $navigation)
            case .empty:
                EmptyView()
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    enum DashboardRowStatus {
        case unstarted
        case retrieving
        case complete([SlimMedia])
        case empty
    }
}

fileprivate struct MediaPicker: View {
    var streamingService: StreamingServiceProtocol
    let pickerMedia: [SlimMedia]
    var isHero: Bool = false

    @Binding var navigation: NavigationPath

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: isHero ? StingraySpacing.lg : StingraySpacing.md) {
                let items = isHero ? Array(pickerMedia.prefix(5)) : pickerMedia
                ForEach(Array(items.enumerated()), id: \.element.id) { index, media in
                    if isHero {
                        HeroMediaCard(media: media, streamingService: streamingService) { navigation.append(media) }
                            .entranceAnimation(index: index)
                    } else {
                        MediaCard(media: media, streamingService: streamingService) { navigation.append(media) }
                            .entranceAnimation(index: index)
                    }
                }
            }
        }
    }
}

// MARK: - Hero Card (large cinematic card for Next Up)

fileprivate struct HeroMediaCard: View {
    let media: any SlimMediaProtocol
    let url: URL?
    let action: @MainActor () -> Void
    @Environment(\.isFocused) private var isFocused

    init(media: any SlimMediaProtocol, streamingService: StreamingServiceProtocol, action: @escaping @MainActor () -> Void) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 800)
        self.action = action
    }

    var body: some View {
        Button { action() }
        label: {
            VStack(spacing: 0) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: StingrayCard.hero.width, height: StingrayCard.hero.imageHeight)
                        .clipped()
                } placeholder: {
                    MediaCardLoading()
                        .frame(width: StingrayCard.hero.width, height: StingrayCard.hero.imageHeight)
                }
                Text(media.title)
                    .font(.headline.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.horizontal, StingraySpacing.sm)
                    .padding(.top, StingraySpacing.sm)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.card)
        .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 30, y: 14)
        .animation(StingrayAnimation.focusSpring, value: isFocused)
        .frame(width: StingrayCard.hero.width, height: StingrayCard.hero.height)
    }
}

struct MediaDetailLoader: View {
    let mediaID: String
    let parentID: String?
    let streamingService: StreamingServiceProtocol

    @Binding var navigation: NavigationPath

    var body: some View {
        switch self.streamingService.lookup(mediaID: mediaID, parentID: parentID) {
        case .found(let foundMedia):
            DetailMediaView(media: foundMedia, streamingService: streamingService, navigation: $navigation)
        case .temporarilyNotFound:
            ProgressView("Loading Libraries...")
        case .notFound:
            Text("Media Not Found")
            Text("It may not have been compatible with Stingray")
                .opacity(0.5)
        }
    }
}

// MARK: - Loading Skeleton

fileprivate struct MediaNavigationLoadingPicker: View {
    var isHero: Bool = false
    private let numOfPlaceholders: Int = Int.random(in: 4..<8)

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: isHero ? StingraySpacing.lg : StingraySpacing.md) {
                ForEach(0..<numOfPlaceholders, id: \.self) { index in
                    SkeletonCard(isHero: isHero)
                        .opacity(Double(1 - (Double(index) / Double(numOfPlaceholders))))
                }
            }
        }
    }
}

fileprivate struct SkeletonCard: View {
    var isHero: Bool = false
    @State private var pulse = false

    private var dims: StingrayCard.Dimensions {
        isHero ? StingrayCard.hero : StingrayCard.standard
    }

    var body: some View {
        Button {} label: {
            VStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(pulse ? 0.25 : 0.12))
                    .frame(height: dims.imageHeight)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(pulse ? 0.2 : 0.1))
                    .frame(width: dims.width * 0.6, height: 14)
                    .padding(.top, StingraySpacing.xs)
                Spacer()
            }
            .frame(width: dims.width, height: dims.height)
        }
        .buttonStyle(.card)
        .focusable(false)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - System Info

struct SystemInfoView: View {
    let streamingService: any StreamingServiceProtocol

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Jellyflix v\(version)")
            }
            else { Text("Unknown Jellyflix Version") }
            Text(" \u{2022} Jellyfin Server ")
            if let name = self.streamingService.serverName { Text("\"\(name)\" ") }
            if let version = self.streamingService.serverVersion { Text("v\(version)") }
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            Text(" \u{2022} tvOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        }
        .foregroundStyle(.gray.opacity(0.35))
        .font(StingrayFont.metadata)
        .frame(maxWidth: .infinity)
        .padding(.top, StingraySpacing.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
        }
    }
}
