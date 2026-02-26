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
    @State private var selectedTab: String = "home"
    @State private var navigationPath = NavigationPath()
    @Binding var deepLinkRequest: DeepLinkRequest?
    @Binding var loggedIn: LoginState

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                switch streamingService.libraryStatus {
                case .waiting, .retrieving:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in
                                VStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 160, height: 24)
                                        .padding(.horizontal, StingraySpacing.sm)
                                    ScrollView(.horizontal) {
                                        HStack(spacing: StingraySpacing.md) {
                                            ForEach(0..<5, id: \.self) { index in
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(Double(1 - Double(index) / 5.0) * 0.15))
                                                    .frame(width: 240, height: 420)
                                            }
                                        }
                                        .padding(.horizontal, StingraySpacing.sm)
                                    }
                                }
                                .padding(.vertical)
                            }
                        }
                    }
                case .error(let err):
                    VStack {
                        ErrorView(error: err, summary: "The server formatted the library's metadata unexpectedly.")
                        SystemInfoView(streamingService: streamingService)
                    }
                case .available(let libraries), .complete(let libraries):
                    TabView(selection: $selectedTab) {
                        Tab(value: "users") {
                            UserView(streamingService: streamingService, loggedIn: $loggedIn)
                        } label: {
                            Text(streamingService.usersName)
                        }

                        Tab(value: "search") {
                            SearchView(streamingService: streamingService, navigation: $navigationPath)
                        } label: {
                            Text("Search")
                        }

                        Tab(value: "home") {
                            if let conduitClient {
                                AIHomeView(
                                    conduitClient: conduitClient,
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
                            Text("Home")
                        }

                        Tab(value: "browse") {
                            BrowseAllView(streamingService: streamingService, navigation: $navigationPath)
                        } label: {
                            Text("Browse")
                        }

                        ForEach(libraries.indices, id: \.self) { index in
                            Tab(value: libraries[index].id) {
                                LibraryView(library: libraries[index], navigation: $navigationPath, streamingService: streamingService)
                            } label: {
                                Text(libraries[index].title)
                            }
                        }
                    }
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
