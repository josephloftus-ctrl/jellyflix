# Jellyflix UI Bug Fix & Targeted Polish
**Date:** 2026-02-25
**Scope:** Option B — Fix focus navigation bugs, layout issues, broken placeholders, and targeted visual polish

---

## Problem Summary

Three categories of issues making the app feel broken and cheap:

1. **Focus navigation** — remote gets lost/stuck unpredictably across all screens
2. **Layout bugs** — clipping, wrong sizes, overlapping elements; detail page is worst offender
3. **Loading/placeholder states** — broken visually (wrong images, no sizing, generic)
4. **Visual cheapness** — small card text, cluttered section headers, generic placeholders

---

## Section 1: Focus Navigation Fixes

### 1.1 `EpisodeView` — duplicate `focused()` modifier
**File:** `Stingray/DetailMediaView.swift` (~line 643)
**Bug:** Description `Button` has `focused($isFocused, equals: true)` applied twice. tvOS cannot determine which view owns focus.
**Fix:** Remove the duplicate modifier. Keep only the one on `EpisodeNavigationView` (thumbnail button).

### 1.2 `PlayNavigationView` — 500ms sleep race condition
**File:** `Stingray/DetailMediaView.swift` (~line 209)
**Bug:** `task { try? await Task.sleep(500ms); self.focus = .play }` is a timing hack. If the view loads slowly, focus never lands on the play button.
**Fix:** Remove the sleep-based task. Use `onAppear` + `defaultFocus($focus, .play, priority: .userInitiated)` which is the tvOS-native pattern for initial focus assignment.

### 1.3 `SeasonSelectorView` — focus trap on nil lastFocusedSeasonID
**File:** `Stingray/DetailMediaView.swift` (~line 462)
**Bug:** When `focus == nil`, all seasons except `lastFocusedSeasonID` are disabled. If `lastFocusedSeasonID` was never set (first appearance), all seasons are disabled and focus has nowhere to go.
**Fix:** Initialize `lastFocusedSeasonID` to `seasons.first?.id` on `.onAppear` as a fallback default.

---

## Section 2: Layout Fixes

### 2.1 `ActorImage` + `PeopleBrowserView` — unconstrained actor card sizing
**File:** `Stingray/DetailMediaView.swift` (~line 688, 750)
**Bug:** `ActorImage` has no frame. Outer `Button` sets `width: 300` but no height. Photos collapse or stretch based on image dimensions.
**Fix:** Add `.aspectRatio(2/3, contentMode: .fill)` to `ActorImage` image views and `.clipped()`. This gives all actor cards a uniform 300×450 portrait size.

### 2.2 `MediaLogoView` — logo can be arbitrarily tall
**File:** `Stingray/DetailMediaView.swift` (~line 271)
**Bug:** Logo image sets `width: 400` but no height limit. Tall logos push tagline and metadata offscreen.
**Fix:** Add `.frame(maxHeight: 160)` to the logo `AsyncImage`.

### 2.3 `EpisodeView` description card — broken padding arithmetic
**File:** `Stingray/DetailMediaView.swift` (~line 592)
**Bug:** Description button applies `.padding(16)` then `.padding(-16)` to achieve a background shape inside a fixed frame. The negative padding causes clipping on some tvOS layouts.
**Fix:** Restructure as a `ZStack` — `RoundedRectangle` background behind the content VStack. Eliminates the padding arithmetic entirely.

### 2.4 `SpecialFeaturesRow` — `ArtView` has no minimum height
**File:** `Stingray/DetailMediaView.swift` (~line 860)
**Bug:** `ArtView` constrained to `maxHeight: 250` but no minimum. Images render at 0 height until loaded, causing layout jump.
**Fix:** Replace `maxHeight: 250` with fixed `frame(height: 220)` + `.clipped()`.

---

## Section 3: Placeholder & Loading Fixes

### 3.1 `ActorImage` — wrong blurHash for actor photos
**File:** `Stingray/DetailMediaView.swift` (~line 696)
**Bug:** Uses the movie's backdrop blurHash as placeholder for actor headshots. A 16:9 landscape image is stretched into a 2:3 portrait slot.
**Fix:** Remove the backdrop blurHash fallback. Use `Color(white: 0.15)` as a neutral placeholder matching the card shape.

### 3.2 `MediaCardLoading` — no shape, flat pulse
**File:** `Stingray/MediaCardView.swift` (~line 91)
**Bug:** Pulsing skeleton has no rounded corners and no visual relationship to the card it's inside. Opacity range (0.15→0.25) is too high — too much visual noise.
**Fix:** Wrap in `RoundedRectangle(cornerRadius: 12).fill(...)` and narrow opacity range to 0.08→0.20.

### 3.3 `DashboardView` loading state — generic system icon
**File:** `Stingray/DashboardView.swift` (~line 22)
**Bug:** Shows `Image(systemName: "play.rectangle.fill")` + text when libraries load. Looks like an unfinished placeholder.
**Fix:** Replace with a `ScrollView` containing a row of `SkeletonCard` views — consistent with how individual content rows load.

### 3.4 `SpecialFeaturesView` loading spinner — unstyled, no frame
**File:** `Stingray/DetailMediaView.swift` (~line 807)
**Bug:** `ProgressView("Loading special features...")` has no frame or minimum height. Causes layout jump when content appears.
**Fix:** Wrap in `.frame(minHeight: 200)` centered container.

---

## Section 4: Targeted Visual Polish

### 4.1 Card title font size — too small to read at 10 feet
**File:** `Stingray/DesignSystem.swift` (line 38)
**Change:** `cardTitle: Font = .caption.bold()` → `.footnote.bold()`
**Impact:** Every media card in the app. One line change.

### 4.2 Section header pills — visual clutter
**File:** `Stingray/HomeView.swift` (~line 82)
**Change:** Remove `.glassBackground(cornerRadius: 12, padding: 8)` from section title `Text`. Keep `StingrayFont.sectionTitle` font with consistent `.padding(.horizontal, StingraySpacing.sm)`.
**Rationale:** Floating glass pills compete visually with content. Plain bold text with consistent padding is cleaner and matches native tvOS conventions.

### 4.3 `MediaCardNoImage` — flat gray box with label
**File:** `Stingray/MediaCardView.swift` (~line 103)
**Change:** Replace flat `Color.gray.opacity(0.15)` + system icon + text label with a subtle two-stop linear gradient (`Color(white: 0.12)` → `Color(white: 0.18)`) and the `photo` icon only (no text label).

### 4.4 `SystemInfoView` — wrong app name
**File:** `Stingray/HomeView.swift` (~line 262)
**Change:** `"Stingray v\(version)"` → `"Jellyflix v\(version)"`

### 4.5 Actor card image — no clip shape
**File:** `Stingray/DetailMediaView.swift` (~line 703)
**Change:** Add `.clipShape(RoundedRectangle(cornerRadius: 16))` to the `AsyncImage` inside `ActorImage` so the portrait photo is properly rounded to match its container.

---

## Files Changed

| File | Sections |
|------|----------|
| `Stingray/DesignSystem.swift` | 4.1 |
| `Stingray/HomeView.swift` | 4.2, 4.4 |
| `Stingray/MediaCardView.swift` | 3.2, 4.3 |
| `Stingray/DashboardView.swift` | 3.3 |
| `Stingray/DetailMediaView.swift` | 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 3.1, 3.4, 4.5 |

**Total:** 5 files, 15 targeted changes.

---

## Out of Scope

- Color palette changes (user said look is "okay")
- Navigation stack restructure
- New features or screens
- Player view changes
