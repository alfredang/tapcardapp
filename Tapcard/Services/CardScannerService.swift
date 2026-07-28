import SwiftUI
import AVFoundation
import Vision
import CoreImage
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// Single-shot business-card scanner.
//
// VisionKit's `VNDocumentCameraViewController` is a *multi-page* document
// scanner: its auto-shutter keeps firing for as long as it sees the card and
// there is no API to cap it at one page — which felt like an infinite capture
// loop when pointed at a business card. This replacement keeps the same
// auto-detect experience (it runs the same Vision document-segmentation model
// on the live feed) but captures exactly ONE photo once the card is held
// steady, perspective-corrects it, and asks "Use photo / Retake".
// ─────────────────────────────────────────────────────────────────────────────

/// Public face of the scanner — same API as the old VisionKit wrapper, so the
/// scan flow presents it unchanged.
struct CardScannerView: View {
    var onScan: @MainActor (UIImage) -> Void
    var onCancel: @MainActor () -> Void

    @State private var model = CardScannerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let captured = model.captured {
                confirmView(captured)
            } else if model.unavailable {
                unavailableView
            } else {
                CameraPreview(session: model.controller.session)
                    .ignoresSafeArea()
                // Live edge detection — the detected card outline, redrawn per
                // frame like VisionKit's, green once the hold is steady.
                if let quad = model.quad {
                    QuadOverlay(quad: quad, bufferSize: model.bufferSize,
                                steady: model.isSteady)
                        .ignoresSafeArea()
                }
                scanOverlay
            }
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // ─── Live scanning ──────────────────────────────────────────────────────

    private var scanOverlay: some View {
        VStack {
            HStack {
                circleButton("xmark") { onCancel() }
                Spacer()
            }
            .padding(20)

            Spacer()

            // Card-shaped guide, shown until the detector locks onto the card.
            if model.quad == nil {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .aspectRatio(1.6, contentMode: .fit)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 18) {
                Text(model.isSteady ? "Hold still…" : "Line up the business card")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())

                // Manual shutter, for cards the auto-detector struggles with.
                Button {
                    model.captureNow()
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 68, height: 68)
                        Circle().fill(.white).frame(width: 56, height: 56)
                    }
                }
            }
            .padding(.bottom, 36)
        }
    }

    // ─── One-shot confirm ───────────────────────────────────────────────────

    private func confirmView(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            Spacer()

            HStack(spacing: 12) {
                Button {
                    model.retake()
                } label: {
                    Text("Retake")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.18), in: Capsule())
                }

                Button {
                    onScan(image)
                } label: {
                    Text("Use photo")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.gradientPrimary, in: Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    // ─── Camera unavailable (simulator, permission denied) ──────────────────

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera unavailable")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Allow camera access in Settings, or enter the card details manually.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Close") { onCancel() }
                .font(.headline)
                .padding(.top, 8)
        }
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.45), in: Circle())
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────

/// UI state for the scanner, fed by `CardCaptureController` callbacks.
@MainActor @Observable
final class CardScannerModel {
    let controller = CardCaptureController()
    var captured: UIImage?
    var isSteady = false
    var unavailable = false
    /// Detected card corners (TL, TR, BR, BL) normalized to `bufferSize`,
    /// top-left origin — nil when no card is in view.
    var quad: [CGPoint]?
    var bufferSize: CGSize = .zero

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            unavailable = true
            return
        }
        controller.onSteadyChange = { [weak self] steady in
            Task { @MainActor in self?.isSteady = steady }
        }
        controller.onQuadChange = { [weak self] quad, size in
            Task { @MainActor in
                self?.quad = quad
                self?.bufferSize = size
            }
        }
        controller.onCapture = { [weak self] image in
            Task { @MainActor in
                self?.captured = image
                self?.quad = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        let ok = await controller.start()
        if !ok { unavailable = true }
    }

    func stop() { controller.stop() }

    func retake() {
        captured = nil
        controller.resume()
    }

    func captureNow() { controller.captureNow() }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Owns the capture session and the detection state machine. Video frames are
/// analysed on a private queue with Vision's document-segmentation request —
/// the same model VisionKit's scanner uses — and once the card has been seen
/// steady (present, large enough, not moving) for ~0.8 s it captures a single
/// photo, perspective-corrects it, and stops until `resume()`.
///
/// `@unchecked Sendable`: mutable state is confined to `videoQueue` (detection
/// counters) and `sessionQueue` (session lifecycle); callbacks hop to the main
/// actor in `CardScannerModel`.
final class CardCaptureController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    var onSteadyChange: (@Sendable (Bool) -> Void)?
    /// Detected corners (TL, TR, BR, BL), normalized with a top-left origin,
    /// plus the analysed buffer's pixel size — nil quad when nothing detected.
    var onQuadChange: (@Sendable ([CGPoint]?, CGSize) -> Void)?
    var onCapture: (@Sendable (UIImage) -> Void)?

    private let sessionQueue = DispatchQueue(label: "cardscanner.session")
    private let videoQueue = DispatchQueue(label: "cardscanner.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()

    // Detection state — videoQueue only.
    private var steadyFrames = 0
    private var lastCenter: CGPoint?
    private var isCapturing = false
    private var frameCounter = 0

    /// Frames the card must stay steady before the shutter fires
    /// (~15 analysed frames/s → ≈0.8 s).
    private static let steadyThreshold = 12

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                continuation.resume(returning: self.configureAndRun())
            }
        }
    }

    func stop() {
        sessionQueue.async { self.session.stopRunning() }
    }

    /// Re-arm after a retake.
    func resume() {
        videoQueue.async {
            self.steadyFrames = 0
            self.lastCenter = nil
            self.isCapturing = false
        }
    }

    /// Manual shutter.
    func captureNow() {
        videoQueue.async {
            guard !self.isCapturing else { return }
            self.isCapturing = true
            self.firePhoto()
        }
    }

    private func configureAndRun() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)

        videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(videoOutput)
        session.addOutput(photoOutput)

        // Deliver buffers/photos upright (portrait UI).
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            if let connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        session.commitConfiguration()
        session.startRunning()
        return session.isRunning
    }

    private func firePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// ─── Live detection ─────────────────────────────────────────────────────────

