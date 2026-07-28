import SwiftUI

/// Landing screen: a hero call-to-action to scan a business card, plus a list
/// of digital cards already created on this device.
struct HomeView: View {
    @Environment(AccountStore.self) private var account
    @State private var showingScan = false
    @State private var editingCard: SavedCard?
    @State private var pendingDelete: SavedCard?
    @State private var deleteError: String?

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    // With a published card, your QR leads the screen — the
                    // fastest way to get scanned in person (Blinq-style).
                    if let first = account.cards.first {
                        MyQRPanel(card: first)
                    }
                    hero
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if account.cards.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    myCardsSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
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
            .navigationTitle("Tapcard")
            .toolbar {
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
            .onAppear {
                if DemoSupport.startInReview || DemoSupport.startInDone { showingScan = true }
            }
        }
    }

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

    private var myCardsSection: some View {
        Section("My digital cards") {
            ForEach(account.cards) { card in
                NavigationLink {
                    SavedCardDetailView(card: card)
                } label: {
                    SavedCardRow(card: card, accent: accent)
                }
                // Swipe left: Edit, or Delete (with confirmation).
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDelete = card
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingCard = card
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Theme.primary)
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
