# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Speisewagen.xcodeproj` in Xcode (≥ 15), select a simulator or device, and press ⌘R. There is no CLI build setup; all building happens through Xcode. Minimum deployment target is iOS 17.0.

Before running on a physical device, set a Development Team in the target's "Signing & Capabilities" tab. The bundle identifier is `com.example.speisewagen`.

## Design

Accent color `#B5341A` (brick red), background `#FAF8F5` (cream), near-black text `#1C1410`. All color constants live in `Theme.swift` as `Color.swAccent / swBg / swText / swMuted / swBorder`. Typography uses Georgia (serif, available on iOS without bundling) for the app title and "Guten Appetit" footer; SF for all other text. The design origin is a Claude Design prototype (`speisewagen/project/Speisewagen.html`).

## Architecture

This is a single-target SwiftUI + SwiftData iOS app with no third-party dependencies.

**Data layer** — `MealEntry` (`Models/MealEntry.swift`) is the sole SwiftData model. It stores a `Date` and a meal `name` string. The model container is configured in `SpeisewagenApp.swift` with `.modelContainer(for: MealEntry.self)`.

**State model** — There is no view model layer. State lives directly in the views:
- `ContentView` owns `weekOffset: Int` (0 = current week), `editingDate: Date?` (which row is active), and `editingText: String` (live text field content). It uses `@Query` to fetch all `MealEntry` objects and filters in-memory by date.
- Autocomplete `suggestions` is a computed property on `ContentView` derived from `editingText` and `allMeals`, so suggestions update live as the user types.

**Inline editing** — There is no sheet. Tapping a row sets `editingDate` and `editingText` in `ContentView`. `DayRowView` switches between display and edit mode based on the `isEditing: Bool` it receives. Save/cancel/delete are passed as callbacks so `ContentView` owns all SwiftData mutations. Suggestion rows are inserted directly into the `List` below the active row via a nested `ForEach`.

**Week calculation** — `mondayOfWeek(offset:)` in `ContentView` uses `Calendar` with `firstWeekday = 2` and `dateComponents([.yearForWeekOfYear, .weekOfYear])` to anchor to Monday of the current week, then offsets by `weekOfYear`. The week always shows all 7 days (Mon–Sun).

**Logo** — `Views/SpeisewagenLogo.swift` draws the train wagon entirely with SwiftUI `Canvas` (no image assets). Coordinates match a 60×60 SVG viewBox; scale factor `s = size / 60` is applied to every value.

**Layout** — `ContentView` uses a plain `VStack` (no `NavigationStack`). The header's white background extends through the status bar via `.background { Color.white.ignoresSafeArea(edges: .top) }`. The footer uses the same pattern for the bottom safe area. Day rows use `.listRowInsets(EdgeInsets())` so the 3 px today-accent border can be drawn flush to the leading edge.