extension CardCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isCapturing else { return }

        // ~30 fps in; analysing every 2nd frame is plenty.
        frameCounter += 1
        guard frameCounter.isMultiple(of: 2),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectDocumentSegmentationRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])

        let bufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                                height: CVPixelBufferGetHeight(pixelBuffer))

        guard let card = request.results?.first,
              card.confidence > 0.85,
              card.boundingBox.width * card.boundingBox.height > 0.10 else {
            onQuadChange?(nil, bufferSize)
            markUnsteady()
            return
        }

        // Publish the live outline (Vision is bottom-left origin; flip Y).
        let flip = { (p: CGPoint) in CGPoint(x: p.x, y: 1 - p.y) }
        onQuadChange?(
            [flip(card.topLeft), flip(card.topRight),
             flip(card.bottomRight), flip(card.bottomLeft)],
            bufferSize
        )

        // Steady means present AND not moving between analysed frames.
        let center = CGPoint(x: card.boundingBox.midX, y: card.boundingBox.midY)
        if let last = lastCenter, abs(center.x - last.x) + abs(center.y - last.y) > 0.04 {
            markUnsteady()
            lastCenter = center
            return
        }
        lastCenter = center

        steadyFrames += 1
        if steadyFrames == 3 { onSteadyChange?(true) }
        if steadyFrames >= Self.steadyThreshold {
            isCapturing = true   // single shot — never fires again until resume()
            firePhoto()
        }
    }

    private func markUnsteady() {
        if steadyFrames >= 3 { onSteadyChange?(false) }
        steadyFrames = 0
    }
}

// ─── Photo capture + perspective correction ─────────────────────────────────

extension CardCaptureController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        onSteadyChange?(false)
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let raw = UIImage(data: data) else {
            resume()   // let the user try again rather than dead-ending
            return
        }
        onCapture?(corrected(raw))
    }

    /// Re-detect the card on the captured still and crop/straighten it, like
    /// VisionKit's post-shot perspective correction. Falls back to the full
    /// frame when detection on the still fails.
    private func corrected(_ image: UIImage) -> UIImage {
        // Normalize EXIF orientation into the bitmap first.
        let upright = UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = upright.cgImage else { return image }

        let request = VNDetectDocumentSegmentationRequest()
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        guard let card = request.results?.first, card.confidence > 0.5 else {
            return upright
        }

        let ci = CIImage(cgImage: cgImage)
        let size = ci.extent.size
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * size.width, y: point.y * size.height)
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return upright }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(vector(card.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(card.topRight), forKey: "inputTopRight")
        filter.setValue(vector(card.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(vector(card.bottomRight), forKey: "inputBottomRight")
        guard let output = filter.outputImage,
              let cropped = ciContext.createCGImage(output, from: output.extent) else {
            return upright
        }
        return UIImage(cgImage: cropped)
    }
}

// ─── Live edge-detection overlay ────────────────────────────────────────────

/// Draws the detected card outline over the aspect-fill preview. The buffer is
/// rotated to portrait (same orientation the preview displays), so mapping is
/// plain aspect-fill math: scale to cover, center the overflow.
private struct QuadOverlay: View {
    let quad: [CGPoint]       // normalized, top-left origin, TL TR BR BL
    let bufferSize: CGSize
    let steady: Bool

    var body: some View {
        GeometryReader { geo in
            let points = mapped(into: geo.size)
            Path { path in
                guard points.count == 4 else { return }
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
            }
            .stroke(steady ? Color.green : .yellow,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .background(
                Path { path in
                    guard points.count == 4 else { return }
                    path.move(to: points[0])
                    for p in points.dropFirst() { path.addLine(to: p) }
                    path.closeSubpath()
                }
                .fill((steady ? Color.green : .yellow).opacity(0.12))
            )
            .animation(.linear(duration: 0.1), value: points)
        }
        .allowsHitTesting(false)
    }

    private func mapped(into viewSize: CGSize) -> [CGPoint] {
        guard bufferSize.width > 0, bufferSize.height > 0 else { return [] }
        // .resizeAspectFill: scale to cover, overflow split evenly.
        let scale = max(viewSize.width / bufferSize.width,
                        viewSize.height / bufferSize.height)
        let offsetX = (viewSize.width - bufferSize.width * scale) / 2
        let offsetY = (viewSize.height - bufferSize.height * scale) / 2
        return quad.map { p in
            CGPoint(x: p.x * bufferSize.width * scale + offsetX,
                    y: p.y * bufferSize.height * scale + offsetY)
        }
    }
}

// ─── SwiftUI camera preview ─────────────────────────────────────────────────

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}
