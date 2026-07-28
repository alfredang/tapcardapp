import SwiftUI

/// A published card, rendered natively (no browser round-trip): live preview,
/// edit, QR and share — mobile-first, with the web page as the share target.
struct SavedCardDetailView: View {
    @Environment(AccountStore.self) private var account
    let card: SavedCard
    @State private var showShare = false
    @State private var showQR = false

    /// Always render the freshest copy — edits refresh the store while this
    /// view stays on the stack.
    private var current: SavedCard {
        account.cards.first(where: { $0.id == card.id }) ?? card
    }

    private var details: BusinessCard {
        current.details ?? {
            var c = BusinessCard()
            c.fullName = current.fullName
            c.company = current.company
            return c
        }()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CardPreviewView(card: details) { showShare = true }

                // Primary actions — edit is first-class: this is the app the
                // card comes back to.
                HStack(spacing: 12) {
                    NavigationLink {
                        EditCardView(saved: current)
                    } label: {
                        actionLabel("Edit", icon: "pencil")
                    }
                    .buttonStyle(OutlineButtonStyle())

                    Button {
                        showQR = true
                    } label: {
                        actionLabel("QR", icon: "qrcode")
                    }
                    .buttonStyle(OutlineButtonStyle())

                    Button {
                        showShare = true
                    } label: {
                        actionLabel("Share", icon: "square.and.arrow.up")
                    }
                    .buttonStyle(GradientButtonStyle())
                }

                NavigationLink {
                    ShareToolsView(card: current)
                } label: {
                    Label("Email signature & virtual background", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                // The public link exists for sharing; viewing stays native.
                Text(current.url.replacingOccurrences(of: "https://", with: ""))
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedForeground)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("My card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .fullScreenCover(isPresented: $showQR) {
            QRShareView(card: current)
        }
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
    }

    private var shareItems: [Any] {
        var items: [Any] = [URL(string: current.url) ?? current.url as Any]
        // The vCard lets the recipient add the contact to their phone in one
        // tap — usable straight away in WhatsApp, calls and SMS.
        if let vcf = VCard.file(for: details, publicURL: current.url) { items.append(vcf) }
        if let qr = QRGenerator.image(for: current.url) { items.append(qr) }
        return items
    }
}
