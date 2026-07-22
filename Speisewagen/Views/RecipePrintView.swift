import SwiftUI

/// Druckvorschau für Rezeptkarten. Zeigt alle vorhandenen Rezepte in einer Liste
/// und startet beim Tippen auf „Jetzt drucken" den System-Druckdialog.
struct RecipePrintView: View {
    @EnvironmentObject private var store: MealStore

    var body: some View {
        Group {
            if store.recipes.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(Color.swBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Rezeptkarten")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "printer")
                .font(.system(size: 48))
                .foregroundStyle(Color.swMuted)
            Text("Keine Rezepte")
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(Color.swText)
            Text("Füge zuerst Rezepte hinzu, um Karten drucken zu können.")
                .font(.system(size: 14))
                .foregroundStyle(Color.swMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info-Header
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.grid.3x2")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.swAccent)
                    let n = store.recipes.count
                    Text("\(n) Karte\(n == 1 ? "" : "n") · 5 × 5 cm · DIN A4")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.swMuted)
                    Text("3 Spalten × 5 Zeilen = 15 pro Seite")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.swMuted.opacity(0.7))
                }
                .padding(.top, 24)

                // Rezeptliste
                VStack(spacing: 0) {
                    ForEach(Array(store.recipes.enumerated()), id: \.element.id) { i, recipe in
                        HStack(spacing: 12) {
                            if let data = recipe.imageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.swBorder)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.swMuted)
                                    )
                            }
                            Text(recipe.title ?? "Ohne Titel")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.swText)
                            Spacer()
                            Image(systemName: "qrcode")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.swMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if i < store.recipes.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                // Drucken-Button
                Button {
                    RecipeCardPrinter.print(recipes: store.recipes)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "printer.filled.and.paper")
                        Text("Jetzt drucken")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.swAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
        }
    }
}
