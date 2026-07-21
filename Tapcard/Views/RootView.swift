import SwiftUI

/// Top-level router — welcome/auth until signed in, then the five-tab app
/// (mirrors the Android navigation: Cards, Contacts, Planner, Analytics, Settings).
struct RootView: View {
    @Environment(AccountStore.self) private var account

    var body: some View {
        if account.isSignedIn {
            TabView {
                HomeView()
                    .tabItem { Label("Cards", systemImage: "person.crop.rectangle.stack") }
                ContactsView()
                    .tabItem { Label("Contacts", systemImage: "person.2") }
                PlannerView()
                    .tabItem { Label("Planner", systemImage: "checklist") }
                AnalyticsView()
                    .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .task { await account.refreshServerCards() }
        } else {
            WelcomeView()
        }
    }
}
