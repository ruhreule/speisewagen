import SwiftUI

/// Detailansicht eines Rezepts: Foto-Header, Titel, Portionenanzahl,
/// strukturierte Zutatentabelle und Zubereitung als Fließtext.
struct RecipeDetailView: View {
    @EnvironmentObject private var store: MealStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var showEdit = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Foto-Header – nur angezeigt, wenn ein Bild gespeichert ist
                if let data = recipe.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 24) {
                    // Titel + Portionenhinweis
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title ?? "Ohne Titel")
                            .font(.custom("Georgia", size: 26))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.swText)

                        if recipe.servings > 0 {
                            (recipe.servings == 1
                                ? Text("Für \(Int(recipe.servings)) Person")
                                : Text("Für \(Int(recipe.servings)) Personen"))
                                .font(.system(size: 13))
                                .foregroundStyle(Color.swMuted)
                        }
                    }

                    // Zutaten
                    let ingredients = recipe.sortedIngredients
                    if !ingredients.isEmpty {
                        ingredientsSection(ingredients)
                    }

                    // Zubereitung
                    if let instructions = recipe.instructions, !instructions.isEmpty {
                        instructionsSection(instructions)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.swBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(recipe.title ?? "")
                    .font(.custom("Georgia", size: 17))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.swMuted)
                    }
                    Button("Bearbeiten") { showEdit = true }
                        .foregroundStyle(Color.swAccent)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            RecipeEditView(editing: recipe)
        }
        .alert("Rezept löschen?", isPresented: $showDeleteAlert) {
            Button("Löschen", role: .destructive) {
                store.deleteRecipe(recipe)
                // dismiss() vor dem nächsten Render-Zyklus, damit kein Zugriff
                // auf das bereits gelöschte Managed Object stattfindet.
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Rezept wird unwiderruflich gelöscht.")
        }
    }

    // MARK: - Abschnitte

    /// Strukturierte Zutatentabelle: Menge | Einheit | Name, zeilenweise.
    private func ingredientsSection(_ ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Zutaten")
            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
                    HStack(alignment: .top, spacing: 0) {
                        // Menge rechtsbündig in fester Spalte
                        Text(ingredient.amount ?? "")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.swText)
                            .frame(width: 52, alignment: .trailing)

                        // Einheit linksbündig mit festem Abstand
                        Text(ingredient.unit ?? "")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.swMuted)
                            .frame(width: 46, alignment: .leading)
                            .padding(.leading, 6)

                        // Name nimmt den restlichen Platz ein
                        Text(ingredient.name ?? "")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.swText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if ingredient.id != ingredients.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color.swSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func instructionsSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Zubereitung")
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.swText)
                .lineSpacing(5)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.swSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(Color.swMuted)
    }
}
