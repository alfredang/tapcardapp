import SwiftUI

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
    case fullName, jobTitle, company, email, mobile, officePhone,
         website, address, linkedin, facebook, instagram
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

    init(card: BusinessCard) {
        stored = card
        editing = nil
    }

    init(editing: Binding<BusinessCard>) {
        stored = editing.wrappedValue
        self.editing = editing
    }

    private var card: BusinessCard { editing?.wrappedValue ?? stored }
    private var isEditing: Bool { editing != nil }

    private var theme: CardTheme { card.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner + overlapping avatar
            theme.banner
                .frame(height: 92)
            HStack {
                ZStack {
                    Circle().fill(theme.accent)
                    Text(initials)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 68, height: 68)
                .overlay(Circle().stroke(theme.surface, lineWidth: 4))
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
                inlineText("Company", \.company,
                           font: .subheadline, color: theme.subtextColor)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            // Contact rows — inline-editable too.
            VStack(alignment: .leading, spacing: 8) {
                row("phone.fill", "Mobile",
                    !isEditing && card.mobile.trimmed.isEmpty ? \.officePhone : \.mobile,
                    keyboard: .phonePad)
                row("envelope.fill", "Email", \.email, keyboard: .emailAddress)
                row("globe", "Website", \.website, keyboard: .URL)
                row("mappin.and.ellipse", "Address", \.address)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            // The card's call-to-action, as visitors will see it.
            Text("Save Contact")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(theme.banner, in: Capsule())
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
        if isEditing || !card[keyPath: keyPath].trimmed.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                    .frame(width: 30, height: 30)
                    .background(theme.chip, in: Circle())
                inlineText(placeholder, keyPath,
                           font: .footnote, color: theme.textColor,
                           keyboard: keyboard)
                    .lineLimit(2)
            }
        }
    }

    private var initials: String {
        let parts = card.fullName.trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "T" : letters.uppercased()
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
            field("Company", text: $card.company, icon: "building.2", focus: .company)
        }

        Section("Contact") {
            field("Email", text: $card.email, icon: "envelope", focus: .email,
                  keyboard: .emailAddress, required: true)
            field("Mobile", text: $card.mobile, icon: "iphone", focus: .mobile, keyboard: .phonePad)
            field("Office phone", text: $card.officePhone, icon: "phone", focus: .officePhone, keyboard: .phonePad)
            field("Website", text: $card.website, icon: "globe", focus: .website, keyboard: .URL)
            field("Address", text: $card.address, icon: "mappin.and.ellipse", focus: .address)
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
