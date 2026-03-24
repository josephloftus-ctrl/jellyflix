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
    var suriClient: SuriClient?
    @State private var selectedTab: String = "home"
    @State private var navigationPath = NavigationPath()
    @Binding var deepLinkRequest: DeepLinkRequest?
    @Binding var loggedIn: LoginState

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                Tab(value: "home") {
                    if let conduitClient {
                        AIHomeView(
                            conduitClient: conduitClient,
                            suriClient: suriClient,
                            streamingService: streamingService,
                            navigation: $navigationPath
                        )
                    } else {
                        ScrollView {
                            HomeView(streamingService: streamingService, navigation: $navigationPath)
                                .scrollClipDisabled()
                        }
                    }
                } label: {
                    Label("Home", systemImage: "house.fill")
                }

                if let suriClient {
                    Tab(value: "downloads") {
                        DownloadsView(suriClient: suriClient)
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }
                }

                Tab(value: "live") {
                    LiveView()
                } label: {
                    Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                }

                Tab(value: "library") {
                    AllLibrariesView(streamingService: streamingService, navigation: $navigationPath)
                } label: {
                    Label("Library", systemImage: "books.vertical.fill")
                }

                Tab(value: "search") {
                    SearchView(streamingService: streamingService, navigation: $navigationPath)
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                Tab(value: "profile") {
                    UserView(streamingService: streamingService, loggedIn: $loggedIn)
                } label: {
                    Label(streamingService.usersName, systemImage: "person.fill")
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
            navigationPath.append(request)
            deepLinkRequest = nil
        }
        .onChange(of: streamingService.userID, initial: true) {
            self.selectedTab = "home"
            Task { await streamingService.retrieveLibraries() }
        }
    }
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
