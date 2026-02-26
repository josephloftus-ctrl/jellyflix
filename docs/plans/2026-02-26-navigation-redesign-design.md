# Navigation Redesign Design

**Date:** 2026-02-26
**Status:** Approved

---

## Goal

Replace the standard horizontal tvOS tab bar with a native sidebar navigation, reorganizing the app into 4 fixed top-level sections: Home, Live, Library, and Search. Profile/user switching moves to the sidebar bottom. Library loading is decoupled from app startup so Home and Search are immediately usable.

## Navigation Pattern

**Native `TabView` with tvOS sidebar behavior (tvOS 17+).** The existing `Tab(value:)` API already wires into tvOS's built-in left-rail sidebar. No custom overlay or gesture handling. Press left on the remote to reveal the sidebar; press right or select to collapse it into content. The platform owns this behavior entirely.

> Philosophy: work with the platform, never against it.

## Sidebar Structure

```
┌──────────────┐
│ 🏠  Home     │
│ 📡  Live     │
│ 📚  Library  │
│ 🔍  Search   │
│              │
│ 👤  [User]   │  ← profile entry at bottom
└──────────────┘
```

**Removed from sidebar:**
- Individual library tabs (Movies, Shows, etc.) — moved inside Library as sub-navigation
- Dedicated Users tab — collapsed into profile entry at sidebar bottom
- Browse tab — replaced by Library

## Tab Breakdown

### Home
No content changes in this sprint. "For You" landing page with Next Up, Recently Added, etc. Moves cleanly into the new sidebar slot. Content redesign (better utilization of the full page) is a separate future brainstorm.

### Live
Intentional placeholder screen — not a skeleton, not an error. A centered card with icon and "Live TV — Coming Soon" copy. Gives the section presence in nav without implying it's broken. Full feature: linear "TV station" experience drawing from personal library, free IPTV channels, and YouTube downloads organized into running channels with a channel guide. Designed separately.

### Library
Replaces both `BrowseAllView` and the dynamic per-library tabs. Internal sub-navigation row at the top of the view: `All | Movies | Shows | [dynamic tabs from libraries data]`. The `libraries` array (already fetched by `streamingService`) feeds these sub-filters instead of top-level sidebar tabs.

### Search
Unchanged. Same `SearchView`, re-homed into the new sidebar slot.

### Profile (sidebar bottom)
Shows current user's display name. Tapping navigates into the existing `UserView` (user switching, logout). No new data fetching — reads `streamingService.userID` which is already available.

## Architecture & State Changes

### `DashboardView.swift`
- **Remove** the `libraryStatus` switch that wraps the entire `TabView`
- **Replace** with a plain `TabView` always showing 4 fixed tabs + profile entry
- `selectedTab` values: `"home" | "live" | "library" | "search"` (remove `"users"`, `"browse"`, dynamic library IDs)
- **Remove** `ForEach(libraries.indices)` dynamic tab loop — `libraries` passed to `LibraryView` instead
- Profile entry at sidebar bottom navigates into `UserView`
- `onChange(of: streamingService.userID)` stays: resets `selectedTab = "home"`, re-fetches libraries

### `LibraryView.swift` (modified from `BrowseAllView`)
- **Owns** the `libraryStatus` switch (loading/error/content states)
- Shows skeleton and error states internally — no longer app-level
- `libraries` array drives internal sub-nav row (`All | Movies | Shows | ...`)
- Empty state: explicit "No libraries found" message when `libraries` is empty

### New: `LiveView.swift`
- Static placeholder view
- Centered layout: icon + title + teaser copy
- No data fetching, no state

### Unchanged
- `HomeView.swift` — content identical, just re-homed
- `SearchView.swift` — no changes
- `UserView.swift` — no changes
- `NavigationStack`, `navigationPath`, `deepLinkRequest` — all push navigation identical
- All `navigationDestination` handlers — unchanged

## Data Flow

```
DashboardView
├── streamingService (passed to all tabs)
├── TabView (always rendered, no libraryStatus gate)
│   ├── HomeView          (immediate, no library dependency)
│   ├── LiveView          (static placeholder)
│   ├── LibraryView       (owns libraryStatus, gets libraries from streamingService)
│   ├── SearchView        (immediate)
│   └── [Profile entry]   (reads streamingService.userID)
└── NavigationStack destinations (unchanged)
```

## Error Handling

| Scenario | Before | After |
|---|---|---|
| Library load error | Blocks entire app, full-screen error | Scoped to Library tab only |
| Library loading | Blocks entire app, skeleton rows | Library tab shows skeleton internally |
| No libraries returned | Empty ForEach (invisible) | Explicit empty state in Library tab |
| Deep links | Appends to navigationPath | Identical — NavigationStack unaffected by tab changes |
| User switch | Resets tab to "home", re-fetches | Identical behavior |
| Not logged in | DashboardView not rendered (parent gate) | Identical — no nil-user case possible |

## Files Touched

| File | Change |
|---|---|
| `Stingray/DashboardView.swift` | Remove libraryStatus switch, reorganize tabs, add profile entry |
| `Stingray/BrowseAllView.swift` | Extend into `LibraryView` with internal sub-nav and status handling |
| `Stingray/LiveView.swift` | **New** — static placeholder |
| `Stingray/HomeView.swift` | No changes (content redesign is future work) |
| `Stingray/SearchView.swift` | No changes |

## Out of Scope (Future)

- Home page content redesign ("For You" better utilization)
- Live TV feature implementation (IPTV scraper, channel guide, YouTube aggregator)
- Library smart category generation (genre, decade, mood)
- Music app (Navidrome-compatible, separate project)
