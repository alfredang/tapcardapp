import SwiftUI

/// Success screen shown after a card is published: QR code, public link, share
/// actions, and (for a brand-new account) the issued login credentials.
struct CardResultView: View {
    let result: ScanViewModel.OnboardResult
    var onDone: () -> Void

    @Environment(AccountStore.self) private var account
    @State private var showShare = false

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(accent)
                    Text("Your digital card is live")
                        .font(.title2.bold())
                    Text(result.card.url)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.top)

                qrCard

                if result.isNewAccount, let password = result.password {
                    credentials(password: password)
                }

                VStack(spacing: 12) {
                    Button {
                        showShare = true
                    } label: {
                        Label("Share card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                    Link(destination: URL(string: result.card.url)!) {
                        Label("Open public card", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button("Done", action: onDone)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
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
                    .frame(width: 220, height: 220)
            }
            Text("Scan to open the card")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func credentials(password: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Account created", systemImage: "key.fill")
                .font(.headline)
            Text("Sign in at tapcard.tertiaryinfotech.com to manage your card and leads.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            row("Email", result.card.url.isEmpty ? "" : account.email ?? "")
            row("Password", password)
            Text("Saved securely in your Keychain.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
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
