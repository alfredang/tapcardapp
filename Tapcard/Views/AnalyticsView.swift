import SwiftUI

/// Card performance — mirrors the Android analytics screen: headline totals,
/// last-30-day views, per-event breakdown and per-card rows.
struct AnalyticsView: View {
    @Environment(AccountStore.self) private var account

    @State private var summary: AnalyticsSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let summary {
                        totalsRow(summary)
                        last30(summary)
                        if !summary.cards.isEmpty { cardsSection(summary) }
                        if !summary.byType.isEmpty { eventsSection(summary) }
                    } else if isLoading {
                        ProgressView().padding(.top, 80)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar").font(.largeTitle).foregroundStyle(.secondary)
                            Text("No analytics yet").font(.headline)
                            Text(errorMessage ?? "Share your card to start collecting views, taps and leads.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 80)
                        .padding(.horizontal, 40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func totalsRow(_ summary: AnalyticsSummary) -> some View {
        HStack(spacing: 12) {
            statCard("eye.fill", "Views", summary.totals.views)
            statCard("hand.tap.fill", "Taps", summary.totals.taps)
            statCard("person.fill.badge.plus", "Leads", summary.totals.leads)
        }
    }

    private func statCard(_ icon: String, _ label: String, _ value: Int) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(accent)
            Text("\(value)").font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func last30(_ summary: AnalyticsSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Views · last 30 days").font(.subheadline).foregroundStyle(.secondary)
                Text("\(summary.last30dViews)").font(.title.bold())
            }
            Spacer()
            Image(systemName: "calendar").font(.title2).foregroundStyle(accent)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cardsSection(_ summary: AnalyticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By card").font(.headline)
            ForEach(summary.cards) { card in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name.isEmpty ? "/c/\(card.slug)" : card.name).font(.subheadline.weight(.semibold))
                        Text("/c/\(card.slug)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(card.views)", systemImage: "eye").font(.caption)
                    Label("\(card.taps)", systemImage: "hand.tap").font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventsSection(_ summary: AnalyticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By event").font(.headline)
            ForEach(summary.byType.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                HStack {
                    Text(CRMTask.typeLabel(key))
                    Spacer()
                    Text("\(value)").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reload() async {
        guard let token = account.token else { return }
        isLoading = true
        do {
            summary = try await TapcardAPI.fetchAnalytics(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
