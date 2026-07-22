import SwiftUI
import VisionKit

/// Hüllt `DataScannerViewController` ein und erkennt Rezept-QR-Codes der Form
/// `speisewagen://recipe/{uuid}`.
///
/// Bei einem Treffer wird `onRecipeFound(title, uuid)` aufgerufen und das Sheet
/// schließt sich. Ist der UUID im Store unbekannt, wird `onRecipeNotFound` aufgerufen
/// und der Scanner bleibt offen – der Benutzer kann einen anderen Code scannen.
struct RecipeScannerView: UIViewControllerRepresentable {
    @EnvironmentObject var store: MealStore
    let onRecipeFound: (String, UUID) -> Void
    var onRecipeNotFound: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: RecipeScannerView
        /// Verhindert Doppel-Callbacks, wenn derselbe gültige QR-Code mehrfach
        /// in `didAdd` erscheint. Wird nur nach einem erfolgreichen Rezept-Fund
        /// gesetzt – ein nicht gefundenes Rezept lässt den Scanner weiter aktiv.
        private var handled = false

        init(parent: RecipeScannerView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !handled else { return }
            for item in addedItems {
                guard case .barcode(let bc) = item,
                      let payload = bc.payloadStringValue,
                      payload.hasPrefix("speisewagen://recipe/") else { continue }

                let uuidStr = String(payload.dropFirst("speisewagen://recipe/".count))
                guard let uuid = UUID(uuidString: uuidStr),
                      let recipe = parent.store.recipes.first(where: { $0.id == uuid }),
                      let title = recipe.title else {
                    // QR-Code gehört zu Speisewagen, aber das Rezept ist nicht im lokalen
                    // Store. Scanner bleibt aktiv (handled nicht setzen), damit der Benutzer
                    // einen anderen Code scannen kann.
                    DispatchQueue.main.async { self.parent.onRecipeNotFound?() }
                    return
                }

                // Erst jetzt handled = true: Doppel-Callbacks für denselben Fund unterdrücken.
                handled = true
                DispatchQueue.main.async { self.parent.onRecipeFound(title, uuid) }
                return
            }
        }
    }
}

/// Sheet-Container: zeigt den Scanner mit einem Schließen-Button.
/// Wird von ContentView als Sheet präsentiert.
struct RecipeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onRecipeFound: (String, UUID) -> Void

    @State private var notFoundAlert = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RecipeScannerView { title, uuid in
                onRecipeFound(title, uuid)
                dismiss()
            } onRecipeNotFound: {
                notFoundAlert = true
            }
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(20)
                    .shadow(radius: 4)
            }
        }
        .alert("Rezept nicht gefunden", isPresented: $notFoundAlert) {
            Button("OK") { }
        } message: {
            Text("Der QR-Code gehört zu keinem Rezept in deiner App.")
        }
    }
}
