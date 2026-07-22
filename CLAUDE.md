# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Speisewagen.xcodeproj` in Xcode (≥ 15), select a simulator or device, and press ⌘R. There is no CLI build setup; all building happens through Xcode. Minimum deployment target is iOS 17.0.

Before running on a physical device, set a Development Team in the target's "Signing & Capabilities" tab. The bundle identifier is `com.example.speisewagen`. The iCloud container identifier is `iCloud.eu.barann.speisewagen`.

Push Notifications and iCloud (CloudKit) capabilities must be enabled under Signing & Capabilities. Before TestFlight builds work, the CloudKit schema must be deployed to Production via the CloudKit Dashboard.

## Design

Accent color `#B5341A` (brick red), background `#FAF8F5` (cream), near-black text `#1C1410`. All color constants live in `Theme.swift` as `Color.swAccent / swBg / swText / swMuted / swBorder`. Typography uses Georgia (serif, available on iOS without bundling) for titles and the "Guten Appetit" footer; SF System for all other text. The design origin is a Claude Design prototype (`speisewagen/project/Speisewagen.html`).

## Architecture

Single-target SwiftUI + CoreData iOS app, no third-party dependencies.

### Data layer

**`MealEntry`** (`Models/MealEntry.swift`) — `NSManagedObject` with four optional properties: `id: UUID?`, `date: Date?`, `name: String?`, `recipeID: UUID?`. The `recipeID` links the entry to a `Recipe` by UUID (soft reference, not a CoreData relationship) so the link survives even if the recipe is deleted — the entry just loses its book-icon affordance.

**`Recipe`** (`Models/Recipe.swift`) — `NSManagedObject` with `id`, `title`, `instructions`, `imageData`, `createdAt`, `servings`. Photos are stored with `allowsExternalBinaryDataStorage = true`, keeping the SQLite file small and letting CloudKit sync them as `CKAsset`.

**`RecipeIngredient`** (`Models/RecipeIngredient.swift`) — `NSManagedObject` linked to `Recipe` via a to-many CoreData relationship (`ingredientItems`). Sorted by `sortOrder: Int16`. Cascade-delete rule ensures ingredients are removed with their recipe. `IngredientInput` is a transient value type used only in `RecipeEditView` before committing to CoreData.

The CoreData model is built entirely in code via `MealStore.makeModel()` — **there is no `.xcdatamodeld` file**. This means CoreData cannot perform automatic lightweight migration when entities or attributes are added. `MealStore.setup()` detects incompatible stores using `metadataForPersistentStore` + `isConfiguration(withName:compatibleWithStoreMetadata:)`, deletes the store files (including `-wal` and `-shm`), and lets `loadPersistentStores` recreate them fresh. CloudKit re-syncs data on next launch.

Persistence uses `NSPersistentCloudKitContainer` with two stores:
- `speisewagen.sqlite` — private iCloud database (`.private` scope) — syncs across the user's own devices automatically
- `speisewagen-shared.sqlite` — shared iCloud database (`.shared` scope) — used when the meal plan is shared with other iCloud users via `CKShare`

Both stores have history tracking and remote change notifications enabled. `viewContext` merges changes automatically from parent and uses `NSMergeByPropertyObjectTrumpMergePolicy`.

### State layer

`MealStore` (`Models/MealStore.swift`) is the sole `ObservableObject` / singleton (`MealStore.shared`). It owns:
- `@Published var meals: [MealEntry]` — all entries, ascending by date, refetched after every mutation and on every `NSPersistentStoreRemoteChange` notification
- `@Published private(set) var allNames: [String]` — deduplicated, sorted list of all meal names ever entered; used for non-recipe autocomplete suggestions
- `@Published var isShared: Bool` — true when at least one `CKShare` exists across both stores
- `@Published var recipes: [Recipe]` — all recipes, newest first

`MealStore.shared` is injected into the view hierarchy as an `@EnvironmentObject` in `SpeisewagenApp`.

There is no view model layer. Views read from store's published properties and call mutating methods (`store.save`, `store.delete`, `store.saveRecipe`, `store.deleteRecipe`) directly.

### Views

