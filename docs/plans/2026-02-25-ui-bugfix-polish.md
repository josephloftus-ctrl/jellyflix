# Jellyflix UI Bug Fix & Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix focus navigation bugs, layout issues, broken placeholders, and apply targeted visual polish across the Jellyflix tvOS app.

**Architecture:** All changes are isolated to 5 existing Swift files. No new files, no new dependencies. Tasks grouped by file to minimize context-switching. No automated test suite exists — verification is by successful Xcode build (`mcp__takumi__build_ipa`).

**Tech Stack:** Swift, SwiftUI, tvOS 16+, AVKit, BlurHashKit. Build via macOS VM using `mcp__takumi__build_ipa`.

**Design doc:** `docs/plans/2026-02-25-ui-bugfix-polish-design.md`

---

## Build Command Reference

To verify changes compile:
```
Use mcp__takumi__build_ipa tool (sync: true, scheme: "Stingray", platform: "tvOS")
```
Check output for errors. Warnings are acceptable, errors are not.

---

### Task 1: DesignSystem — card title font size

**Files:**
- Modify: `Stingray/DesignSystem.swift:38`

**Step 1: Make the change**

In `DesignSystem.swift`, line 38, change:
```swift
// Before
static let cardTitle: Font = .caption.bold()

// After
static let cardTitle: Font = .footnote.bold()
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DesignSystem.swift
git commit -m "style: bump cardTitle font from caption to footnote for readability"
```

---

### Task 2: HomeView — rename Stingray to Jellyflix in footer

**Files:**
- Modify: `Stingray/HomeView.swift:262`

**Step 1: Make the change**

In `SystemInfoView.body`, find the text that reads `"Stingray v\(stingrayVersion)"` and change both the variable name reference and the string prefix:

```swift
// Before
if let stingrayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    Text("Stingray v\(stingrayVersion)")
}
else { Text("Unknown Stingray Version") }

// After
if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    Text("Jellyflix v\(version)")
}
else { Text("Unknown Jellyflix Version") }
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/HomeView.swift
git commit -m "fix: rename Stingray to Jellyflix in system info footer"
```

---

### Task 3: HomeView — remove section header glass pills

**Files:**
- Modify: `Stingray/HomeView.swift` (DashboardRow body, ~line 82)

**Step 1: Make the change**

In `DashboardRow.body`, the section title `Text` has `.glassBackground(cornerRadius: 12, padding: 8)`. Remove that modifier and add consistent left padding:

```swift
// Before
Text(title)
    .font(StingrayFont.sectionTitle)
    .padding(.horizontal, StingraySpacing.xs)
    .padding(.vertical, 6)
    .glassBackground(cornerRadius: 12, padding: 8)
    .task { ... }

// After
Text(title)
    .font(StingrayFont.sectionTitle)
    .padding(.horizontal, StingraySpacing.sm)
    .task { ... }
```

Note: Keep the `.task { ... }` attached to the `Text` — that's where the fetch logic lives.

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/HomeView.swift
git commit -m "style: remove glass pill from section headers, use plain bold text"
```

---

### Task 4: MediaCardView — fix skeleton loading card

**Files:**
- Modify: `Stingray/MediaCardView.swift` (MediaCardLoading, ~line 91)

**Step 1: Make the change**

Replace the `MediaCardLoading` body with a version that has a rounded shape and subtler pulse:

```swift
struct MediaCardLoading: View {
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(pulse ? 0.20 : 0.08))
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/MediaCardView.swift
git commit -m "style: fix skeleton card shape and refine pulse opacity range"
```

---

### Task 5: MediaCardView — improve no-image placeholder

**Files:**
- Modify: `Stingray/MediaCardView.swift` (MediaCardNoImage, ~line 103)

**Step 1: Make the change**

Replace the flat gray + text label with a gradient and icon only:

```swift
struct MediaCardNoImage: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.19)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/MediaCardView.swift
git commit -m "style: replace flat gray no-image placeholder with subtle gradient"
```

---

### Task 6: DashboardView — replace loading state with skeletons

**Files:**
- Modify: `Stingray/DashboardView.swift` (~line 22)

**Step 1: Make the change**

In `DashboardView.body`, the `.waiting`/`.retrieving` case shows a generic icon. Replace it with skeleton rows that match the home screen structure:

```swift
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
                                SkeletonCard(isHero: false)
                                    .opacity(Double(1 - (Double(index) / 5.0)))
                            }
                        }
                        .padding(.horizontal, StingraySpacing.sm)
                    }
                }
                .padding(.vertical)
            }
        }
    }
