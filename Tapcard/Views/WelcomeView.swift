import SwiftUI

/// First-run landing — a native take on the website's hero: brand mark,
/// "Replace paper cards with smart digital cards" headline with gradient
/// words, feature rows, and a gradient "Create free card" CTA.
struct WelcomeView: View {
    @Environment(AccountStore.self) private var account
    @State private var authMode: AuthView.Mode?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Brand mark — gradient tile + sparkles, as on the site header.
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.gradientPrimary)
                        .frame(width: 104, height: 104)
                        .shadow(color: Theme.primary.opacity(0.35), radius: 24, y: 12)
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 24)

                // The hero headline, with the site's gradient-tinted words.
                (Text("Replace paper cards with ")
                    .foregroundStyle(Theme.foreground)
                 + Text("smart ")
                    .foregroundStyle(Theme.primary)
                 + Text("digital cards")
                    .foregroundStyle(Theme.accent))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Create, share, capture leads and publish a professional card in under two minutes.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    featureRow("camera.viewfinder", "Scan paper cards with on-device OCR")
                    featureRow("qrcode", "Share your card by QR code in seconds")
                    featureRow("person.2.fill", "Keep leads and contacts in one place")
                    featureRow("chart.bar.fill", "See views, taps and leads for your card")
                }
                .padding(20)
                .surfaceCard()
                .padding(.top, 28)

                Spacer()

                VStack(spacing: 12) {
                    Button("Create free card") { authMode = .signUp }
                        .buttonStyle(GradientButtonStyle())

                    Button("Log in") { authMode = .logIn }
                        .buttonStyle(OutlineButtonStyle())
                }
                .padding(.bottom, 8)
            }
            .padding(24)
            .tapcardBackground()
            .navigationDestination(item: $authMode) { mode in
                AuthView(mode: mode)
            }
            .onAppear {
                // Screenshot hook — no effect in a normal launch.
                if authMode == nil, let demo = DemoSupport.startInAuth { authMode = demo }
            }
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
            Spacer(minLength: 0)
        }
    }
}
