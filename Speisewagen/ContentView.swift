import SwiftUI
import CloudKit
import VisionKit

/// Autocomplete-Vorschlag: entweder ein verlinktes Rezept (recipeID != nil)
/// oder ein früherer Eintrag ohne Rezeptbindung.
struct MealSuggestion: Identifiable {
    let id: UUID
    let name: String
    let recipeID: UUID?
}

/// Wochenplan-Tab. Zeigt den 7-Tage-Speiseplan und koordiniert alle
/// Bearbeitungsinteraktionen. Lebt als erster Tab innerhalb des TabView in SpeisewagenApp.
struct ContentView: View {
    @EnvironmentObject private var store: MealStore

    /// Woche relativ zur aktuellen: 0 = diese Woche, -1 = letzte, +1 = nächste.
    @State private var weekOffset = 0
    /// Das Datum des gerade im Bearbeitungsmodus befindlichen Tags (nil = kein Tag aktiv).
    @State private var editingDate: Date? = nil
    /// Der Textinhalt des aktiven Eingabefeldes; liegt in ContentView, damit
    /// Auto-Save beim Zeilenwechsel möglich ist.
    @State private var editingText: String = ""
    /// Rezept-UUID, die beim nächsten Speichern mitgespeichert wird. Wird gesetzt,
    /// wenn der Benutzer ein Rezept aus dem Autocomplete wählt oder per QR scannt.
    @State private var pendingRecipeID: UUID? = nil

    // --- Sharing-Zustand ---
    @State private var isPreparingShare = false
    @State private var activeShare: CKShare? = nil
    @State private var activeContainer: CKContainer? = nil
    @State private var showShareSheet = false
    @State private var sharingError: String? = nil
    @State private var showScanner = false
    @State private var showScannerUnsupportedAlert = false
    /// Datum, für das der Scanner geöffnet wurde – explizit gespeichert, damit
    /// die Sheet-Closure immer den richtigen Tag hat, unabhängig vom Capture-Zeitpunkt.
    @State private var scannerTargetDate: Date? = nil
    /// Rezept, das als Detailansicht geöffnet werden soll (nil = kein Sheet).
    @State private var linkedRecipe: Recipe? = nil