**`ContentView`** — root view of the Wochenplan tab. Owns `weekOffset: Int` (0 = current week), `editingDate: Date?`, `editingText: String`, and `pendingRecipeID: UUID?`. The `pendingRecipeID` tracks which recipe should be linked when saving — it is set when entering edit mode on an already-linked entry, when a recipe autocomplete suggestion is tapped, or when a QR scan completes. It is cleared when text is manually changed (via `onChange` that compares against the linked recipe's title) or when the entry is deleted/cancelled.

**`DayRowView`** — one row per day. Switches between display and edit mode via `isEditing: Bool` passed from `ContentView`. All mutations (save/cancel/delete/scan/openRecipe) are callbacks — `ContentView` owns all state changes. The cancel (X) button deletes the day's entry. A book icon appears in display mode when `recipeID != nil`; tapping it opens `RecipeDetailView` as a sheet from `ContentView`. All icon buttons use `.buttonStyle(.plain)` + 44×44 pt frame to ensure reliable tap targets and to prevent the row's `onTapGesture` from intercepting the button gesture.

**Inline autocomplete** — when a row is in edit mode, suggestion rows are inserted directly into the `List` below the active row via a nested `ForEach`. Suggestions are `[MealSuggestion]` (defined in `ContentView.swift`), which combine matching recipes (shown first, with book icon and immediate save-and-close behavior) and matching past meal names (shown second, fill text field only). Deduplication removes past names that also exist as recipe titles.

**`RecipeListView`** — 2-column grid of all recipes. Long-press shows a context menu with a delete option. The + FAB opens `RecipeEditView` as a sheet.

**`RecipeDetailView`** — full recipe display: photo header, title, servings, structured ingredient table (fixed column widths: 52 pt amount, 46 pt unit, flex name), freeform instructions. Edit and delete buttons in toolbar.

**`RecipeEditView`** — modal form (has its own NavigationStack). Photo via `PhotosPicker` (out-of-process, no `NSPhotoLibraryUsageDescription` needed). Ingredients use `IngredientInput` draft values; the `IngredientRow` sub-view handles per-row editing with a unit menu. Photo is JPEG-compressed at 0.8 quality before storing to keep binary data size reasonable.

**`RecipeCardPrinter`** — enum with static methods. Generates a PDF of 5×5 cm cards (3 cols × 5 rows per A4 page, `5/2.54*72 ≈ 141.73 pt`) and triggers `UIPrintInteractionController`. Each card has an aspect-fill photo, title text, and a QR code. QR payload: `speisewagen://recipe/{UUID}`. Error correction level M (15%) balances code density with scan reliability at small print sizes.

**`RecipeScannerView`** — `UIViewControllerRepresentable` wrapping `DataScannerViewController`. Parses the `speisewagen://recipe/{uuid}` payload, looks up the recipe in `store.recipes`, and calls `onRecipeFound(title, uuid)`. The `handled` flag prevents duplicate callbacks for the same successful scan; it is NOT set on failed lookups, so the scanner stays active for another attempt. Requires `DataScannerViewController.isSupported` (true on iPhone XS and later).

**`CloudSharingView`** — wraps `UICloudSharingController`. After saving a share it clears `minimumAppVersion` on the `CKShare` record via a `CKModifyRecordsOperation`. Without this, TestFlight recipients see an "update required" error because the system cannot find the build version in the App Store.

**`SpeisewagenLogo`** — draws the train wagon with fork/knife entirely in SwiftUI `Canvas` (no image assets). All coordinates are in a 60×60 pt viewBox; scale factor `s = size / 60` is applied to every value, making the logo resolution-independent.

**`OnboardingView`** — four-page carousel shown as `fullScreenCover` on first launch (guarded by `@AppStorage("hasSeenOnboarding")`). Also accessible via Mehr → App-Einführung as a sheet. Tapping "Los geht's" on the last page sets `hasSeenOnboarding = true` and dismisses.

### Week calculation

`mondayOfWeek(offset:)` in `ContentView` uses a cached `Calendar` with `firstWeekday = 2`, extracts `[.yearForWeekOfYear, .weekOfYear]` from today, then offsets by `weekOfYear`. Using `yearForWeekOfYear` (not `.year`) is essential for correct week arithmetic at year boundaries. The week always shows all 7 days (Mon–Sun). Day identity comparisons use `Calendar.current.isDate(_:inSameDayAs:)` throughout.

### Layout

`ContentView` uses a plain `VStack` (no `NavigationStack`). The header's white background extends through the status bar via `.background { Color.white.ignoresSafeArea(edges: .top) }`. Day rows use `.listRowInsets(EdgeInsets())` so the 3 px today-accent stripe is flush to the leading edge.

### iCloud sync flow

All data in the private store syncs automatically across the user's own devices via `NSPersistentCloudKitContainer`. Remote changes arrive via APNs silent push and trigger `NSPersistentStoreRemoteChange`, which calls `fetch()` and updates all `@Published` properties.

### iCloud sharing flow

1. `ContentView` calls `store.prepareShare` when the share button is tapped.
2. If a share already exists, it clears `minimumAppVersion` and re-presents; otherwise it calls `container.share(_:to:)`.
3. The resulting `CKShare` and `CKContainer` are stored in `ContentView` state and presented via `CloudSharingView`.
4. Share acceptance is handled in `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)`, which calls `store.acceptShare(metadata:)`.
