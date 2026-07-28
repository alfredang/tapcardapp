import SwiftUI

@main
struct TapcardApp: App {
    @State private var account = AccountStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(account)
                .tint(Theme.primary)
                // The website is light-by-default (dark is an opt-in toggle);
                // lock the app to light so both surfaces match.
                .preferredColorScheme(.light)
        }
    }
}