    private var allMeals: [MealEntry] { store.meals }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            mealList
            footerView
        }
        .background(Color.swBg)
        .sheet(isPresented: $showShareSheet) {
            if let share = activeShare, let ckContainer = activeContainer {
                CloudSharingView(share: share, container: ckContainer) {
                    showShareSheet = false
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            RecipeScannerSheet { title, recipeID in
                if let date = scannerTargetDate {
                    store.save(name: title, recipeID: recipeID, for: date)
                    editingDate = nil
                    pendingRecipeID = nil
                    scannerTargetDate = nil
                }
            }
            .environmentObject(store)
        }
        .sheet(item: $linkedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipe: recipe)
            }
            .environmentObject(store)
        }
        .alert("Hinweis", isPresented: Binding(
            get: { sharingError != nil },
            set: { if !$0 { sharingError = nil } }
        )) {
            Button("OK") { sharingError = nil }
        } message: {
            Text(sharingError ?? "")
        }
        .alert("Kamera nicht verfügbar", isPresented: $showScannerUnsupportedAlert) {
            Button("OK") { }
        } message: {
            Text("Das Scannen von Rezeptkarten wird auf diesem Gerät nicht unterstützt.")
        }
    }

    // MARK: – Header

    private var headerView: some View {
        VStack(spacing: 14) {
            brandRow
            progressBarView
            weekNavRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background { Color.white.ignoresSafeArea(edges: .top) }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.swBorder).frame(height: 0.5)
        }
    }

    private var brandRow: some View {
        HStack(alignment: .center, spacing: 12) {
            SpeisewagenLogo(size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text("Speisewagen")
                    .font(.custom("Georgia", size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
                Text("Wochenmenü")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.swMuted)
            }

            Spacer()

            shareButton
        }
    }

    /// Share-Button: zeigt während der Vorbereitung einen Ladeindikator,
    /// danach das passende Icon je nach Share-Status.
    private var shareButton: some View {
        Button {
            initiateSharing()
        } label: {
            Group {
                if isPreparingShare {
                    ProgressView()
                        .tint(Color.swMuted)
                } else {
                    Image(systemName: store.isShared ? "person.2.fill" : "person.badge.plus")
                        .font(.system(size: 17))
                        .foregroundStyle(store.isShared ? Color.swAccent : Color.swMuted)
                }
            }
            .frame(width: 34, height: 34)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(store.isShared ? Color.swAccent.opacity(0.3) : Color.swBorder, lineWidth: 1)
            )
        }
        .disabled(isPreparingShare)
    }

    private func initiateSharing() {
        guard !allMeals.isEmpty else {
            sharingError = "Füge zuerst mindestens ein Gericht hinzu."
            return
        }
        isPreparingShare = true
        store.prepareShare { share, container, error in
            isPreparingShare = false
            if let error {
                sharingError = error.localizedDescription
            } else if let share, let container {
                activeShare = share
                activeContainer = container
                showShareSheet = true
            }
        }
    }

    /// Fortschrittsbalken: jeder der 7 Balken entspricht einem Wochentag.
    private var progressBarView: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(i < filledCount ? Color.swAccent : Color.swBorder)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: filledCount)
            }
        }
    }

    private var weekNavRow: some View {
        HStack(spacing: 8) {
            navButton(direction: -1)
            Spacer()
            HStack(spacing: 6) {
                if weekOffset == 0 {
                    Circle()
                        .fill(Color.swAccent)
                        .frame(width: 6, height: 6)
                }
                Text(weekRangeTitle)
                    .font(Font.custom("Georgia", size: 13).italic())
                    .foregroundStyle(Color.swMuted)
            }
            Spacer()
            navButton(direction: 1)
        }
    }

    private func navButton(direction: Int) -> some View {
        Button {
            weekOffset += direction
        } label: {
            Text(direction < 0 ? "‹" : "›")
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(Color.swMuted)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.swBorder, lineWidth: 1)
                )
        }
    }

    // MARK: – Liste

    private var mealList: some View {
        List {
            Text("Diese Woche")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.swMuted)
                .listRowBackground(Color.swBg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            ForEach(weekDates, id: \.timeIntervalSince1970) { date in
                DayRowView(
                    date: date,
                    mealName: meal(for: date)?.name,
                    recipeID: meal(for: date)?.recipeID,
                    isEditing: editingDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                    editingText: $editingText,
                    onStartEditing: { startEditing(date: date) },
                    onSave: { save(for: date) },
                    onCancel: {
                        editingDate = nil
                        pendingRecipeID = nil
                    },
                    onDelete: { delete(for: date) },
                    onScanRecipe: {
                        if DataScannerViewController.isSupported {
                            scannerTargetDate = editingDate
                            showScanner = true
                        } else {
                            showScannerUnsupportedAlert = true
                        }
                    },
                    onOpenRecipe: {
                        if let id = meal(for: date)?.recipeID {
                            linkedRecipe = store.recipes.first { $0.id == id }
                        }
                    }
                )

                // Autocomplete-Vorschläge direkt unterhalb der aktiven Zeile
                if editingDate == date && !suggestions.isEmpty {
                    ForEach(suggestions) { suggestion in
                        Button {
                            if let recipeID = suggestion.recipeID {
                                // Rezept-Vorschlag: sofort speichern und Editiermodus verlassen
                                store.save(name: suggestion.name, recipeID: recipeID, for: date)
                                editingDate = nil
                                pendingRecipeID = nil
                            } else {
                                // Einfacher Textvorschlag: nur Textfeld füllen
                                editingText = suggestion.name
                                pendingRecipeID = nil
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Spacer().frame(width: 54)
                                if suggestion.recipeID != nil {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.swAccent.opacity(0.7))
                                }
                                Text(suggestion.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.swText)
                                Spacer()
                                Text(suggestion.recipeID != nil ? "Rezept ↩" : "↩")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.swAccent.opacity(0.7))
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                    }
                }
            }

            if !store.allNames.isEmpty || !store.recipes.isEmpty {
                HStack(spacing: 8) {
                    Text("💡")
                        .font(.system(size: 16))
                    Text("Tippe auf einen Tag und gib die ersten Buchstaben ein – deine Rezepte und früheren Gerichte werden vorgeschlagen.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.swMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.swBorder)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowBackground(Color.swBg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.swBg)
    }

    // MARK: – Footer

    private var footerView: some View {
        Text("Guten Appetit")
            .font(Font.custom("Georgia", size: 11).italic())
            .kerning(1)
            .foregroundStyle(Color.swMuted.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Kein ignoresSafeArea(.bottom) mehr – das TabView übernimmt den unteren Rand.
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.swBorder).frame(height: 0.5)
            }
    }

    // MARK: – Hilfswerte

    private var filledCount: Int {
        weekDates.filter { meal(for: $0) != nil }.count
    }

    /// Kombinierte Vorschlagsliste: Rezepte zuerst (mit Verlinkung), dann frühere
    /// Gerichtnamen ohne Rezeptbindung. Duplikate (gleicher Name wie ein Rezept) werden
    /// aus dem zweiten Block herausgefiltert.
    private var suggestions: [MealSuggestion] {
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // 1. Passende Rezepte
        var result: [MealSuggestion] = store.recipes.compactMap { recipe in
            guard let title = recipe.title, let id = recipe.id,
                  title.localizedCaseInsensitiveContains(trimmed),
                  title.caseInsensitiveCompare(trimmed) != .orderedSame
            else { return nil }
            return MealSuggestion(id: id, name: title, recipeID: id)
        }

        // 2. Frühere Gerichtnamen, die noch kein Rezept mit diesem Namen haben
        let recipeNames = Set(result.map { $0.name.lowercased() })
        let pastMeals = store.allNames.filter {
            $0.localizedCaseInsensitiveContains(trimmed) &&
            $0.caseInsensitiveCompare(trimmed) != .orderedSame &&
            !recipeNames.contains($0.lowercased())
        }.map { MealSuggestion(id: UUID(), name: $0, recipeID: nil) }

        result.append(contentsOf: pastMeals)
        return result
    }

    private var weekDates: [Date] {
        let monday = mondayOfWeek(offset: weekOffset)
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: monday)
        }
    }

    private static let weekFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd. MMM"
        return f
    }()

    private static let weekFmtYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd. MMM yyyy"
        return f
    }()

    private var weekRangeTitle: String {
        guard let monday = weekDates.first, let lastDay = weekDates.last else { return "" }
        return "\(Self.weekFmt.string(from: monday)) – \(Self.weekFmtYear.string(from: lastDay))"
    }

    private func meal(for date: Date) -> MealEntry? {
        store.meal(for: date)
    }

    /// Wechselt in den Bearbeitungsmodus. Speichert den vorherigen Eintrag automatisch
    /// und lädt die bestehende Rezeptverknüpfung als pendingRecipeID.
    private func startEditing(date: Date) {
        if let prev = editingDate, prev != date {
            let trimmed = editingText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { store.save(name: trimmed, recipeID: pendingRecipeID, for: prev) }
        }
        let existing = meal(for: date)
        editingText = existing?.name ?? ""
        pendingRecipeID = existing?.recipeID
        editingDate = date
    }

    private func save(for date: Date) {
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            editingDate = nil
            pendingRecipeID = nil
            return
        }
        store.save(name: trimmed, recipeID: pendingRecipeID, for: date)
        editingDate = nil
        pendingRecipeID = nil
    }

    private func delete(for date: Date) {
        store.delete(for: date)
        if editingDate == date {
            editingDate = nil
            pendingRecipeID = nil
        }
    }

    /// Berechnet den Montag der Woche mit dem gegebenen Offset (0 = aktuelle Woche).
    /// `yearForWeekOfYear` ist entscheidend für korrekte KW-Arithmetik am Jahreswechsel.
    private func mondayOfWeek(offset: Int) -> Date {
        let comps = Self.weekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let monday = Self.weekCalendar.date(from: comps)!
        return Self.weekCalendar.date(byAdding: .weekOfYear, value: offset, to: monday)!
    }

    /// Gecachter Calendar mit Montag als erstem Wochentag.
    private static let weekCalendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()
}
