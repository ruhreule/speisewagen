import SwiftUI

/// Seitenmenü, das von rechts über den Hauptinhalt gleitet.
///
/// Enthält einen direkten Link zurück zur Wochenübersicht und einen
/// NavigationLink zum Impressum. Das Menü selbst verwaltet keine eigene
/// Sichtbarkeit – das wird vollständig von ContentView über `onClose` gesteuert.
struct SideMenuView: View {
    let onClose: () -> Void

    var body: some View {
        // NavigationStack ermöglicht den Tiefenlink zum ImpressumView,
        // ohne dass ContentView eine eigene NavigationStack-Hierarchie braucht.
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header mit Titel und Schließen-Button
                HStack {
                    Text("Menü")
                        .font(.custom("Georgia", size: 20))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.swText)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.swMuted)
                            .frame(width: 30, height: 30)
                            .background(Color.swBg)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                // "Wochenübersicht" schließt das Menü und kehrt zur Hauptansicht zurück
                Button(action: onClose) {
                    menuRow(icon: "calendar", title: "Wochenübersicht")
                }
                .buttonStyle(.plain)

                // Trennlinie beginnt erst nach der Icon-Spalte für eine eingerückte Optik
                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)
                    .padding(.leading, 56)

                NavigationLink {
                    ImpressumView()
                } label: {
                    menuRow(icon: "info.circle", title: "Impressum")
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                Spacer()
            }
            .background(Color.white)
            // Standard-NavigationBar ausblenden – eigener Header übernimmt diese Rolle
            .toolbar(.hidden, for: .navigationBar)
        }
        // Schatten simuliert Tiefe und trennt das Menü visuell vom gedimmten Hintergrund
        .shadow(color: .black.opacity(0.12), radius: 24, x: -6, y: 0)
    }

    /// Erstellt eine einheitliche Menüzeile mit Icon, Titel und Chevron.
    private func menuRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.swAccent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.swText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.swMuted.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
