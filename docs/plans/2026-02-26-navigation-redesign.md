# Navigation Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the horizontal tab bar with a native tvOS sidebar, reorganize into 4 fixed sections (Home / Live / Library / Search) plus a profile entry, and decouple library loading from app startup.

**Architecture:** The existing `Tab(value:)` API in tvOS 17+ automatically renders as a left sidebar — no custom gesture handling needed. The `libraryStatus` switch that currently gates the entire `TabView` is removed; loading/error states move inside the Library tab only. Three file changes total: `DashboardView.swift` (tab reorganization), `BrowseAllView.swift` (becomes `AllLibrariesView`), and a new `LiveView.swift`.

**Tech Stack:** SwiftUI tvOS 18, `@Observable`, native `Tab(value:)` API, existing design tokens in `DesignSystem.swift`

---

## Before You Start

**Build command (run this to verify each task):**
```bash
# On the macOS VM via MCP tool: mcp__takumi__build_ipa
# Then check: mcp__takumi__build_log
# Exit code 70 ("tvOS 18.2 not installed") is NORMAL — not an error.
# A real build failure shows in the log as "error:" lines.
```

**Key files to understand:**
- `Stingray/DashboardView.swift` — current nav hub (read this first)
- `Stingray/BrowseAllView.swift` — current Browse tab (you will rewrite this)
- `Stingray/LibraryView.swift` — single-library grid view (unchanged, but you'll use it)
- `Stingray/DesignSystem.swift` — all spacing/color/font tokens

**Types you'll use:**
- `LibraryStatus` (in `StreamingServiceModel.swift`): `.waiting | .retrieving | .available([LibraryModel]) | .complete([LibraryModel]) | .error(RError)`
- `LibraryModel`: has `.title: String`, `.id: String`, `.media: MediaStatus`
- `StreamingServiceProtocol`: has `.libraryStatus`, `.usersName: String`
- `StingrayColors.accent`, `StingraySpacing.xs/sm/md`, `StingrayFont.heroTitle/sectionTitle`

**No unit tests:** This is a tvOS UI project with no test target. Verification is by build + visual inspection on simulator.

---

### Task 1: Create `LiveView.swift` — placeholder screen

**Files:**
- Create: `Stingray/LiveView.swift`

**Step 1: Create the file**

```swift
//
//  LiveView.swift
//  Stingray
//

import SwiftUI

struct LiveView: View {
    var body: some View {
        VStack(spacing: StingraySpacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [StingrayColors.accent, StingrayColors.accentDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("Live TV")
                .font(StingrayFont.heroTitle)
            Text("Coming Soon")
                .font(StingrayFont.sectionTitle)
                .foregroundStyle(StingrayColors.textSecondary)
            Text("Live channels, free IPTV, and your personal media organized into stations.")
                .font(.body)
                .foregroundStyle(StingrayColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**Step 2: Build**

Run: `mcp__takumi__build_ipa` then `mcp__takumi__build_log`
Expected: Zero `error:` lines. Exit 70 is normal.

**Step 3: Commit**

```bash
git add Stingray/LiveView.swift
git commit -m "feat: add LiveView placeholder for future Live TV feature"
```

---

### Task 2: Rewrite `BrowseAllView.swift` as `AllLibrariesView`

Replace `BrowseAllView` with `AllLibrariesView` — a unified Library tab view that handles its own loading/error states, shows library sub-navigation, and displays either a genre-filtered aggregate grid or a single library view.

**Files:**
- Modify: `Stingray/BrowseAllView.swift` (full replacement — keep filename, replace content)

**Step 1: Read the current file**

Read `Stingray/BrowseAllView.swift` and `Stingray/LibraryView.swift` in full before writing anything.

**Step 2: Replace the entire file contents**

```swift
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
        .buttonStyle(.card)
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
                            .buttonStyle(.card)
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
```

**Step 3: Build**

Run: `mcp__takumi__build_ipa` then `mcp__takumi__build_log`
Expected: Zero `error:` lines.

If you see `error: cannot find type 'BrowseAllView'` — that's expected and will be fixed in Task 3 when DashboardView is updated. Any other errors need fixing first.

**Step 4: Commit**

```bash
git add Stingray/BrowseAllView.swift
git commit -m "feat: replace BrowseAllView with AllLibrariesView — unified library tab with sub-nav"
```

---

### Task 3: Refactor `DashboardView.swift` — new sidebar tabs

Remove the `libraryStatus` outer switch. Replace all current tabs with: Home, Live, Library, Search, Profile.

**Files:**
- Modify: `Stingray/DashboardView.swift` (full replacement)

**Step 1: Read the current file**

Read `Stingray/DashboardView.swift` in full. Understand the current structure before replacing it.

**Step 2: Replace the entire file contents**

```swift
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
            TabView(selection: $selectedTab) {
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
                    Label("Home", systemImage: "house.fill")
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
```

**Step 3: Build**

Run: `mcp__takumi__build_ipa` then `mcp__takumi__build_log`
Expected: Zero `error:` lines.

**Common errors and fixes:**
- `error: cannot find 'BrowseAllView'` — you forgot to rename it in Task 2; check that `AllLibrariesView` exists in BrowseAllView.swift
- `error: 'LibraryView' requires...` — check the LibraryView init signature matches what you're calling. It is: `LibraryView(library:, navigation:, streamingService:)`
- Any other error: read it carefully, fix the specific line, re-build

**Step 4: Commit**

```bash
git add Stingray/DashboardView.swift
git commit -m "feat: replace tab bar with sidebar nav — Home/Live/Library/Search/Profile"
```

---

### Task 4: Final build verification

**Step 1: Clean build to confirm no lingering issues**

Run: `mcp__takumi__build_ipa` (with `clean: true` if the tool supports it, otherwise just run normally)
Then: `mcp__takumi__build_log`
Expected: Zero `error:` lines.

**Step 2: Verify sidebar renders correctly (if simulator available)**

Run: `mcp__takumi__simulator_run` then `mcp__takumi__simulator_screenshot`

Expected:
- App launches to Home tab immediately (no loading gate)
- Left sidebar is accessible via remote left-swipe
- Sidebar shows: Home / Live / Library / Search / [username]
- Live tab shows the placeholder screen (icon + "Coming Soon")
- Library tab shows loading spinner initially, then library selector + grid
- Profile tab shows user switching screen

**Step 3: Commit if anything was fixed**

If you had to fix any errors in steps above:
```bash
git add -p   # stage only the fix
git commit -m "fix: <describe what you fixed>"
```

---

## Notes for the Implementer

**tvOS sidebar behavior:** The existing `Tab(value:)` API renders as a sidebar on tvOS 17+. You do NOT need to add `.tabViewStyle()` — it's automatic. If the sidebar doesn't appear after implementation, add `.tabViewStyle(.sidebarAdaptable)` to the `TabView` as a diagnostic step.

**`LibraryView` init:** The existing `LibraryView` signature is:
```swift
public struct LibraryView: View {
    @State var library: any LibraryProtocol
    @Binding var navigation: NavigationPath
    let streamingService: StreamingServiceProtocol
```
Initialize it as: `LibraryView(library: library, navigation: $navigation, streamingService: streamingService)`

**`MediaProtocol.genres`:** Exists — used in the original BrowseAllView. Safe to use in AllMediaView.

**File auto-inclusion:** New `.swift` files in `Stingray/` are automatically compiled. No Xcode project file changes needed.

**Do not change:**
- `HomeView.swift` — content redesign is future work
- `SearchView.swift` — no changes needed
- `UserView.swift` — no changes needed
- Any `navigationDestination` handlers — they are moved but unchanged
