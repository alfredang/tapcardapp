import SwiftUI

/// What a card's QR code encodes for a given mode.
///
/// - **WhatsApp** — with your WhatsApp contact link on file (Settings →
///   Sharing), that link itself: the same code WhatsApp shows under QR code,
///   so scanning adds you as a contact. Otherwise the card page with `?wa=1`,
///   which opens a WhatsApp chat to the owner's international number with an
///   intro message. Encoding `wa.me` directly would be one hop shorter, but a
///   scanner without WhatsApp gets bounced to the App Store and loses the
///   contact; routing through the card page means they always land on
///   something useful.
/// - **LinkedIn** — the profile URL itself, so LinkedIn opens on Connect.
/// - **Card link** — the public card.
///
/// `url` is nil when the card lacks what the mode needs (no number, no
/// LinkedIn) — the panel then asks for it inline instead of showing a QR that
/// silently does something else.
struct CardQRTarget {
    let mode: QRMode
    let url: String?
    /// The international number a WhatsApp QR chats with ("+65 9698 3731").
    let whatsappNumber: String?
    /// The WhatsApp QR is your own WhatsApp contact link: it adds you as a
    /// contact rather than opening a chat.
    let addsWhatsAppContact: Bool

    init(card: SavedCard, mode: QRMode, preferences: UserPreferences) {
        self.mode = mode
        let countryCode = preferences.countryCode
        let contactLink = preferences.whatsappQr.isEmpty ? nil : preferences.whatsappQr
        addsWhatsAppContact = mode == .whatsapp && contactLink != nil
        let details = card.details
        whatsappNumber = details
            .flatMap { WhatsAppLink.number(for: $0, countryCode: countryCode) }
            .map { PhoneNumber.display(digits: $0, countryCode: countryCode) }
        switch mode {
        case .linkedin:
            url = details.flatMap(WhatsAppLink.linkedInURL(for:))
        case .whatsapp:
            if let contactLink {
                url = contactLink
            } else {
                url = whatsappNumber == nil ? nil : Self.cardURL(card.url, whatsapp: true)
            }
        case .card:
            url = Self.cardURL(card.url, whatsapp: false)
        }
    }

    private static func cardURL(_ base: String, whatsapp: Bool) -> String {
        var components = URLComponents(string: base)
        var items = (components?.queryItems ?? []).filter { $0.name != "wa" && $0.name != "src" }
        if whatsapp { items.append(URLQueryItem(name: "wa", value: "1")) }
        items.append(URLQueryItem(name: "src", value: "qr"))
        components?.queryItems = items
        return components?.url?.absoluteString ?? base
    }

    var caption: String {
        switch mode {
        case .whatsapp: addsWhatsAppContact ? "Scan to add me on WhatsApp" : "Scan to chat on WhatsApp"
        case .linkedin: "Scan to connect on LinkedIn"
        case .card: "Scan to open my card"
        }
    }

    var detail: String {
        switch mode {
        case .whatsapp where addsWhatsAppContact:
            "Saves you as a WhatsApp contact — the same code as in WhatsApp."
        case .whatsapp:
            "Opens a WhatsApp chat with \(whatsappNumber ?? "you"), with an intro message ready to send."
        case .linkedin: "Opens your LinkedIn profile so they can connect in one tap."
        case .card: "Opens your digital card — they can save your contact from there."
        }
    }
}

/// The QR panel on the Cards tab: pick what the code opens, show it, tap to
/// enlarge. The choice is the account's synced default (Settings → Sharing),
/// so it sticks across launches and matches the web.
struct MyQRPanel: View {
    let card: SavedCard
    @Environment(AccountStore.self) private var account
    @State private var showFull = false

    private var target: CardQRTarget {
        CardQRTarget(card: card, mode: account.preferences.qrMode,
                     preferences: account.preferences)
    }

    var body: some View {
        VStack(spacing: 14) {
            QRModePicker(selection: Binding(
                get: { account.preferences.qrMode },
                set: { mode in Task { _ = await account.updatePreferences(qrMode: mode) } }))

            if let url = target.url {
                Button {
                    showFull = true
                } label: {
                    VStack(spacing: 10) {
                        QRCodeImage(payload: url, mode: target.mode)
                            .frame(width: 176, height: 176)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1))
                            .accessibilityLabel("QR code: \(target.caption)")
                        QRCaption(target: target)
                        Text("Tap to enlarge")
                            .font(.caption2)
                            .foregroundStyle(Theme.mutedForeground.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                QRMissingDetail(card: card, mode: target.mode)
            }
        }
        .padding(20)
        .surfaceCard()
        .fullScreenCover(isPresented: $showFull) {
            QRShareView(card: card, initialMode: account.preferences.qrMode)
        }
    }
}

/// Caption + one-line explanation under a QR.
private struct QRCaption: View {
    let target: CardQRTarget
    var onDark = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                if target.mode == .whatsapp {
                    WhatsAppGlyph().frame(width: 16, height: 16)
                } else {
                    Image(systemName: target.mode.icon)
                }
                Text(target.caption).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(onDark ? .white : Theme.foreground)
            Text(target.detail)
                .font(.caption)
                .foregroundStyle(onDark ? .white.opacity(0.85) : Theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
    }
}

/// Segmented WhatsApp / LinkedIn / Card link switch.
struct QRModePicker: View {
    @Binding var selection: QRMode

