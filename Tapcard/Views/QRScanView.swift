import SwiftUI
import AVFoundation

/// Live QR-code scanner — mirrors the Android QR capture: reads vCard, MECARD
/// or URL QR codes and hands back a prefilled `Contact` for review.
struct QRScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (Contact) -> Void

    @State private var denied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if denied {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Camera access needed").font(.headline)
                        Text("Enable camera access in Settings to scan QR codes.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    QRCameraView { payload in
                        onScanned(QRContactParser.parse(payload))
                    }
                    .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                        .frame(width: 240, height: 240)
                    VStack {
                        Spacer()
                        Text("Point at a QR code on a business card or screen")
                            .font(.footnote)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .task {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .notDetermined {
                    denied = !(await AVCaptureDevice.requestAccess(for: .video))
                } else {
                    denied = status != .authorized
                }
            }
        }
    }
}

/// Parses a scanned QR payload (vCard / MECARD / URL / plain text) into a Contact.
enum QRContactParser {
    static func parse(_ payload: String) -> Contact {
        let trimmed = payload.trimmed
        if trimmed.uppercased().contains("BEGIN:VCARD") { return parseVCard(trimmed) }
        if trimmed.uppercased().hasPrefix("MECARD:") { return parseMecard(trimmed) }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return Contact(notes: trimmed)
        }
        return Contact(name: trimmed)
    }

    private static func parseVCard(_ text: String) -> Contact {
        var c = Contact()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmed
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].uppercased()
            let value = String(line[line.index(after: colon)...]).trimmed
            if key.hasPrefix("FN") { c.name = value }
            else if key.hasPrefix("ORG") { c.company = value.components(separatedBy: ";").first ?? value }
            else if key.hasPrefix("TITLE") { c.position = value }
            else if key.hasPrefix("EMAIL"), c.email.isEmpty { c.email = value }
            else if key.hasPrefix("TEL"), c.phone.isEmpty { c.phone = value }
            else if key.hasPrefix("ADR"), c.address.isEmpty {
                c.address = value.components(separatedBy: ";").filter { !$0.isEmpty }.joined(separator: ", ")
            }
            else if key.hasPrefix("URL"), c.notes.isEmpty { c.notes = value }
        }
        return c
    }

    private static func parseMecard(_ text: String) -> Contact {
        var c = Contact()
        let body = String(text.dropFirst("MECARD:".count))
        for field in body.components(separatedBy: ";") {
            guard let colon = field.firstIndex(of: ":") else { continue }
            let key = field[..<colon].uppercased()
            let value = String(field[field.index(after: colon)...]).trimmed
            switch key {
            case "N": c.name = value.components(separatedBy: ",").reversed().joined(separator: " ").trimmed
            case "ORG": c.company = value
            case "EMAIL": c.email = value
            case "TEL": c.phone = value
            case "ADR": c.address = value
            case "NOTE": c.notes = value
            case "URL": if c.notes.isEmpty { c.notes = value }
            default: break
            }
        }
        return c
    }
}

/// AVFoundation camera preview + metadata (QR) capture.
private struct QRCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRCameraController {
        let controller = QRCameraController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: QRCameraController, context: Context) {}
}

final class QRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var delivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first { $0 is AVCaptureVideoPreviewLayer }?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        // The output delegate queue is .main, so hopping back onto the main
        // actor here is safe and lets us touch the controller's state.
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = object.stringValue, !payload.isEmpty else { return }
        MainActor.assumeIsolated {
            guard !delivered else { return }
            delivered = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(payload)
        }
    }
}