```

Note: `SkeletonCard` is defined as `fileprivate` in `HomeView.swift`. Either:
- Make it `internal` (remove `fileprivate`) so `DashboardView` can use it, OR
- Inline a simplified version as shown above (recommended — avoids changing visibility)

Use the inline approach shown above.

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DashboardView.swift
git commit -m "style: replace generic loading icon with skeleton content rows"
```

---

### Task 7: DetailMediaView — fix ActorImage wrong blurHash and missing clip

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (ActorImage, ~line 688)

**Step 1: Make the change**

Replace `ActorImage` body. Remove the wrong backdrop blurHash placeholder. Add `clipShape` to the async image:

```swift
fileprivate struct ActorImage: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    let person: any MediaPersonProtocol

    var body: some View {
        ZStack {
            Color(white: 0.15)
            if let url = streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 0) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    EmptyView()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

Note: Removed `@State private var imageOpacity` — it wasn't being used in the original.

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: use neutral placeholder for actor images, remove wrong backdrop blurHash"
```

---

### Task 8: DetailMediaView — fix actor card sizing in PeopleBrowserView

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (PeopleBrowserView, ~line 750)

**Step 1: Make the change**

In `PeopleBrowserView`, the actor `Button` label has `ActorImage` with no frame. Add a fixed frame with 2:3 aspect ratio:

```swift
// Before
VStack {
    ActorImage(media: media, streamingService: streamingService, person: person)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: 300)
    Text(person.name)
        ...
}

// After
VStack {
    ActorImage(media: media, streamingService: streamingService, person: person)
        .frame(width: 200, height: 300)
    Text(person.name)
        ...
}
```

Note: `ActorImage` now has `.clipShape` inside it (from Task 7), so remove the external `.clipShape` here. Width reduced from 300 to 200 — actor cards at 300pt wide are oversized next to the 240pt media cards.

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: constrain actor card to 200x300 portrait frame"
```

---

### Task 9: DetailMediaView — cap logo image height

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (MediaLogoView, ~line 271)

**Step 1: Make the change**

In `MediaLogoView.body`, add `frame(maxHeight: 160)` to the logo `AsyncImage`:

```swift
// Before
AsyncImage(url: logoImageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .opacity(logoOpacity)
        .animation(StingrayAnimation.fadeIn, value: logoOpacity)
        .onAppear { logoOpacity = 1 }
} placeholder: {
    EmptyView()
}
.frame(width: 400)

// After
AsyncImage(url: logoImageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .opacity(logoOpacity)
        .animation(StingrayAnimation.fadeIn, value: logoOpacity)
        .onAppear { logoOpacity = 1 }
} placeholder: {
    EmptyView()
}
.frame(maxWidth: 400, maxHeight: 160)
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: cap media logo height at 160pt to prevent layout overflow"
```

---

### Task 10: DetailMediaView — fix SpecialFeaturesRow ArtView height

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (SpecialFeaturesRow, ~line 860)

**Step 1: Make the change**

In `SpecialFeaturesRow.body`, find the `ArtView` and change from `maxHeight` to fixed `frame`:

```swift
// Before
ArtView(media: specialFeature, streamingService: self.streamingService)
    .frame(maxHeight: 250)

