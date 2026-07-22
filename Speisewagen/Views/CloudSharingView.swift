import SwiftUI
import UIKit
import CloudKit

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(share: share, ckContainer: container, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var onDismiss: () -> Void
        private let share: CKShare
        private let ckContainer: CKContainer

        init(share: CKShare, ckContainer: CKContainer, onDismiss: @escaping () -> Void) {
            self.share = share
            self.ckContainer = ckContainer
            self.onDismiss = onDismiss
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { "Speisewagen – Wochenmenü" }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            // UICloudSharingController setzt minimumAppVersion auf die aktuelle Build-Nummer.
            // Empfänger mit älterer App-Store-Version sehen "Update erforderlich".
            // Direkt auf dem CKShare-Objekt löschen und mit .allKeys sichern –
            // kein Fetch nötig, da UICloudSharingController das Objekt aktualisiert hat.
            share["minimumAppVersion"] = nil
            let op = CKModifyRecordsOperation(recordsToSave: [share])
            op.savePolicy = .allKeys
            op.qualityOfService = .userInitiated
            op.modifyRecordsResultBlock = { [weak self] result in
                switch result {
                case .success: print("✓ cloudSharingControllerDidSaveShare: minimumAppVersion geleert")
                case .failure(let error): print("⚠️ cloudSharingControllerDidSaveShare: \(error)")
                }
                DispatchQueue.main.async { self?.onDismiss() }
            }
            ckContainer.privateCloudDatabase.add(op)
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDismiss() }
        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("Share error: \(error)")
            onDismiss()
        }
    }
}
