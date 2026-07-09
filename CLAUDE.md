# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Speisewagen.xcodeproj` in Xcode (≥ 15), select a simulator or device, and press ⌘R. There is no CLI build setup; all building happens through Xcode. Minimum deployment target is iOS 17.0.

Before running on a physical device, set a Development Team in the target's "Signing & Capabilities" tab. The bundle identifier is `com.example.speisewagen`. The iCloud container identifier is `iCloud.eu.barann.speisewagen`.

## Design

Accent color `#B5341A` (brick red), background `#FAF8F5` (cream), near-black text `#1C1410`. All color constants live in `Theme.swift` as `Color.swAccent / swBg / swText / swMuted / swBorder`. Typography uses Georgia (serif, available on iOS without bundling) for the app title and "Guten Appetit" footer; SF for all other text. The design origin is a Claude Design prototype (`speisewagen/project/Speisewagen.html`).

## Architecture

Single-target SwiftUI + CoreData iOS app, no third-party dependencies.

### Data layer

`MealEntry` (`Models/MealEntry.swift`) is an `NSManagedObject` with three optional properties: `id: UUID?`, `date: Date?`, `name: String?`. The Core Data model is built entirely in code via `MealStore.makeModel()` — there is no `.xcdatamodeld` file.

Persistence is handled by `NSPersistentCloudKitContainer` with two stores:
- `speisewagen.sqlite` — private iCloud database (`.private` scope)
- `speisewagen-shared.sqlite` — shared iCloud database (`.shared` scope)

Both stores have history tracking and remote change notifications enabled. `viewContext` merges changes automatically from parent and uses `NSMergeByPropertyObjectTrumpMergePolicy`.

### State layer

`MealStore` (`Models/MealStore.swift`) is the sole `ObservableObject`. It owns:
- `@Published var meals: [MealEntry]` — all entries, sorted by date, refetched after every mutation and on every `NSPersistentStoreRemoteChange` notification
- `@Published private(set) var allNames: [String]` — deduplicated, sorted list of all meal names; updated inside `fetch()` so it's never stale
- `@Published var isShared: Bool` — true when at least one `CKShare` exists across both stores

`MealStore.shared` is injected into the view hierarchy as an `@EnvironmentObject` in `SpeisewagenApp`.

There is no view model layer. `ContentView` reads from `store.meals` and calls mutating methods (`store.save`, `store.delete`) directly.

### Views

**`ContentView`** — root view. Owns `weekOffset: Int` (0 = current week), `editingDate: Date?`, and `editingText: String`. Uses a `GeometryReader` as the outermost container so the side-menu width is derived from `geo.size.width` rather than `UIScreen`. Hosts the header, list, footer, and the side-menu overlay.

**`DayRowView`** — one row per day. Switches between display and edit mode via `isEditing: Bool` passed from `ContentView`. Save/cancel/delete are callbacks; `ContentView` owns all mutations. Focus is managed with `.onChange(of: isEditing)`. Date formatters are `static` constants to avoid repeated allocation.

**Inline autocomplete** — when a row is in edit mode, suggestion rows are inserted directly into the `List` below the active row via a nested `ForEach`. Suggestions are computed in `ContentView` from `store.allNames` filtered by `editingText`.

**`SideMenuView`** — slides in from the trailing edge over a dimming overlay. Contains a link to close (return to main view) and a `NavigationLink` to `ImpressumView`.

**`CloudSharingView`** — wraps `UICloudSharingController`. After saving a share it clears `minimumAppVersion` on the `CKShare` record to prevent TestFlight recipients being blocked by an App Store version check.

**`SpeisewagenLogo`** — draws the train wagon entirely with SwiftUI `Canvas` (no image assets). Coordinates match a 60×60 SVG viewBox; scale factor `s = size / 60` is applied to every value.

### Week calculation

`mondayOfWeek(offset:)` in `ContentView` creates a `Calendar` with `firstWeekday = 2`, extracts `[.yearForWeekOfYear, .weekOfYear]` from today, then offsets by `weekOfYear`. The week always shows all 7 days (Mon–Sun). Day identity comparisons use `Calendar.current.isDate(_:inSameDayAs:)` throughout.

### Layout

`ContentView` uses a plain `VStack` (no `NavigationStack`). The header's white background extends through the status bar via `.background { Color.white.ignoresSafeArea(edges: .top) }`. The footer uses the same pattern for the bottom safe area. Day rows use `.listRowInsets(EdgeInsets())` so the 3 px today-accent border is flush to the leading edge.

### iCloud sharing flow

1. `ContentView` calls `store.prepareShare` when the share button is tapped.
2. If a share already exists it clears `minimumAppVersion` and re-presents; otherwise it calls `container.share(_:to:)`.
3. The resulting `CKShare` and `CKContainer` are stored in `ContentView` state and presented via `CloudSharingView`.
4. Share acceptance is handled in `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)`, which calls `store.acceptShare(metadata:)`.
