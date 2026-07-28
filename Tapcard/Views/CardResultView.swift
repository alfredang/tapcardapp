import SwiftUI

/// Success screen shown after a card is published: the live card rendered
/// natively, QR code, share actions, and (for a brand-new account) the issued
/// login credentials. Everything stays in the app — the public URL is for
/// sharing, not for viewing your own card.
struct CardResultView: View {
    let result: ScanViewModel.OnboardResult
    let card: BusinessCard
    var onDone: () -> Void

    @Environment(AccountStore.self) private var account
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.gradientPrimary)
                    Text("Your digital card is live")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.foreground)
                    Text(result.card.url.replacingOccurrences(of: "https://", with: ""))
                        .font(.footnote)
                        .foregroundStyle(Theme.mutedForeground)
                        .textSelection(.enabled)
                }
                .padding(.top)

                // The card itself — native, exactly as visitors see it.
                CardPreviewView(card: card)

                qrCard

                if result.isNewAccount, let password = result.password {
                    credentials(password: password)
                }

                VStack(spacing: 12) {
                    Button {
                        showShare = true
                    } label: {
                        Label("Share card", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GradientButtonStyle())

                    Button("Done", action: onDone)
                        .font(.headline)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Theme.background)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    private var qrCard: some View {
        VStack(spacing: 12) {
            if let qr = QRGenerator.image(for: result.card.url) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            Text("Scan to open the card")
                .font(.caption)
                .foregroundStyle(Theme.mutedForeground)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .surfaceCard()
    }

    private func credentials(password: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Account created", systemImage: "key.fill")
                .font(.headline)
            Text("Use these to sign in on another device — everything here stays in the app.")
                .font(.caption)
                .foregroundStyle(Theme.mutedForeground)
            Divider()
            row("Email", account.email ?? "")
            row("Password", password)
            Text("Saved securely in your Keychain.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.mutedForeground)
            Spacer()
            Text(value).fontDesign(.monospaced).textSelection(.enabled)
        }
        .font(.subheadline)
    }

    private var shareItems: [Any] {
        var items: [Any] = [URL(string: result.card.url) ?? result.card.url as Any]
        if let qr = QRGenerator.image(for: result.card.url) { items.append(qr) }
        return items
    }
}
