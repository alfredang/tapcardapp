import SwiftUI

/// What a card's QR code encodes.
///
/// When the card carries a phone number the QR points at the card page with
/// `?wa=1`, which hands off to WhatsApp on arrival. Encoding `wa.me` directly
/// would be one hop shorter, but a scanner without WhatsApp installed gets
/// bounced to the App Store and loses the contact entirely — routing through
/// the card page means they always land on something useful.
struct CardQRTarget {
    let url: String
    let isWhatsApp: Bool

    init(card: SavedCard) {
        let hasNumber = card.details.flatMap(WhatsAppLink.number(for:)) != nil
        isWhatsApp = hasNumber
        url = hasNumber ? card.url + "?wa=1&src=qr" : card.url + "?src=qr"
    }

    /// One-line explanation shown under the code.
    var caption: String {
        isWhatsApp ? "Scan to chat on WhatsApp" : "Scan to open my card"
    }
}

/// Compact QR panel for the Cards tab — your code front and center, Blinq
/// style, so sharing in person is one glance away. Tapping opens the
/// full-screen version.
struct MyQRPanel: View {
    let card: SavedCard
    @State private var showFull = false

    private var target: CardQRTarget { CardQRTarget(card: card) }

    var body: some View {
        Button {
            showFull = true
        } label: {
            VStack(spacing: 12) {
                if let qr = QRGenerator.image(for: target.url) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 168, height: 168)
                }

                if target.isWhatsApp {
                    HStack(spacing: 6) {
                        WhatsAppGlyph()
                            .frame(width: 16, height: 16)
                        Text(target.caption)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                    }
                    Text("They point their camera — WhatsApp opens with your details.")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                } else {
                    Text(target.caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.foreground)
                    Text("Add a mobile number so scanning opens WhatsApp.")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                }

                Text("Tap to enlarge")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedForeground.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(24)
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

    private var target: CardQRTarget { CardQRTarget(card: card) }

    var body: some View {
        ZStack {
            Theme.gradientPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    if let qr = QRGenerator.image(for: target.url) {
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

                    HStack(spacing: 8) {
                        if target.isWhatsApp {
                            WhatsAppGlyph().frame(width: 18, height: 18)
                        }
                        Text(target.caption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
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
