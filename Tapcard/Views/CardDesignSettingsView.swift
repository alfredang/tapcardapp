import SwiftUI

/// Settings → Card design. Pick one of the 20 designs and a colour scheme
/// with a live preview; every tap saves straight to the account, so the
/// public web card changes too — no separate Save step.
struct CardDesignSettingsView: View {
    @Environment(AccountStore.self) private var account
    let cardID: String

    @State private var errorMessage: String?
    /// What Image Playground is generating, while its sheet is up.
    @State private var generating: CardImageKind?
    @State private var isSavingImage = false

    /// Hand-picked accents that read well on every light and dark design.
    static let accents: [(name: String, hex: String)] = [
        ("Violet", "#7C3AED"), ("Blue", "#2563EB"), ("Cyan", "#0891B2"),
        ("Teal", "#0D9488"), ("Green", "#16A34A"), ("Gold", "#CA8A04"),
        ("Orange", "#EA580C"), ("Rose", "#E11D48"), ("Pink", "#DB2777"),
        ("Ink", "#111827"),
    ]

    private var saved: SavedCard? { account.card(withID: cardID) }
    private var details: BusinessCard { saved?.details ?? BusinessCard() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CardPreviewView(card: details, ctaTitle: "Save Contact")
                    .allowsHitTesting(false)
                    .animation(.snappy(duration: 0.25), value: details.theme)
                    .animation(.snappy(duration: 0.25), value: details.accentColor)

                section("Colour scheme",
                        footer: "Match design uses each design's own colours.") {
                    accentRow
                }

                IfImagePlaygroundSupported {
                    section("Apple Intelligence",
                            footer: "Images are created on your iPhone from your card's design, job title and company — edit the ideas before you create.") {
                        aiImageButtons
                    }
                }

                section("Design · 20 templates", footer: nil) {
                    ThemeSwatchGrid(selection: Binding(
                        get: { details.theme },
                        set: { apply(theme: $0, accent: details.accentColor) }))
                }

                Label("Saved automatically — your web card updates too.", systemImage: "checkmark.icloud")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedForeground)
            }
            .padding(16)
        }
        .background(Theme.background)
        .appleIntelligenceImageSheet(
            isPresented: Binding(get: { generating != nil }, set: { if !$0 { generating = nil } }),
            // A photo of you lets it draw your likeness.
            sourceImage: generating == .avatar ? CardImageView.decode(details.profilePhoto) : nil
        ) { image in
            if let kind = generating { save(image, as: kind) }
        }
        .navigationTitle("Card design")
        .navigationBarTitleDisplayMode(.inline)
        // An alert, not an inline note: the grid is usually scrolled past
        // anything at the top, so a failed save looked like a dead tap.
        .alert("Couldn't save your card",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var accentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                swatch(name: "Match design", fill: AnyShapeStyle(details.theme.banner),
                       selected: details.customAccentHex == nil) {
                    apply(theme: details.theme, accent: "")
                }
                ForEach(Self.accents, id: \.hex) { accent in
                    swatch(name: accent.name, fill: AnyShapeStyle(Color(hex: accent.hex)),
                           selected: details.customAccentHex?.lowercased() == accent.hex.lowercased()) {
                        apply(theme: details.theme, accent: accent.hex)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    private func swatch(name: String, fill: AnyShapeStyle, selected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(fill)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 0))
                    .overlay(Circle().stroke(selected ? Theme.primary : Theme.border,
                                             lineWidth: selected ? 2 : 1).padding(selected ? -3 : 0))
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(selected ? Theme.foreground : Theme.mutedForeground)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) colour")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func section<Content: View>(_ title: String, footer: String?,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
            if let footer {
                Text(footer).font(.caption).foregroundStyle(Theme.mutedForeground)
            }
        }
    }

    private var aiImageButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    generating = .banner
                } label: {
                    Label("Create banner", systemImage: "apple.intelligence")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                Button {
                    generating = .avatar
                } label: {
                    Label("Create photo", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .disabled(isSavingImage)
            if isSavingImage {
                ProgressView("Saving…").font(.caption)
            } else if !details.coverBanner.trimmed.isEmpty {
                Button("Use the design's banner instead", role: .destructive) {
                    var updated = details
                    updated.coverBanner = ""
                    save(updated)
                }
                .font(.footnote)
            }
        }
    }

    private func save(_ image: UIImage, as kind: CardImageKind) {
        guard let url = kind.dataURL(for: image) else { return }
        var updated = details
        switch kind {
        case .banner: updated.coverBanner = url
        case .avatar: updated.profilePhoto = url
        }
        save(updated)
    }

    private func save(_ updated: BusinessCard) {
        guard let saved else { return }
        var updated = updated
        if updated.fullName.trimmed.isEmpty { updated.fullName = saved.fullName }
        isSavingImage = true
        Task {
            if let error = await account.saveCard(saved.id, details: updated) {
                errorMessage = error
            }
            isSavingImage = false
        }
    }

    private func apply(theme: CardTheme, accent: String) {
        guard theme != details.theme || accent != details.accentColor else { return }
        errorMessage = nil
        Task {
            if let error = await account.updateDesign(of: cardID, theme: theme, accentColor: accent) {
                errorMessage = error
            }
        }
    }
}
