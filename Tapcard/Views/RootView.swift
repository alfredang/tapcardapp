import SwiftUI

/// Top-level router — welcome/auth until signed in, then the five-tab app
/// (mirrors the Android navigation: Cards, Contacts, Planner, Analytics, Settings).
struct RootView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlockError: String?

    var body: some View {
        Group {
        if account.needsBiometricUnlock {
            VStack(spacing: 24) {
                Image(systemName: BiometricAuthService.label == "Touch ID" ? "touchid" : "faceid")
                    .font(.system(size: 64)).foregroundStyle(Theme.primary)
                Text("Welcome back").font(.largeTitle.bold())
                Text("Unlock your Tapcard account with \(BiometricAuthService.label).")
                    .foregroundStyle(Theme.mutedForeground).multilineTextAlignment(.center)
                if let unlockError { Text(unlockError).font(.footnote).foregroundStyle(.red) }
                Button {
                    Task {
                        unlockError = nil
                        do { try await account.unlockSession() }
                        catch { unlockError = error.localizedDescription }
                    }
                } label: {
                    if account.isUnlocking { ProgressView() }
                    else { Text("Log in with \(BiometricAuthService.label)") }
                }.buttonStyle(GradientButtonStyle()).disabled(account.isUnlocking)
                Button("Use another login") { account.signOut() }
                    .buttonStyle(OutlineButtonStyle())
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).tapcardBackground()
        } else if account.isSignedIn {
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
            .task {
                await account.refreshServerCards()
                await account.refreshPreferences()
            }
        } else {
            WelcomeView()
        }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { account.lockSession() }
        }
        // Every card view builds WhatsApp / tel: links with the account's
        // default country code (Settings → Sharing).
        .environment(\.dialCountryCode, account.preferences.countryCode)
    }
}
