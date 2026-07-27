import SwiftUI

/// First-run landing — mirrors the Android welcome screen: brand hero plus
/// "Create account" / "Log in" entry points into `AuthView`.
struct WelcomeView: View {
    @Environment(AccountStore.self) private var account
    @State private var authMode: AuthView.Mode?

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(LinearGradient(colors: [accent, accent.opacity(0.65)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.crop.rectangle.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 24)

                Text("Tapcard")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Your business card, reimagined")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 14) {
                    featureRow("camera.viewfinder", "Scan paper cards with on-device OCR")
                    featureRow("qrcode", "Share your card by QR code in seconds")
                    featureRow("person.2.fill", "Keep leads and contacts in one place")
                    featureRow("chart.bar.fill", "See views, taps and leads for your card")
                }
                .padding(.top, 32)
                .padding(.horizontal, 8)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        authMode = .signUp
                    } label: {
                        Text("Create account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                    Button {
                        authMode = .logIn
                    } label: {
                        Text("Log in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 8)
            }
            .padding(24)
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
                .foregroundStyle(accent)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}
