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
            // UICloudSharingController sets minimumAppVersion to the current build number.
            // Since the app is TestFlight-only, iOS can't verify that version in the App Store
            // and shows an error to recipients. Clearing it removes the version gate.
            share["minimumAppVersion"] = nil
            let op = CKModifyRecordsOperation(recordsToSave: [share])
            op.savePolicy = .changedKeys
            ckContainer.privateCloudDatabase.add(op)
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDismiss() }
        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("Share error: \(error)")
            onDismiss()
        }
    }
}
