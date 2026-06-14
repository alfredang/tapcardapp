import SwiftUI
import VisionKit
import UIKit

/// SwiftUI wrapper around VisionKit's document camera, used to capture a sharp,
/// perspective-corrected image of a paper business card.
///
/// `VNDocumentCameraViewControllerDelegate` is NOT `@MainActor` in the SDK, so
/// the Coordinator stays nonisolated. Callbacks are typed `@MainActor` (which
/// makes them Sendable) and the captured page is shuttled to the main actor as
/// a Sendable `CGImage`, then rebuilt into a `UIImage`.
struct CardScannerView: UIViewControllerRepresentable {
    var onScan: @MainActor (UIImage) -> Void
    var onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: @MainActor (UIImage) -> Void
        let onCancel: @MainActor () -> Void

        init(onScan: @escaping @MainActor (UIImage) -> Void,
             onCancel: @escaping @MainActor () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let cgImage = scan.pageCount > 0 ? scan.imageOfPage(at: 0).cgImage : nil
            let onScan = self.onScan
            Task { @MainActor in
                if let cgImage { onScan(UIImage(cgImage: cgImage)) }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            let onCancel = self.onCancel
            Task { @MainActor in onCancel() }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            let onCancel = self.onCancel
            Task { @MainActor in onCancel() }
        }
    }
}
