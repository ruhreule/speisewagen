import SwiftUI

/// Rasteransicht aller gespeicherten Rezepte.
/// Wird vom SideMenu per NavigationLink aufgerufen und nutzt dessen NavigationStack.
struct RecipeListView: View {
    @EnvironmentObject private var store: MealStore
    @State private var showAddRecipe = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if store.recipes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.recipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeCardView(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            // Langes Tippen öffnet Kontextmenü mit Löschen-Option
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteRecipe(recipe)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    // Platz für den FAB, damit Karten nicht darunter verschwinden
                    .padding(.bottom, 100)
                }
            }

            // Floating Action Button – immer sichtbar, auch im leeren Zustand
            Button { showAddRecipe = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.swAccent)
                    .clipShape(Circle())
                    .shadow(color: Color.swAccent.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding([.trailing, .bottom], 20)
        }
        .background(Color.swBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Rezepte")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            RecipeEditView()
        }
    }

    /// Wird angezeigt, solange noch kein Rezept angelegt wurde.
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Color.swMuted)
            Text("Noch keine Rezepte")
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(Color.swText)
            Text("Tippe auf + um dein erstes Rezept hinzuzufügen.")
                .font(.system(size: 14))
                .foregroundStyle(Color.swMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Karte

/// Einzelne Rezeptkarte im Raster: optionales Foto, Titel und Zutatenzahl.
private struct RecipeCardView: View {
    let recipe: Recipe

    /// Anzahl nicht-leerer Zutatenzeilen, für die Unterzeile der Karte.
    private var ingredientCount: Int {
        guard let text = recipe.ingredients, !text.isEmpty else { return 0 }
        return text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bildbereich mit fester Höhe – entweder Foto oder Platzhalter
            ZStack {
                if let data = recipe.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.swBorder
                    Image(systemName: "fork.knife")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.swMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .clipped()

            // Textbereich
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title ?? "Ohne Titel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.swText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if ingredientCount > 0 {
                    Text("\(ingredientCount) Zutaten")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.swMuted)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
    }
}
