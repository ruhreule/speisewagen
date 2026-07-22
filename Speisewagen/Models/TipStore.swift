import StoreKit

/// Einzelner Trinkgeld-Kauf aus der Transaktionshistorie.
struct TipRecord: Identifiable {
    let id: UInt64      // StoreKit-Transaktions-ID – stabil über Neustarts
    let productID: String
    let date: Date
}

/// Lädt und verarbeitet die konsumierbaren In-App-Käufe für die Trinkgeld-Funktion.
/// Wird als @StateObject in TipJarView gehalten – lebt nur so lange wie die Ansicht.
@MainActor
final class TipStore: ObservableObject {

    /// Produkt-IDs müssen exakt mit den Einträgen im App Store Connect übereinstimmen.
    static let productIDs: [String] = [
        "eu.barann.speisewagen.tip.small",
        "eu.barann.speisewagen.tip.medium",
        "eu.barann.speisewagen.tip.large"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var tipHistory: [TipRecord] = []

    enum State: Equatable {
        case idle
        case loading
        case purchasing
        case success
        case failed(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading),
                 (.purchasing, .purchasing), (.success, .success): return true
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await loadHistory()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public

    func loadProducts() async {
        state = .loading
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
            state = .idle
        } catch {
            state = .failed("Produkte konnten nicht geladen werden.")
        }
    }

    func purchase(_ product: Product) async {
        state = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await loadHistory()
                state = .success
            case .userCancelled:
                state = .idle
            case .pending:
                state = .idle
            @unknown default:
                state = .idle
            }
        } catch {
            state = .failed("Kauf fehlgeschlagen.")
        }
    }

    /// Anzeigename eines Produkts aus der lokalen Produktliste (Fallback: Suffix der ID).
    func displayName(for productID: String) -> String {
        if let product = products.first(where: { $0.id == productID }) {
            return product.displayName
        }
        return String(productID.split(separator: ".").last.map(String.init) ?? "Trinkgeld")
    }

    func resetState() {
        state = .idle
    }

    // MARK: - Private

    /// Liest alle verifizierten Transaktionen aus der StoreKit-Historie und füllt tipHistory.
    func loadHistory() async {
        var records: [TipRecord] = []
        for await result in Transaction.all {
            guard case .verified(let tx) = result,
                  Self.productIDs.contains(tx.productID) else { continue }
            records.append(TipRecord(id: tx.id, productID: tx.productID, date: tx.purchaseDate))
        }
        tipHistory = records.sorted { $0.date > $1.date }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw TipStoreError.verificationFailed
        case .verified(let value): return value
        }
    }

    // Verarbeitet ausstehende Transaktionen (z.B. Family Sharing, Ask-to-Buy).
    // Task (nicht detached) erbt den MainActor-Kontext – kein weak-self nötig.
    private func listenForTransactions() -> Task<Void, Error> {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await loadHistory()
                state = .success
            }
        }
    }
}

private enum TipStoreError: Error {
    case verificationFailed
}
