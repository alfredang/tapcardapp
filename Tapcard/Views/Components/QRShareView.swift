import SwiftUI

/// Compact QR panel for the Cards tab — your code front and center, Blinq
/// style, so sharing in person is one glance away. Tapping opens the
/// full-screen version.
struct MyQRPanel: View {
    let card: SavedCard
    @State private var showFull = false

    var body: some View {
        Button {
            showFull = true
        } label: {
            VStack(spacing: 10) {
                if let qr = QRGenerator.image(for: card.url) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                }
                Text(card.fullName)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Text("Tap to enlarge · scan to connect")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .surfaceCard()
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFull) {
            QRShareView(card: card)
        }
    }
}

/// Full-screen QR for in-person sharing: big code on the brand gradient,
/// with the link and a share button underneath.
struct QRShareView: View {
    let card: SavedCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.gradientPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    if let qr = QRGenerator.image(for: card.url) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .background(.white,
                                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    Text(card.fullName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(card.url.replacingOccurrences(of: "https://", with: ""))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 44)

                Spacer()

                if let url = URL(string: card.url) {
                    ShareLink(item: url) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.white, in: Capsule())
                    }
                    .padding(.horizontal, 44)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .padding(.bottom, 24)
            }
        }
    }
}
