import SwiftUI

/// Detail view for a previously created card — re-shows the QR, link and share.
struct SavedCardDetailView: View {
    let card: SavedCard
    @State private var showShare = false

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(card.fullName).font(.title2.bold())
                    if !card.company.isEmpty {
                        Text(card.company).foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                if let qr = QRGenerator.image(for: card.url) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(24)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Text(card.url)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

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

                Link(destination: URL(string: card.url)!) {
                    Label("Open public card", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = [URL(string: card.url) ?? card.url as Any]
        if let qr = QRGenerator.image(for: card.url) { items.append(qr) }
        return items
    }
}
