//
//  BrowseAllView.swift
//  Stingray
//

import SwiftUI

// MARK: - AllLibrariesView (Library tab root)

/// The root view for the Library sidebar tab.
/// Handles all library loading states internally, shows library sub-navigation,
/// and renders either an aggregate genre-filtered grid or a single library's content.
struct AllLibrariesView: View {
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    @State private var selectedLibraryID: String = "all"
    @State private var selectedGenre: String = "All"

    var body: some View {
        Group {
            switch streamingService.libraryStatus {
            case .waiting, .retrieving:
                VStack(spacing: StingraySpacing.md) {
                    ProgressView()
                    Text("Loading Library...")
                        .foregroundStyle(StingrayColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .error(let err):
                VStack {
                    ErrorView(error: err, summary: "The server formatted the library's metadata unexpectedly.")
                    SystemInfoView(streamingService: streamingService)
                }

            case .available(let libraries), .complete(let libraries):
                VStack(alignment: .leading, spacing: 0) {
                    LibrarySelectorRow(
                        libraries: libraries,
                        selectedLibraryID: $selectedLibraryID,
                        selectedGenre: $selectedGenre
                    )
                    .focusSection()

                    if selectedLibraryID == "all" {
                        AllMediaView(
                            libraries: libraries,
                            selectedGenre: $selectedGenre,
                            streamingService: streamingService,
                            navigation: $navigation
                        )
                    } else if let library = libraries.first(where: { $0.id == selectedLibraryID }) {
                        LibraryView(
                            library: library,
                            navigation: $navigation,
                            streamingService: streamingService
                        )
                    }
                }
            }
        }
        .onChange(of: streamingService.userID) {
            selectedLibraryID = "all"
            selectedGenre = "All"
        }
    }
}

// MARK: - Library Selector Row

private struct LibrarySelectorRow: View {
    let libraries: [LibraryModel]
    @Binding var selectedLibraryID: String
    @Binding var selectedGenre: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StingraySpacing.xs) {
                LibrarySelectorButton(title: "All", isSelected: selectedLibraryID == "all") {
                    selectedLibraryID = "all"
                    selectedGenre = "All"
                }
                ForEach(libraries) { library in
                    LibrarySelectorButton(title: library.title, isSelected: selectedLibraryID == library.id) {
                        selectedLibraryID = library.id
                        selectedGenre = "All"
                    }
                }
            }
            .padding(.horizontal, 48)
        }
    }
}

private struct LibrarySelectorButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, StingraySpacing.sm)
                .padding(.vertical, StingraySpacing.xs)
                .background(isSelected ? StingrayColors.accent : Color.gray.opacity(0.3))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Media View (genre-filtered aggregate)

private struct AllMediaView: View {
    let libraries: [LibraryModel]
    @Binding var selectedGenre: String
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    private var allMedia: [any MediaProtocol] {
        libraries.flatMap { library -> [any MediaProtocol] in
            switch library.media {
            case .available(let media), .complete(let media):
                return media
            default:
                return []
            }
        }
    }

    private var genres: [String] {
        var genreSet: Set<String> = []
        for media in allMedia { genreSet.formUnion(media.genres) }
        return ["All"] + genreSet.sorted()
    }

    private var filteredMedia: [any MediaProtocol] {
        if selectedGenre == "All" { return allMedia }
        return allMedia.filter { $0.genres.contains(selectedGenre) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if genres.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StingraySpacing.xs) {
                        ForEach(genres, id: \.self) { genre in
                            Button { selectedGenre = genre } label: {
                                Text(genre)
                                    .padding(.horizontal, StingraySpacing.sm)
                                    .padding(.vertical, StingraySpacing.xs)
                                    .background(selectedGenre == genre ? StingrayColors.accent.opacity(0.6) : Color.gray.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 48)
                }
                .focusSection()
            }

            ScrollView {
                if allMedia.isEmpty {
                    VStack(spacing: StingraySpacing.sm) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Library is loading or empty.")
                            .foregroundStyle(StingrayColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, StingraySpacing.xl)
                } else {
                    MediaGridView(
                        allMedia: filteredMedia,
                        streamingService: streamingService,
                        navigation: $navigation
                    )
                    .padding(.horizontal, 48)
                }
            }
        }
    }
}
