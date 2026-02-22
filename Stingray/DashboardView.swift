//
//  DashboardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

struct DashboardView: View {
    var streamingService: StreamingServiceProtocol
    var conduitClient: ConduitClient?
    @State private var navigationPath = NavigationPath()
    @Binding var deepLinkRequest: DeepLinkRequest?
    @Binding var loggedIn: LoginState

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let conduitClient {
                    AIHomeView(
                        conduitClient: conduitClient,
                        streamingService: streamingService,
                        navigation: $navigationPath
                    )
                } else {
                    // Fallback: show the original home view rows
                    ScrollView {
                        HomeView(streamingService: streamingService, navigation: $navigationPath)
                            .scrollClipDisabled()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: BrowseDestination.browseAll) {
                        Label("Browse", systemImage: "square.grid.2x2")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: BrowseDestination.search) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: BrowseDestination.user) {
                        Label(streamingService.usersName, systemImage: "person.circle")
                    }
                }
            }
            .navigationDestination(for: BrowseDestination.self) { destination in
                switch destination {
                case .search:
                    SearchView(streamingService: streamingService, navigation: $navigationPath)
                case .browseAll:
                    BrowseAllView(streamingService: streamingService, navigation: $navigationPath)
                case .user:
                    UserView(streamingService: streamingService, loggedIn: $loggedIn)
                }
            }
            .navigationDestination(for: DeepLinkRequest.self) { request in
                MediaDetailLoader(
                    mediaID: request.mediaID,
                    parentID: request.parentID,
                    streamingService: streamingService,
                    navigation: $navigationPath
                )
            }
            .navigationDestination(for: SlimMedia.self) { slimMedia in
                MediaDetailLoader(
                    mediaID: slimMedia.id,
                    parentID: slimMedia.parentID,
                    streamingService: streamingService,
                    navigation: $navigationPath
                )
            }
            .navigationDestination(for: AnyMedia.self) { anyMedia in
                DetailMediaView(media: anyMedia.media, streamingService: streamingService, navigation: $navigationPath)
            }
        }
        .onChange(of: deepLinkRequest) { _, newValue in
            guard let request = newValue else { return }
            navigationPath.append(request) // Navigate to requested media
            deepLinkRequest = nil // Clear the request
        }
        .onChange(of: streamingService.userID, initial: true) {
            Task { await streamingService.retrieveLibraries() }
        }
    }
}

/// Navigation destinations for toolbar items
enum BrowseDestination: Hashable {
    case search
    case browseAll
    case user
}

/// A type-erased wrapper for MediaProtocol that conforms to Hashable
struct AnyMedia: Hashable {
    let media: any MediaProtocol

    static func == (lhs: AnyMedia, rhs: AnyMedia) -> Bool {
        lhs.media.id == rhs.media.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
    }
}
