import SwiftUI
import SwiftData

struct MealEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allMeals: [MealEntry]

    let date: Date
    let existingMeal: MealEntry?

    @State private var mealName = ""
    @FocusState private var isFocused: Bool

    private var suggestions: [String] {
        let trimmed = mealName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let all = Array(Set(allMeals.map { $0.name }.filter { !$0.isEmpty })).sorted()
        return all.filter {
            $0.localizedCaseInsensitiveContains(trimmed) &&
            $0.caseInsensitiveCompare(trimmed) != .orderedSame
        }
    }

    private var dateTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EEEE, dd. MMMM yyyy"
        return fmt.string(from: date)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Gericht eingeben…", text: $mealName)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }

                if !suggestions.isEmpty {
                    Section("Vorschläge") {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                mealName = suggestion
                            } label: {
                                HStack {
                                    Text(suggestion)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if existingMeal != nil {
                    Section {
                        Button(role: .destructive) {
                            delete()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Eintrag löschen", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: save)
                        .disabled(mealName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                mealName = existingMeal?.name ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }

    private func save() {
        let trimmed = mealName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = existingMeal {
            existing.name = trimmed
        } else {
            context.insert(MealEntry(date: date, name: trimmed))
        }
        dismiss()
    }

    private func delete() {
        if let existing = existingMeal {
            context.delete(existing)
        }
        dismiss()
    }
}
