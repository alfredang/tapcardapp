import SwiftUI
import UIKit

/// Share tools for a published card — mirrors the Android generators: an email
/// signature (copied to the clipboard) and a 1920×1080 virtual meeting
/// background with the card's QR code (shared/saved as an image).
struct ShareToolsView: View {
    let card: SavedCard

    @State private var signatureCopied = false
    @State private var backgroundImage: UIImage?
    @State private var showShare = false

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                signatureSection
                backgroundSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Share tools")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let backgroundImage {
                ShareSheet(items: [backgroundImage])
            }
        }
    }

    // ─── Email signature ────────────────────────────────────────────────────

    private var signatureText: String {
        var lines = [card.fullName]
        if !card.company.isEmpty { lines.append(card.company) }
        lines.append("Digital business card: \(card.url)")
        return lines.joined(separator: "\n")
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Email signature", systemImage: "signature")
                .font(.headline)
            Text(signatureText)
                .font(.footnote.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                UIPasteboard.general.string = signatureText
                signatureCopied = true
            } label: {
                Label(signatureCopied ? "Copied!" : "Copy signature",
                      systemImage: signatureCopied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            Text("Paste it into your email app's signature settings — every email then links to your card.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // ─── Virtual background ─────────────────────────────────────────────────

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Virtual meeting background", systemImage: "video.fill")
                .font(.headline)
            VirtualBackgroundCanvas(card: card, accent: accent)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                renderAndShare()
            } label: {
                Label("Share background image", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            Text("A 1920×1080 background for Zoom, Teams or Meet — attendees can scan the QR to get your card.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func renderAndShare() {
        let renderer = ImageRenderer(content:
            VirtualBackgroundCanvas(card: card, accent: accent)
                .frame(width: 1920, height: 1080)
        )
        renderer.scale = 1
        if let image = renderer.uiImage {
            backgroundImage = image
            showShare = true
        }
    }
}

/// The 16:9 background artwork — rendered on screen as a preview and offscreen
/// at 1920×1080 for export.
private struct VirtualBackgroundCanvas: View {
    let card: SavedCard
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / 1080
            ZStack {
                LinearGradient(colors: [Color(hex: "#101223"), Color(hex: "#232853")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 900 * unit)
                    .offset(x: geo.size.width * 0.42, y: -geo.size.height * 0.4)

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8 * unit) {
                            Text(card.fullName)
                                .font(.system(size: 64 * unit, weight: .bold))
                            if !card.company.isEmpty {
                                Text(card.company)
                                    .font(.system(size: 40 * unit, weight: .medium))
                                    .opacity(0.85)
                            }
                            Text(card.url.replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 28 * unit))
                                .opacity(0.7)
                        }
                        .foregroundStyle(.white)
                        Spacer()
                        if let qr = QRGenerator.image(for: card.url) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 220 * unit, height: 220 * unit)
                                .padding(16 * unit)
                                .background(.white, in: RoundedRectangle(cornerRadius: 20 * unit))
                        }
                    }
                    .padding(60 * unit)
                }
            }
        }
    }
}