// After
ArtView(media: specialFeature, streamingService: self.streamingService)
    .frame(height: 220)
    .clipped()
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: use fixed height for special features art to prevent layout jump"
```

---

### Task 11: DetailMediaView — add frame to SpecialFeaturesView loading state

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (SpecialFeaturesView, ~line 807)

**Step 1: Make the change**

In `SpecialFeaturesView.body`, the `.loading` case shows an unstyled `ProgressView`. Wrap it:

```swift
// Before
case .loading:
    ProgressView("Loading special features...")

// After
case .loading:
    ProgressView()
        .frame(maxWidth: .infinity, minHeight: 200)
```

Note: Removed the label string — on tvOS, `ProgressView` with a string label looks different from iOS. Plain spinner is cleaner here.

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: add minimum height to special features loading spinner"
```

---

### Task 12: DetailMediaView — fix EpisodeView description card padding arithmetic

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (EpisodeView, ~line 592)

**Step 1: Understand the current structure**

The description button currently does:
```swift
Button { ... } label: {
    VStack(alignment: .leading) { ... }
    .frame(width: 400, height: 225)
    .padding(16)
    .background {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(isFocused ? 0.1 : 0))
    }
    .padding(-16)
}
.buttonStyle(.plain)
```

The `.padding(16)` + `.padding(-16)` is trying to make the background extend to the edge while keeping content inset. This is fragile.

**Step 2: Make the change**

Restructure as a `ZStack` — background behind content:

```swift
Button {
    self.showDetails = episode.overview != nil
} label: {
    ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(isFocused ? 0.1 : 0))
        VStack(alignment: .leading) {
            // Season and episode number
            HStack(spacing: 0) {
                if let season = (seasons.first { $0.episodes.contains { $0.id == episode.id } }) {
                    Text("\(season.title), ")
                }
                Text("Episode \(episode.episodeNumber)")
                Spacer()
            }
            .opacity(episode.overview != nil ? 0.5 : 1)

            if let overview = episode.overview {
                VStack(alignment: .leading, spacing: 0) {
                    Text(overview)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .sheet(isPresented: $showDetails) {
                    VStack {
                        Spacer()
                        MediaLogoView(
                            media: media,
                            logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
                        )
                        .padding()
                        Spacer()
                        Text(overview)
                            .padding()
                        Spacer()
                    }
                }
            } else {
                Text("No Description Available")
                    .opacity(0.5)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 400, height: 225)
    }
    .frame(width: 400, height: 225)
}
.buttonStyle(.plain)
.focused($isFocused, equals: true)
.focused($focus, equals: .media(episode.id))
```

**Step 3: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 4: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: restructure episode description card as ZStack to fix clipping"
```

---

### Task 13: DetailMediaView — fix SeasonSelectorView focus trap

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (SeasonSelectorView, ~line 462)

**Step 1: Make the change**

Add `.onAppear` to initialize `lastFocusedSeasonID` to the first season's ID so the disabled logic always has a valid default:

```swift
// In SeasonSelectorView body, after the ForEach closing brace and .onChange:

.onChange(of: focus) { _, newValue in
    switch newValue {
    case .media(let mediaID):
        if let season = seasons.first(where: { $0.episodes.contains { $0.id == mediaID } }) {
            lastFocusedSeasonID = season.id
        }
    default:
        break
    }
}
.onAppear {
    if lastFocusedSeasonID == nil {
        lastFocusedSeasonID = seasons.first?.id
    }
}
```

**Step 2: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 3: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: initialize lastFocusedSeasonID to prevent season selector focus trap"
```

---

### Task 14: DetailMediaView — fix duplicate focused modifier on EpisodeView

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (EpisodeView, ~line 643)

**Step 1: Understand the issue**

In `EpisodeView.body`, the description `Button` (bottom half) has:
```swift
.focused($isFocused, equals: true)      // line 643
.focused($focus, equals: .media(episode.id))  // line 644
```

