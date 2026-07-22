import SwiftUI
import PhotosUI

/// Formular zum Anlegen und Bearbeiten von Rezepten.
/// Wird immer als Modal-Sheet präsentiert (hat daher seinen eigenen NavigationStack).
struct RecipeEditView: View {
    @EnvironmentObject private var store: MealStore
    @Environment(\.dismiss) private var dismiss

    let editingRecipe: Recipe?

    @State private var title: String
    @State private var servings: Int
    @State private var draftIngredients: [IngredientInput]
    @State private var instructions: String
    @State private var imageData: Data?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    init(editing recipe: Recipe? = nil) {
        editingRecipe = recipe
        _title        = State(initialValue: recipe?.title        ?? "")
        // Servings default 4 für neue Rezepte; bestehende mit 0 (nie gesetzt) auf 1 heben.
        _servings     = State(initialValue: recipe.map { max(1, Int($0.servings)) } ?? 4)
        _draftIngredients = State(initialValue:
            recipe?.sortedIngredients.map {
                IngredientInput(amount: $0.amount ?? "", unit: $0.unit ?? "", name: $0.name ?? "")
            } ?? []
        )
        _instructions = State(initialValue: recipe?.instructions ?? "")
        _imageData    = State(initialValue: recipe?.imageData)
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    photoSection

                    VStack(spacing: 20) {
                        // Titel
                        formField(label: "Titel") {
                            TextField("z. B. Pasta Bolognese", text: $title)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.swText)
                        }

                        // Personenanzahl
                        formField(label: "Portionen") {
                            HStack {
                                Text("\(servings) \(servings == 1 ? "Person" : "Personen")")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.swText)
                                Spacer()
                                Stepper("", value: $servings, in: 1...20)
                                    .labelsHidden()
                            }
                        }

                        // Zutaten
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ZUTATEN")
                                .font(.system(size: 11, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.swMuted)

                            VStack(spacing: 0) {
                                ForEach($draftIngredients) { $ingredient in
                                    IngredientRow(ingredient: $ingredient) {
                                        draftIngredients.removeAll { $0.id == ingredient.id }
                                    }
                                    if ingredient.id != draftIngredients.last?.id {
                                        Divider().padding(.leading, 36)
                                    }
                                }
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.swBorder, lineWidth: 1)
                            )

                            // "Zutat hinzufügen"-Button
                            Button {
                                draftIngredients.append(IngredientInput())
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.swAccent)
                                    Text("Zutat hinzufügen")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.swAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.swAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }

                        // Zubereitung
                        formField(label: "Zubereitung") {
                            placeholderEditor(
                                text: $instructions,
                                placeholder: "Beschreibe die Zubereitungsschritte…"
                            )
                            .frame(minHeight: 160)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.swBg)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editingRecipe == nil ? "Neues Rezept" : "Rezept bearbeiten")
                        .font(.custom("Georgia", size: 17))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.swText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.swMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { saveAndDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(isTitleValid ? Color.swAccent : Color.swMuted)
                        .disabled(!isTitleValid)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            isLoadingPhoto = true
            Task {
                // loadTransferable läuft im Hintergrund; Komprimierung auf 0.8 begrenzt Speicherbedarf.
                let compressed = try? await newItem.loadTransferable(type: Data.self)
                    .flatMap { UIImage(data: $0) }
                    .flatMap { $0.jpegData(compressionQuality: 0.8) }
                await MainActor.run {
                    imageData = compressed
                    isLoadingPhoto = false
                }
            }
        }
    }

    // MARK: - Foto-Bereich

    /// Oberer Bildbereich: Foto oder Platzhalter.
    /// PHPickerViewController läuft out-of-process – kein NSPhotoLibraryUsageDescription nötig.
    private var photoSection: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let data = imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("Ändern", systemImage: "camera.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.45))
                                .clipShape(Capsule())
                                .padding(12)
                        }
                    }
                } else {
                    Color(uiColor: .systemGroupedBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    VStack(spacing: 10) {
                        if isLoadingPhoto {
                            ProgressView()
                        } else {
                            Image(systemName: "camera")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.swMuted)
                            Text("Foto hinzufügen")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.swMuted)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hilfsviews

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.swMuted)
            content()
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.swBorder, lineWidth: 1)
                )
        }
    }

    /// TextEditor mit Platzhaltertext via Overlay.
    /// TextEditor hat nativ kein `placeholder`, daher nicht-interaktiver Text überlagert.
    private func placeholderEditor(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.swMuted.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.system(size: 15))
                .foregroundStyle(Color.swText)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Speichern

    private func saveAndDismiss() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        store.saveRecipe(
            title: trimmedTitle,
            servings: Int16(servings),
            ingredients: draftIngredients,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData,
            editing: editingRecipe
        )
        dismiss()
    }
}

// MARK: - Zutatenzeile

/// Einzelne Zeile im Zutaten-Editor: Löschen-Button | Menge | Einheit | Name
private struct IngredientRow: View {
    @Binding var ingredient: IngredientInput
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Löschen
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            // Menge (Freitext, da "1/2", "nach Bedarf" etc. möglich)
            TextField("Menge", text: $ingredient.amount)
                .font(.system(size: 15))
                .foregroundStyle(Color.swText)
                .multilineTextAlignment(.center)
                .frame(width: 58)
                .padding(.vertical, 6)
                .background(Color.swBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Einheit – Menu mit allen Optionen
            Menu {
                ForEach(IngredientInput.unitOptions, id: \.self) { option in
                    Button(option.isEmpty ? "Keine Einheit" : option) {
                        ingredient.unit = option
                    }
                }
            } label: {
                Text(ingredient.unit.isEmpty ? "Einheit" : ingredient.unit)
                    .font(.system(size: 14))
                    .foregroundStyle(ingredient.unit.isEmpty ? Color.swMuted : Color.swText)
                    .lineLimit(1)
                    .frame(width: 68, alignment: .center)
                    .padding(.vertical, 6)
                    .background(Color.swBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Name der Zutat
            TextField("Zutat", text: $ingredient.name)
                .font(.system(size: 15))
                .foregroundStyle(Color.swText)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