    var body: some View {
        Picker("QR code opens", selection: $selection) {
            ForEach(QRMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Shown in place of the QR when the card lacks the mode's detail — one field
/// and a Save button, right here, instead of a trip to Edit card.
struct QRMissingDetail: View {
    let card: SavedCard
    let mode: QRMode
    @Environment(AccountStore.self) private var account
    @State private var entry = ""
    @State private var isSaving = false
    @State private var error: String?

    private var title: String {
        mode == .linkedin ? "Add your LinkedIn profile" : "Add your WhatsApp number"
    }
    private var prompt: String {
        mode == .linkedin
            ? "Paste your profile link or handle — e.g. linkedin.com/in/yourname."
            : "Local numbers get +\(account.preferences.countryCode) added automatically."
    }

    /// The card with the entry applied, or nil while the entry is unusable.
    private var updated: BusinessCard? {
        var details = card.details ?? BusinessCard()
        if details.fullName.trimmed.isEmpty { details.fullName = card.fullName }
        switch mode {
        case .linkedin:
            details.linkedin = entry.trimmed
            guard let url = WhatsAppLink.linkedInURL(for: details) else { return nil }
            details.linkedin = url
        case .whatsapp:
            guard entry.filter(\.isNumber).count >= 6 else { return nil }
            details.whatsapp = entry.trimmed
        case .card:
            return nil
        }
        return details
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: mode == .linkedin ? "person.badge.plus" : "phone.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(Theme.primary)
            Text(title).font(.headline)
            Text(prompt)
                .font(.caption)
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center)
            TextField(mode == .linkedin ? "linkedin.com/in/yourname" : "9123 4567", text: $entry)
                .keyboardType(mode == .linkedin ? .URL : .phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(save)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button(action: save) {
                HStack(spacing: 6) {
                    if isSaving { ProgressView().tint(.white) }
                    Text("Save and show QR")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(updated == nil || isSaving)
        }
        .padding(.vertical, 6)
    }

    private func save() {
        guard let details = updated, !isSaving else { return }
        isSaving = true
        error = nil
        Task {
            error = await account.saveCard(card.id, details: details)
            isSaving = false
        }
    }
}

/// Full-screen QR for in-person sharing: big code on the brand gradient,
/// with the link and share actions underneath.
struct QRShareView: View {
    let card: SavedCard
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var mode: QRMode
    @State private var shareQR = false

    init(card: SavedCard, initialMode: QRMode) {
        self.card = card
        _mode = State(initialValue: initialMode)
    }

    /// The live card (an inline LinkedIn / number save updates it).
    private var current: SavedCard { account.cards.first { $0.id == card.id } ?? card }
    private var target: CardQRTarget {
        CardQRTarget(card: current, mode: mode, preferences: account.preferences)
    }

    var body: some View {
        ZStack {
            Theme.gradientPrimary.ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.2), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                QRModePicker(selection: $mode)
                    .padding(6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)

                Group {
                    if let url = target.url {
                        QRCodeImage(payload: url, mode: target.mode)
                            .padding(14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .accessibilityLabel("QR code: \(target.caption)")
                    } else {
                        QRMissingDetail(card: current, mode: mode)
                            .padding(18)
                            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .padding(.horizontal, 40)

                VStack(spacing: 8) {
                    Text(current.fullName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    if target.url != nil {
                        QRCaption(target: target, onDark: true)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer(minLength: 0)

                if let link = target.url, let url = URL(string: link) {
                    VStack(spacing: 14) {
                        ShareLink(item: url) {
                            Label(mode == .linkedin ? "Share LinkedIn profile"
                                  : target.addsWhatsAppContact ? "Share WhatsApp link" : "Share card link",
                                  systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundStyle(Theme.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.white, in: Capsule())
                        }
                        Button {
                            shareQR = true
                        } label: {
                            Label("Share QR image", systemImage: "qrcode")
                                .font(.headline).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 44)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $shareQR) {
            if let link = target.url, let image = QRCodeImage.shareImage(payload: link, mode: target.mode) {
                ShareSheet(items: [image, link])
            }
        }
    }
}

/// A QR code as a view. The WhatsApp QR takes WhatsApp's own look — its mark
/// in the middle — encoded at high error correction so the mark never costs
/// a scan. Callers put it on a white tile.
struct QRCodeImage: View {
    let payload: String
    let mode: QRMode

    private var branded: Bool { mode == .whatsapp }

    var body: some View {
        if let qr = QRGenerator.image(for: payload, correctionLevel: branded ? "H" : "M") {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .overlay {
                    if branded {
                        GeometryReader { geo in
                            let side = min(geo.size.width, geo.size.height) * 0.24
                            QRWhatsAppMark()
                                .frame(width: side, height: side)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        }
                    }
                }
        }
    }

    /// The QR on its white tile as an image, for the share sheet.
    @MainActor
    static func shareImage(payload: String, mode: QRMode) -> UIImage? {
        let renderer = ImageRenderer(content:
            QRCodeImage(payload: payload, mode: mode)
                .frame(width: 600, height: 600)
                .padding(48)
                .background(.white))
        renderer.scale = 2
        return renderer.uiImage
    }
}

/// WhatsApp's in-QR mark: the outlined bubble and handset, in black on a
/// white disc that clears the modules beneath it.
private struct QRWhatsAppMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(.white)
                WhatsAppBubble().fill(.white).padding(s * 0.14)
                WhatsAppBubble().stroke(.black, lineWidth: s * 0.075).padding(s * 0.14)
                Image(systemName: "phone.fill")
                    .font(.system(size: s * 0.34, weight: .semibold))
                    .foregroundStyle(.black)
                    .offset(x: s * 0.01, y: -s * 0.015)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