And `EpisodeNavigationView` (thumbnail button) also applies `focused($isFocused, equals: true)` via:
```swift
.focused($isFocused, equals: true)  // on EpisodeNavigationView
```

Two different views in the same VStack both bind to `$isFocused` — tvOS gets confused about which one owns focus. The description button should NOT be separately focusable; it opens a sheet when the thumbnail is selected.

**Step 2: Make the change**

After Task 12 restructures the description button, verify it has exactly ONE `focused` modifier. The description `Button` should only have `.focused($focus, equals: .media(episode.id))` if needed for the overview context, or remove it entirely since `EpisodeNavigationView` already handles the media focus binding.

Remove the duplicate `focused($isFocused, equals: true)` from the description Button. The `EpisodeNavigationView` thumbnail is the primary focusable element. The description button uses `.buttonStyle(.plain)` and should not compete for focus:

```swift
// Description button - at end of label modifiers
.buttonStyle(.plain)
// Remove: .focused($isFocused, equals: true)  ← DELETE THIS LINE
.focused($focus, equals: .media(episode.id))
```

**Step 3: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 4: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: remove duplicate focused modifier from episode description button"
```

---

### Task 15: DetailMediaView — replace sleep hack in PlayNavigationView

**Files:**
- Modify: `Stingray/DetailMediaView.swift` (DetailMediaView, ~line 209)

**Step 1: Understand the current hack**

```swift
.task { // Yep. I hate it too.
    try? await Task.sleep(for: .milliseconds(500))
    self.focus = .play
}
```

This fires 500ms after the view appears. If the view loads faster than 500ms, there's an unnecessary delay. If it loads slower (e.g. slow image load), focus never lands correctly.

**Step 2: Make the change**

Remove the `.task` sleep hack. The `PlayNavigationView` already has `.onAppear { self.focus = .play }` and `.defaultFocus($focus, .play, priority: .userInitiated)` at lines 442 and 445. The task on the parent `DetailMediaView` is redundant and harmful.

In `DetailMediaView.body`, find and remove:
```swift
.task { // Yep. I hate it too. Apple TVs are having issues selecting the play button if it changes type.
    try? await Task.sleep(for: .milliseconds(500))
    self.focus = .play
}
```

If the `PlayNavigationView` sub-component's own `.onAppear { self.focus = .play }` and `.defaultFocus` aren't sufficient, add `onAppear` on `PlayNavigationView` at the call site:

```swift
PlayNavigationView(focus: $focus, navigation: $navigation, media: media, streamingService: streamingService)
    .disabled({ ... }())
```

Leave as-is after removing the task — `PlayNavigationView` handles its own initial focus.

**Step 3: Build to verify**

Run `mcp__takumi__build_ipa`. Expected: build succeeds.

**Step 4: Commit**
```bash
git add Stingray/DetailMediaView.swift
git commit -m "fix: remove 500ms sleep hack for play button focus, rely on defaultFocus"
```

---

## Summary

| Task | File | Type |
|------|------|------|
| 1 | DesignSystem.swift | Visual polish |
| 2 | HomeView.swift | Rename |
| 3 | HomeView.swift | Visual polish |
| 4 | MediaCardView.swift | Placeholder fix |
| 5 | MediaCardView.swift | Visual polish |
| 6 | DashboardView.swift | Loading fix |
| 7 | DetailMediaView.swift | Layout + placeholder fix |
| 8 | DetailMediaView.swift | Layout fix |
| 9 | DetailMediaView.swift | Layout fix |
| 10 | DetailMediaView.swift | Layout fix |
| 11 | DetailMediaView.swift | Loading fix |
| 12 | DetailMediaView.swift | Layout fix |
| 13 | DetailMediaView.swift | Focus fix |
| 14 | DetailMediaView.swift | Focus fix |
| 15 | DetailMediaView.swift | Focus fix |

**15 tasks, 5 files, all isolated changes.**
