import SwiftUI

@main
struct TapcardApp: App {
    @State private var account = AccountStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(account)
                .tint(Color(hex: Constants.accentHex))
        }
    }
}
