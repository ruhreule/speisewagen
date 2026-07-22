import SwiftUI
import StoreKit

/// Trinkgeld-Ansicht: zeigt drei Kaufoptionen und bestätigt den Kauf mit einer
/// kurzen Danke-Meldung. Produkte werden beim Erscheinen der Ansicht geladen.
struct TipJarView: View {
    @StateObject private var tipStore = TipStore()
    @State private var showThankYou = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.swAccent.opacity(0.08))
                            .frame(width: 90, height: 90)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.swAccent)
                    }
                    .padding(.top, 8)

                    Text("Speisewagen unterstützen")
                        .font(.custom("Georgia", size: 22))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.swText)
                        .multilineTextAlignment(.center)

                    Text("Die App ist kostenlos und werbefrei.\nWenn du magst, kannst du die Entwicklung\nmit einem kleinen Trinkgeld unterstützen.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 24)

                // Produkte
                VStack(spacing: 10) {
                    if tipStore.state == .loading {
                        ProgressView()
                            .padding(.vertical, 32)
                    } else if tipStore.products.isEmpty {
                        Text("Produkte konnten nicht geladen werden.\nBitte überprüfe deine Internetverbindung.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.swMuted)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(tipStore.products, id: \.id) { product in
                            TipButton(
                                product: product,
                                isPurchasing: tipStore.state == .purchasing
                            ) {
                                Task {
                                    await tipStore.purchase(product)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if case .failed(let message) = tipStore.state {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                }

                // Kaufhistorie
                if !tipStore.tipHistory.isEmpty {
                    TipHistorySection(tipStore: tipStore)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color.swBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Trinkgeld")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
            }
        }
        // Danke-Overlay nach erfolgreichem Kauf
        .overlay {
            if showThankYou {
                ThankYouOverlay {
                    withAnimation { showThankYou = false }
                    tipStore.resetState()
                }
            }
        }
        .onChange(of: tipStore.state) { _, newState in
            if newState == .success {
                withAnimation(.spring(duration: 0.4)) {
                    showThankYou = true
                }
            }
        }
    }
}

// MARK: - Einzelne Schaltfläche

private struct TipButton: View {
    let product: Product
    let isPurchasing: Bool
    let action: () -> Void

    // Passende Emoji-Icons für kleine, mittlere und große Beträge
    private var icon: String {
        let price = product.price
        if price < 3 { return "☕️" }
        if price < 5 { return "🍺" }
        if price < 7 { return "🍕" }
        return "🎉"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 28))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.swText)
                    Text(product.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.swMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.swAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.swSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.swBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

// MARK: - Kaufhistorie

private struct TipHistorySection: View {
    let tipStore: TipStore

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEINE UNTERSTÜTZUNG")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.swMuted)

            VStack(spacing: 0) {
                ForEach(tipStore.tipHistory) { record in
                    HStack(spacing: 12) {
                        Text("🙏")
                            .font(.system(size: 22))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tipStore.displayName(for: record.productID))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.swText)
                            Text(Self.dateFmt.string(from: record.date))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.swMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if record.id != tipStore.tipHistory.last?.id {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color.swSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.swBorder, lineWidth: 1))

            Text("Vielen Dank für deine Unterstützung! ❤️")
                .font(.system(size: 13))
                .foregroundStyle(Color.swMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }
}

// MARK: - Danke-Overlay

private struct ThankYouOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 56))

                Text("Danke!")
                    .font(.custom("Georgia", size: 28))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)

                Text("Deine Unterstützung bedeutet mir sehr viel.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.swMuted)
                    .multilineTextAlignment(.center)

                Button("Schließen") { onDismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.swAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .background(Color.swSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
    }
}
