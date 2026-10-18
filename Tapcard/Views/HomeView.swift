import SwiftUI

/// Landing screen. Two states, driven by whether the account has a card yet:
///
/// - **Card published** — your identity leads: photo, name, designation, job
///   title and contact rows, with the QR beneath it and Share / Edit in the
///   thumb zone. Scanning a paper card moves to a secondary toolbar action;
///   the big "scan a business card" pitch is gone once it's been answered.
/// - **No card yet** — the scan hero and its call to action, as before.
struct HomeView: View {
    @Environment(AccountStore.self) private var account
    @State private var showingScan = false
    @State private var editingCard: SavedCard?
    @State private var pendingDelete: SavedCard?
    @State private var deleteError: String?
    @State private var showShare = false

    private var accent: Color { Color(hex: Constants.accentHex) }

    /// The card that represents the user on this screen.
    private var primaryCard: SavedCard? { account.cards.first }

    var body: some View {
        NavigationStack {
            Group {
                if let card = primaryCard {
                    cardPage(for: card)
                } else {
                    onboardingList
                }
            }
            .navigationDestination(item: $editingCard) { card in
                EditCardView(saved: card)
            }
            .confirmationDialog(
                "Delete this card?",
                isPresented: Binding(get: { pendingDelete != nil },
                                     set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete card", role: .destructive) {
                    guard let card = pendingDelete else { return }
                    pendingDelete = nil
                    Task { deleteError = await account.deleteCard(card) }
                }
            } message: {
                Text("The public link stops working immediately. This can't be undone.")
            }
            .alert("Couldn't delete card", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
            // No title: the card is the header. The toolbar buttons float
            // over its banner.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // With a card on file, scanning is a secondary tool — kept
                // reachable for adding another card, out of the main flow.
                if primaryCard != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingScan = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }
                        .accessibilityLabel("Scan a business card")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingScan) {
                ScanFlowView()
            }
            .sheet(isPresented: $showShare) {
                if let card = primaryCard {
                    ShareSheet(items: shareItems(for: card))
                }
            }
            .onAppear {
                if DemoSupport.startInReview || DemoSupport.startInDone { showingScan = true }
            }
        }
    }

    // ─── Signed-in identity ─────────────────────────────────────────────────

    /// The card fills the screen: edge to edge, its banner running up under
    /// the status and navigation bars, with the QR and actions below it.
    private func cardPage(for card: SavedCard) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    identityHeader(for: card)
                        .fullBleed(top: proxy.safeAreaInsets.top)
                    Group {
                        MyQRPanel(card: card)
                        primaryActions(for: card)
                        if account.cards.count > 1 {
                            otherCards
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(.container, edges: .top)
            // Pulling down past the top reveals more banner, not a gap.
            .background(alignment: .top) {
                CardDesignBanner(theme: details(of: card).theme)
                    .frame(height: proxy.size.height / 2)
                    .ignoresSafeArea()
            }
            .background(Theme.background)
        }
    }

    /// Before the first card: the scan pitch and an empty state.
    private var onboardingList: some View {
        List {
            hero
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            emptyState
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    /// The user's own card, rendered exactly as visitors see it.
    private func identityHeader(for card: SavedCard) -> CardPreviewView {
        CardPreviewView(card: details(of: card), ctaTitle: "Share my card") {
            showShare = true
        }
    }

    /// Share / Edit, side by side in the thumb zone.
    private func primaryActions(for card: SavedCard) -> some View {
        HStack(spacing: 12) {
            Button {
                editingCard = card
            } label: {
                actionLabel("Edit", icon: "pencil")
            }
            .buttonStyle(OutlineButtonStyle())

            Button {
                showShare = true
            } label: {
                actionLabel("Share", icon: "square.and.arrow.up")
            }
            .buttonStyle(GradientButtonStyle())
        }
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
    }

    /// The full field set for a saved card, with a minimal fallback for cards
    /// persisted before `details` existed.
    private func details(of card: SavedCard) -> BusinessCard {
        card.details ?? {
            var c = BusinessCard()
            c.fullName = card.fullName
            c.company = card.company
            return c
        }()
    }

    private func shareItems(for card: SavedCard) -> [Any] {
        var items: [Any] = [URL(string: card.url) ?? card.url as Any]
        let prefs = account.preferences
        if let vcf = VCard.file(for: details(of: card), publicURL: card.url,
                                countryCode: prefs.countryCode) { items.append(vcf) }
        let preferred = CardQRTarget(card: card, mode: prefs.qrMode, preferences: prefs)
        let target = preferred.url != nil ? preferred : CardQRTarget(card: card, mode: .card, preferences: prefs)
        if let link = target.url,
           let qr = QRCodeImage.shareImage(payload: link, mode: target.mode) { items.append(qr) }
        return items
    }

    // ─── No card yet ────────────────────────────────────────────────────────

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, Color(hex: Constants.coralHex)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 46, weight: .semibold))
                    Text("Scan a paper business card")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("We'll read it, set up your account, and publish a shareable digital card in seconds.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .opacity(0.92)
                }
                .foregroundStyle(.white)
                .padding(28)
            }
            .frame(minHeight: 240)

            Button {
                showingScan = true
            } label: {
                Label("Scan business card", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
    }

    /// Additional cards beyond the one on show — the primary card already
    /// leads the screen, so it isn't repeated here.
    private var otherCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My other cards")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .padding(.top, 8)
            ForEach(account.cards.dropFirst()) { card in
                NavigationLink {
                    SavedCardDetailView(card: card)
                } label: {
                    SavedCardRow(card: card, accent: accent)
                }
                .buttonStyle(.plain)
                // Long-press: Edit, or Delete (with confirmation).
                .contextMenu {
                    Button {
                        editingCard = card
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        pendingDelete = card
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No cards yet")
                .font(.headline)
            Text("Scan your first business card to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
}

struct SavedCardRow: View {
    let card: SavedCard
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.15))
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.fullName).font(.headline)
                if !card.company.isEmpty {
                    Text(card.company).font(.subheadline).foregroundStyle(.secondary)
                }
                Text("/c/\(card.slug)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var initials: String {
        card.fullName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
