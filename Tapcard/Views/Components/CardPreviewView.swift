import SwiftUI
import PhotosUI

// ─── Per-theme design tokens ────────────────────────────────────────────────

extension CardTheme {
    /// Dark-surface templates render light text on a dark card.
    var isDark: Bool {
        switch self {
        case .dark, .luxury, .midnight, .graphite: true
        default: false
        }
    }

    var accent: Color { Color(hex: gradientHexes.start) }

    var banner: LinearGradient {
        LinearGradient(colors: [Color(hex: gradientHexes.start),
                                Color(hex: gradientHexes.end)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var surface: Color { isDark ? Color(hex: "#17171D") : .white }
    var textColor: Color { isDark ? Color(hex: "#F4F4F5") : Theme.foreground }
    var subtextColor: Color { isDark ? Color(hex: "#A1A1AA") : Theme.mutedForeground }
    var chip: Color { accent.opacity(isDark ? 0.22 : 0.10) }
}

// ─── Native card preview ────────────────────────────────────────────────────

/// A field on the card — used to jump from a tapped preview element straight
/// to its form field.
enum CardField: Hashable {
    case fullName, jobTitle, tagline, company, email, mobile, officePhone,
         whatsapp, website, addressLine1, addressLine2, zipcode, bio,
         linkedin, facebook, instagram
}

/// The digital card rendered natively, Blinq-style — a pure function of
/// `BusinessCard`, so theme and field edits re-render instantly.
///
/// Two modes:
/// - read-only (`card:`) — how visitors see it;
/// - WYSIWYG (`editing:`) — every text element becomes an inline field,
///   edited in place with the card's own typography and colors.
struct CardPreviewView: View {
    private let stored: BusinessCard
    private var editing: Binding<BusinessCard>?
    /// The card's call-to-action. On the real card visitors tap "Save
    /// Contact" to download the vCard; in the app the button always does
    /// something real — save/publish/share — never a dead control.
    private let ctaTitle: String
    private let onCTA: (() -> Void)?

    init(card: BusinessCard, ctaTitle: String = "Save Contact",
         onCTA: (() -> Void)? = nil) {
        stored = card
        editing = nil
        self.ctaTitle = ctaTitle
        self.onCTA = onCTA
    }

    init(editing: Binding<BusinessCard>, ctaTitle: String,
         onCTA: @escaping () -> Void) {
        stored = editing.wrappedValue
        self.editing = editing
        self.ctaTitle = ctaTitle
        self.onCTA = onCTA
    }

    private var card: BusinessCard { editing?.wrappedValue ?? stored }
    private var isEditing: Bool { editing != nil }

    private var theme: CardTheme { card.theme }

    // Image editing (photo library) + maps chooser state.
    private enum ImageTarget { case avatar, banner }
    @State private var imageTarget: ImageTarget = .avatar
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showMapChooser = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner + overlapping avatar (both replaceable while editing).
            // Images render as overlays: overlay content has no say in
            // layout, so a huge photo can't inflate the row height.
            Color.clear
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .background(theme.banner)
                .overlay {
                    if !card.coverBanner.trimmed.isEmpty {
                        CardImageView(source: card.coverBanner)
                    }
                }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if isEditing {
                        imageMenu(for: .banner).padding(8)
                    }
                }
            HStack {
                ZStack(alignment: .bottomTrailing) {
                    avatar
                    if isEditing {
                        imageMenu(for: .avatar).offset(x: 4, y: 4)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, -34)

            // Identity — in editing mode every line is typed in place.
            VStack(alignment: .leading, spacing: 3) {
                inlineText("Your Name", \.fullName,
                           font: .title3.bold(), color: theme.textColor)
                inlineText("Job title", \.jobTitle,
                           font: .subheadline, color: theme.subtextColor)
                inlineText("Tagline", \.tagline,
                           font: .footnote.italic(), color: theme.accent)
                bioText
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            // Contact rows — inline-editable too.
            VStack(alignment: .leading, spacing: 8) {
                row("building.2.fill", "Company", \.company)
                row("iphone", "Mobile", \.mobile, keyboard: .phonePad)
                row("phone.fill", "Landline", \.officePhone, keyboard: .phonePad)
                row("message.fill", "WhatsApp", \.whatsapp, keyboard: .phonePad)
                row("envelope.fill", "Email", \.email, keyboard: .emailAddress)
                row("globe", "Website", \.website, keyboard: .URL)
                addressBlock
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            // The card's call-to-action. Tappable whenever a real action was
            // provided; plain artwork otherwise.
            Group {
                if let onCTA {
                    Button(action: onCTA) { ctaLabel }
                        .buttonStyle(.plain)
                } else {
                    ctaLabel
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.isDark ? .white.opacity(0.08) : Theme.border, lineWidth: 1)
        )
        .shadow(color: theme.accent.opacity(0.18), radius: 18, y: 10)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    applyImage(image)
                }
            }
        }
    }

    // ─── Image editing ──────────────────────────────────────────────────────

    private var currentImage: String {
        imageTarget == .avatar ? card.profilePhoto : card.coverBanner
    }

    private func setImage(_ value: String) {
        switch imageTarget {
        case .avatar: editing?.wrappedValue.profilePhoto = value
        case .banner: editing?.wrappedValue.coverBanner = value
        }
    }

    /// Downscale, compress and store as a base64 data URL (the same format
    /// the web builder uploads), keeping payloads well under the API cap.
    private func applyImage(_ image: UIImage) {
        let maxDim: CGFloat = imageTarget == .avatar ? 512 : 1400
        let scale = min(1, maxDim / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return }
        setImage("data:image/jpeg;base64," + data.base64EncodedString())
    }

    /// Camera badge that opens an anchored menu right where it sits — no
    /// detached bottom sheet.
    private func imageMenu(for target: ImageTarget) -> some View {
        Menu {
            Button {
                imageTarget = target
                showPhotoPicker = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            if !(target == .avatar ? card.profilePhoto : card.coverBanner).isEmpty {
                Button(role: .destructive) {
                    imageTarget = target
                    setImage("")
                } label: {
                    Label("Remove image", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.55), in: Circle())
        }
        .accessibilityLabel(target == .avatar ? "Change profile photo" : "Change banner image")
    }


    private var avatar: some View {
        Circle()
            .fill(theme.accent)
            .frame(width: 68, height: 68)
            .overlay {
                if !card.profilePhoto.trimmed.isEmpty {
                    CardImageView(source: card.profilePhoto)
                } else {
                    Text(initials)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
            }
            .clipShape(Circle())
            .overlay(Circle().stroke(theme.surface, lineWidth: 4))
    }

    // ─── Structured address ─────────────────────────────────────────────────

    /// Editing: line 1 / line 2 / postal code typed in place. Read-only: the
    /// composed address, tappable to open Apple Maps or Google Maps.
    @ViewBuilder
    private var addressBlock: some View {
        if isEditing {
            HStack(alignment: .top, spacing: 10) {
                addressChip
                VStack(spacing: 6) {
                    inlineText("Address line 1", \.addressLine1,
                               font: .footnote, color: theme.textColor)
                    inlineText("Address line 2", \.addressLine2,
                               font: .footnote, color: theme.textColor)
                    inlineText("Postal code", \.zipcode,
                               font: .footnote, color: theme.textColor)
                }
            }
        } else if !card.composedAddress.isEmpty {
            Button {
                showMapChooser = true
            } label: {
                HStack(spacing: 10) {
                    addressChip
                    Text(card.composedAddress)
                        .font(.footnote)
                        .foregroundStyle(theme.textColor)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
            .confirmationDialog("Open address in…", isPresented: $showMapChooser,
                                titleVisibility: .visible) {
                Button("Apple Maps") { openMaps(apple: true) }
                Button("Google Maps") { openMaps(apple: false) }
            }
        }
    }

    private var addressChip: some View {
        Image(systemName: "mappin.and.ellipse")
            .font(.caption)
            .foregroundStyle(theme.accent)
            .frame(width: 30, height: 30)
            .background(theme.chip, in: Circle())
    }

    private func openMaps(apple: Bool) {
        let query = card.composedAddress
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let raw = apple
            ? "https://maps.apple.com/?q=\(query)"
            : "https://www.google.com/maps/search/?api=1&query=\(query)"
        if let url = URL(string: raw) { openURL(url) }
    }

    private var ctaLabel: some View {
        Text(ctaTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(theme.banner, in: Capsule())
    }

    /// The short bio under the identity block — multiline, capped at 1000
    /// characters while editing.
    @ViewBuilder
    private var bioText: some View {
        if isEditing {
            TextField("Short bio (up to 1000 characters)",
                      text: Binding(
                          get: { editing?.wrappedValue.bio ?? "" },
                          set: { editing?.wrappedValue.bio = String($0.prefix(1000)) }
                      ),
                      axis: .vertical)
                .font(.footnote)
                .foregroundStyle(theme.subtextColor)
                .lineLimit(1...5)
                .padding(.top, 4)
        } else if !card.bio.trimmed.isEmpty {
            Text(card.bio)
                .font(.footnote)
                .foregroundStyle(theme.subtextColor)
                .padding(.top, 4)
        }
    }

    /// A binding into the edited card for one field.
    private func binding(_ keyPath: WritableKeyPath<BusinessCard, String>) -> Binding<String> {
        Binding(
            get: { editing?.wrappedValue[keyPath: keyPath] ?? "" },
            set: { editing?.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    /// Text that becomes an in-place field while editing; hidden entirely when
    /// read-only and empty (identity lines and rows share this rule).
    @ViewBuilder
    private func inlineText(_ placeholder: String,
                            _ keyPath: WritableKeyPath<BusinessCard, String>,
                            font: Font, color: Color,
                            keyboard: UIKeyboardType = .default) -> some View {
        if isEditing {
            TextField(placeholder, text: binding(keyPath))
                .font(font)
                .foregroundStyle(color)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
        } else if keyPath == \.fullName {
            Text(card.fullName.trimmed.isEmpty ? "Your Name" : card.fullName)
                .font(font)
                .foregroundStyle(color)
        } else if !card[keyPath: keyPath].trimmed.isEmpty {
            Text(card[keyPath: keyPath])
                .font(font)
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func row(_ icon: String, _ placeholder: String,
                     _ keyPath: WritableKeyPath<BusinessCard, String>,
                     keyboard: UIKeyboardType = .default) -> some View {
        if isEditing {
            rowContent(icon, placeholder, keyPath, keyboard: keyboard)
        } else if !card[keyPath: keyPath].trimmed.isEmpty {
            // Read-only rows act: website opens the default browser, email
            // composes, phone numbers dial.
            if let url = actionURL(for: keyPath) {
                Button {
                    openURL(url)
                } label: {
                    rowContent(icon, placeholder, keyPath, keyboard: keyboard)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(icon, placeholder, keyPath, keyboard: keyboard)
            }
        }
    }

    private func rowContent(_ icon: String, _ placeholder: String,
                            _ keyPath: WritableKeyPath<BusinessCard, String>,
                            keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 10) {
            if keyPath == \.whatsapp {
                WhatsAppGlyph()
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                    .frame(width: 30, height: 30)
                    .background(theme.chip, in: Circle())
            }
            inlineText(placeholder, keyPath,
                       font: .footnote, color: theme.textColor,
                       keyboard: keyboard)
                .lineLimit(2)
        }
    }

    /// The tap action for a read-only row, when it has one.
    private func actionURL(for keyPath: WritableKeyPath<BusinessCard, String>) -> URL? {
        let value = card[keyPath: keyPath].trimmed
        switch keyPath {
        case \.website:
            let raw = value.lowercased().hasPrefix("http") ? value : "https://" + value
            return URL(string: raw)
        case \.email:
            return URL(string: "mailto:\(value)")
        case \.mobile, \.officePhone:
            let digits = value.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        case \.whatsapp:
            // wa.me wants digits only, no + or spaces.
            let digits = value.filter(\.isNumber)
            return digits.isEmpty ? nil : URL(string: "https://wa.me/\(digits)")
        default:
            return nil
        }
    }

    private var initials: String {
        let parts = card.fullName.trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "T" : letters.uppercased()
    }
}

// ─── Card imagery ───────────────────────────────────────────────────────────

/// Renders a card image source — a base64 `data:` URL (uploaded/AI-generated)
/// or a hosted https URL — filling its frame.
struct CardImageView: View {
    let source: String

    var body: some View {
        if let ui = Self.decode(source) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if source.hasPrefix("http"), let url = URL(string: source) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }

    /// Decode a `data:image/...;base64,` URL into a UIImage.
    static func decode(_ source: String) -> UIImage? {
        guard source.hasPrefix("data:"),
              let comma = source.firstIndex(of: ",") else { return nil }
        let base64 = String(source[source.index(after: comma)...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

// ─── Theme swatch grid ──────────────────────────────────────────────────────

/// All 20 templates as tappable gradient swatches. Selection re-renders any
/// `CardPreviewView` bound to the same card instantly.
struct ThemeSwatchGrid: View {
    @Binding var selection: CardTheme

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                  spacing: 12) {
            ForEach(CardTheme.allCases) { theme in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = theme }
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.banner)
                            .frame(height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selection == theme ? Theme.primary : .clear,
                                            lineWidth: 2.5)
                            )
                        Text(theme.label)
                            .font(.caption2)
                            .foregroundStyle(selection == theme
                                             ? Theme.primary : Theme.mutedForeground)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.label) theme")
                .accessibilityAddTraits(selection == theme ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

// ─── Shared editable form sections ──────────────────────────────────────────

/// The card's editable fields — shared by the scan-review flow and the saved
/// card editor so the two never drift. Every field has a one-tap clear (⊗),
/// and the bound `FocusState` lets a tap on the preview jump straight here.
struct CardFormFields: View {
    @Binding var card: BusinessCard
    var focus: FocusState<CardField?>.Binding

    var body: some View {
        Section("Identity") {
            field("Full name", text: $card.fullName, icon: "person", focus: .fullName, required: true)
            field("Job title", text: $card.jobTitle, icon: "briefcase", focus: .jobTitle)
            field("Tagline", text: $card.tagline, icon: "quote.opening", focus: .tagline)
            field("Company", text: $card.company, icon: "building.2", focus: .company)
        }

        Section("Contact") {
            field("Email", text: $card.email, icon: "envelope", focus: .email,
                  keyboard: .emailAddress, required: true)
            field("Mobile", text: $card.mobile, icon: "iphone", focus: .mobile, keyboard: .phonePad)
            field("Landline", text: $card.officePhone, icon: "phone", focus: .officePhone, keyboard: .phonePad)
            field("WhatsApp", text: $card.whatsapp, icon: "message", focus: .whatsapp, keyboard: .phonePad)
            field("Website", text: $card.website, icon: "globe", focus: .website, keyboard: .URL)
            field("Address line 1", text: $card.addressLine1, icon: "mappin.and.ellipse", focus: .addressLine1)
            field("Address line 2", text: $card.addressLine2, icon: "mappin", focus: .addressLine2)
            field("Postal code", text: $card.zipcode, icon: "number", focus: .zipcode)
            bioField
        }

        Section("Social") {
            field("LinkedIn", text: $card.linkedin, icon: "link", focus: .linkedin)
            field("Facebook", text: $card.facebook, icon: "hand.thumbsup", focus: .facebook)
            field("Instagram", text: $card.instagram, icon: "camera", focus: .instagram)
        }

        Section("Design") {
            ThemeSwatchGrid(selection: $card.theme)
        }
    }

    /// Multiline bio, capped at 1000 characters with a live count.
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Short bio",
                          text: Binding(
                              get: { card.bio },
                              set: { card.bio = String($0.prefix(1000)) }
                          ),
                          axis: .vertical)
                    .lineLimit(2...6)
                    .focused(focus, equals: .bio)
                if !card.bio.isEmpty {
                    Button {
                        card.bio = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear bio")
                }
            }
            if !card.bio.isEmpty {
                Text("\(card.bio.count)/1000")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .id(CardField.bio)
    }

    @ViewBuilder
    private func field(
        _ title: String,
        text: Binding<String>,
        icon: String,
        focus focusField: CardField,
        keyboard: UIKeyboardType = .default,
        required: Bool = false
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(required ? "\(title) (required)" : title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
                .focused(focus, equals: focusField)
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(title)")
            }
        }
        .id(focusField)
    }
}


// ─── WhatsApp brand glyph ───────────────────────────────────────────────────

/// A drawn WhatsApp mark — green speech bubble with a tail and a white
/// handset — since SF Symbols carries no brand icons.
struct WhatsAppGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                WhatsAppBubble()
                    .fill(Color(hex: "#25D366"))
                Image(systemName: "phone.fill")
                    .font(.system(size: s * 0.40, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: s * 0.01, y: -s * 0.02)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("WhatsApp")
    }
}

/// Speech-bubble circle with the characteristic bottom-left tail.
private struct WhatsAppBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height)
        let bubble = CGRect(x: rect.midX - s / 2, y: rect.midY - s / 2, width: s, height: s)
        path.addEllipse(in: bubble.insetBy(dx: s * 0.02, dy: s * 0.02))
        // Tail: small wedge poking out at the lower-left.
        path.move(to: CGPoint(x: bubble.minX + s * 0.10, y: bubble.maxY - s * 0.30))
        path.addLine(to: CGPoint(x: bubble.minX + s * 0.02, y: bubble.maxY - s * 0.02))
        path.addLine(to: CGPoint(x: bubble.minX + s * 0.34, y: bubble.maxY - s * 0.10))
        path.closeSubpath()
        return path
    }
}
