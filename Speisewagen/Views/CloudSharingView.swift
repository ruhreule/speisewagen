import SwiftUI
import UIKit
import CloudKit

struct CloudSharingView: UIViewControllerRepresentable {
    @EnvironmentObject var store: MealStore
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { [store] _, completion in
            store.prepareShare { share, ck, error in
                completion(share, ck, error)
            }
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func itemTitle(for csc: UICloudSharingController) -> String? { "Speisewagen – Wochenmenü" }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onDismiss() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDismiss() }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Share error: \(error)")
            onDismiss()
        }
    }
}
