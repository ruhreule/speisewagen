import SwiftUI

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "fork.knife",
        title: "Willkommen beim\nSpeisewagen",
        description: "Dein digitaler Speiseplan. Plane die Woche, verwalte Rezepte und behalte immer den Überblick."
    ),
    OnboardingPage(
        icon: "calendar",
        title: "Wochenplan",
        description: "Tippe auf einen Tag, um ein Gericht einzutragen. Deine Rezepte und früheren Gerichte werden als Vorschlag angezeigt."
    ),
    OnboardingPage(
        icon: "book.closed.fill",
        title: "Rezepte",
        description: "Lege Rezepte mit Zutaten und Zubereitung an. Drucke Rezeptkarten mit QR-Code und scanne sie, um ein Rezept einem Tag zuzuweisen."
    ),
    OnboardingPage(
        icon: "icloud.fill",
        title: "iCloud-Sync",
        description: "Speiseplan und Rezepte werden automatisch auf all deinen Geräten synchronisiert."
    )
]

/// Einführungsansicht: wird beim ersten Start als fullScreenCover gezeigt
/// und ist über „Mehr" jederzeit wieder aufrufbar.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.swBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Überspringen-Button oben rechts – nur auf den ersten Seiten sichtbar
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Überspringen") {
                            hasSeenOnboarding = true
                            dismiss()
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swMuted)
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 44)

                // Logo
                SpeisewagenLogo(size: 48)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                Text("Speisewagen")
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(Color.swMuted)
                    .padding(.bottom, 32)

                // Seiteninhalt
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        pageContent(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Punkte-Indikator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.swAccent : Color.swBorder)
                            .frame(width: i == currentPage ? 20 : 7, height: 7)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 28)

                // Weiter / Los geht's
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasSeenOnboarding = true
                        dismiss()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Weiter" : "Los geht's")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.swAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .interactiveDismissDisabled()
    }

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.swAccent.opacity(0.08))
                    .frame(width: 110, height: 110)
                Image(systemName: page.icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.swAccent)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.custom("Georgia", size: 26))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.swMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}
