import SwiftUI
import AuthenticationServices

/// Sign-up / log-in form — a SwiftUI port of the website's auth card
/// (`auth-form.tsx` / `register-form.tsx`): a glass Surface on the lavender
/// grid backdrop, pill method tabs, labelled inputs, a gradient primary
/// button and outline social buttons underneath.
struct AuthView: View {
    enum Mode: String, Identifiable, Hashable {
        case signUp, logIn
        var id: String { rawValue }
    }

    @State private var mode: Mode

    init(mode: Mode) {
        _mode = State(initialValue: mode)
    }

    @Environment(AccountStore.self) private var account

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var useCode = false
    @State private var codeSent = false
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                logo

                VStack(alignment: .leading, spacing: 20) {
                    header

                    if mode == .logIn {
                        methodTabs
                    }

                    fields

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    primaryButton

                    // Social sign-on sits under the form, mirroring the website
                    // — but not on the code-entry step, where the user is
                    // already mid-way through an email login.
                    if !(mode == .logIn && useCode && codeSent) {
                        orDivider
                        socialButtons
                    }

                    switchModeFooter
                }
                .padding(24)
                .surfaceCard()
            }
            .padding(20)
        }
        .tapcardBackground()
        .navigationTitle(mode == .signUp ? "Create account" : "Log in")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: mode)
    }

    // ─── Chrome ─────────────────────────────────────────────────────────────

    /// The web auth layout's brand mark: gradient tile + gradient wordmark.
    private var logo: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.gradientPrimary)
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            GradientText(text: "Tapcard", font: .system(size: 22, weight: .bold))
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .signUp ? "Create your account" : "Welcome back")
                .font(.title2.bold())
                .foregroundStyle(Theme.foreground)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private var subtitle: String {
        if mode == .signUp { return "Publish your digital card in minutes." }
        if useCode {
            return codeSent ? "Enter the 6-digit code we emailed you."
                            : "We'll email you a one-time code — no password needed."
        }
        return "Sign in to manage your cards and leads."
    }

    /// The web's two-segment pill switcher on a `surface-2` track.
    private var methodTabs: some View {
        HStack(spacing: 4) {
            methodTab("Password", icon: "key.fill", selected: !useCode) { setMethod(code: false) }
            methodTab("Email code", icon: "envelope.fill", selected: useCode) { setMethod(code: true) }
        }
        .padding(4)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func methodTab(_ title: String, icon: String, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? Theme.background : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(selected ? Theme.foreground : Theme.mutedForeground)
            .shadow(color: selected ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func setMethod(code useOtp: Bool) {
        useCode = useOtp
        codeSent = false
        code = ""
        errorMessage = nil
    }

    // ─── Fields ─────────────────────────────────────────────────────────────

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 14) {
            if mode == .signUp {
                labelled("Full name") {
                    authField("Jordan Avery", text: $name, contentType: .name)
                }
            }
            if !(useCode && codeSent) {
                labelled("Email") {
                    authField("you@company.com", text: $email,
                              contentType: .emailAddress, keyboard: .emailAddress)
                }
            }
            if mode == .signUp || (mode == .logIn && !useCode) {
                labelled("Password", trailing: mode == .logIn ? forgotPassword : nil) {
                    SecureField("••••••••", text: $password)
                        .textContentType(.password)
                        .modifier(InputChrome())
                }
            }
            if useCode && codeSent {
                labelled("6-digit code") {
                    authField("123456", text: $code, keyboard: .numberPad)
                }
                Button("Use a different email") {
                    codeSent = false
                    code = ""
                }
                .font(.footnote)
                .foregroundStyle(Theme.mutedForeground)
            }
        }
    }

    /// Web-style field label row, with an optional trailing link
    /// (e.g. "Forgot password?").
    private func labelled(_ label: String, trailing: AnyView? = nil,
                          @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.foreground)
                Spacer()
                if let trailing { trailing }
            }
            content()
        }
    }

    /// The web behaviour: there is no reset flow — the one-time code is the
    /// recovery path, so "Forgot password?" simply switches methods.
    private var forgotPassword: AnyView {
        AnyView(
            Button("Forgot password?") { setMethod(code: true) }
                .font(.caption)
                .foregroundStyle(Theme.primary)
        )
    }

    private func authField(_ placeholder: String, text: Binding<String>,
                           contentType: UITextContentType? = nil,
                           keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(contentType == .name ? .words : .never)
            .autocorrectionDisabled()
            .modifier(InputChrome())
    }

    // ─── Buttons ────────────────────────────────────────────────────────────

    private var primaryButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isBusy { ProgressView().tint(.white) }
                Text(buttonTitle)
            }
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isBusy)
    }

    private var buttonTitle: String {
        if mode == .signUp { return "Create account" }
        if useCode { return codeSent ? "Verify & sign in" : "Email OTP code" }
        return "Sign in"
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text("or continue with")
                .font(.footnote)
                .foregroundStyle(Theme.mutedForeground)
                .fixedSize()
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var socialButtons: some View {
        VStack(spacing: 12) {
            // Sign in with Apple is required alongside any third-party social
            // login (App Store Guideline 4.8), and by convention leads. The
            // outline style matches the web's social buttons on light.
            SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in
                // Handled by AppleAuthService so the token exchange, error
                // mapping and cancellation behaviour match the Google path.
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .allowsHitTesting(false)
            .overlay {
                Button { social(.apple) } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .disabled(isBusy)
            }

            if GoogleAuthService.isConfigured {
                Button { social(.google) } label: {
                    HStack(spacing: 10) {
                        GoogleGlyph().frame(width: 18, height: 18)
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(isBusy)
            }
        }
    }

    /// The web card's footer link, swapping between the two modes in place.
    private var switchModeFooter: some View {
        HStack(spacing: 4) {
            Text(mode == .signUp ? "Already have an account?" : "Don't have an account?")
                .foregroundStyle(Theme.mutedForeground)
            Button(mode == .signUp ? "Log in" : "Create one free") {
                mode = mode == .signUp ? .logIn : .signUp
                errorMessage = nil
            }
            .fontWeight(.medium)
            .foregroundStyle(Theme.primary)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    // ─── Actions ────────────────────────────────────────────────────────────

    private func submit() {
        errorMessage = nil
        let e = email.trimmed.lowercased()

        if mode == .signUp {
            guard !name.trimmed.isEmpty else { return fail("Enter your name.") }
            guard e.isValidEmail else { return fail("Enter a valid email address.") }
            guard password.count >= 6 else { return fail("Use a password of at least 6 characters.") }
            run { try await TapcardAPI.register(name: name, email: e, password: password) }
            return
        }
        if useCode {
            if codeSent {
                guard code.trimmed.count >= 4 else { return fail("Enter the code from your email.") }
                run { try await TapcardAPI.verifyOtp(email: e, code: code, name: nil) }
            } else {
                guard e.isValidEmail else { return fail("Enter a valid email address.") }
                isBusy = true
                Task {
                    do {
                        _ = try await TapcardAPI.requestOtp(email: e)
                        codeSent = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isBusy = false
                }
            }
            return
        }
        guard e.isValidEmail else { return fail("Enter a valid email address.") }
        guard !password.isEmpty else { return fail("Enter your password.") }
        run { try await TapcardAPI.login(email: e, password: password) }
    }

    /// Which social provider a sign-in run belongs to — decides both the picker
    /// to present and the endpoint that exchanges its token.
    private enum SocialProvider {
        case apple, google

        @MainActor
        func authenticate() async -> SocialSignInOutcome {
            switch self {
            case .apple: await AppleAuthService.signIn()
            case .google: await GoogleAuthService.signIn()
            }
        }

        func exchange(token: String, name: String?) async throws -> AuthResult {
            switch self {
            case .apple: try await TapcardAPI.appleSignIn(identityToken: token, name: name)
            case .google: try await TapcardAPI.googleSignIn(idToken: token, name: name)
            }
        }
    }

    /// Drives a social provider then exchanges its token for a session. A
    /// cancelled picker leaves the form untouched.
    private func social(_ provider: SocialProvider) {
        errorMessage = nil
        isBusy = true
        Task {
            switch await provider.authenticate() {
            case .cancelled:
                break
            case .failure(let message):
                errorMessage = message
            case .success(let token, let name):
                do {
                    account.startSession(try await provider.exchange(token: token, name: name))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            isBusy = false
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
    }

    private func run(_ op: @escaping @Sendable () async throws -> AuthResult) {
        isBusy = true
        Task {
            do {
                let result = try await op()
                account.startSession(result)
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }
}

/// The web `Input` chrome: white surface, hairline border, `radius-md` corners.
private struct InputChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Theme.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
