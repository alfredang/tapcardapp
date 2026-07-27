import SwiftUI
import AuthenticationServices

/// Sign-up / log-in form — mirrors the Android auth screen. "Create account"
/// takes name + email + password. "Log in" offers two ways: email + password,
/// or a one-time email code — switchable via a picker, mirroring the website.
struct AuthView: View {
    enum Mode: String, Identifiable, Hashable {
        case signUp, logIn
        var id: String { rawValue }
    }

    let mode: Mode

    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var colorScheme

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var useCode = false
    @State private var codeSent = false
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var accent: Color { Color(hex: Constants.accentHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if mode == .logIn {
                    Picker("Method", selection: $useCode) {
                        Text("Password").tag(false)
                        Text("Email code").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: useCode) { codeSent = false; code = ""; errorMessage = nil }
                }

                fields

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                primaryButton

                // Social sign-on sits under the form, mirroring the website and
                // the Android app — but not on the code-entry step, where the
                // user is already mid-way through an email login.
                if !(mode == .logIn && useCode && codeSent) {
                    orDivider
                    socialButtons
                }
            }
            .padding(24)
        }
        .navigationTitle(mode == .signUp ? "Create account" : "Log in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .signUp ? "Create your account" : "Welcome back")
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        if mode == .signUp { return "Sign up with your email and a password." }
        if useCode {
            return codeSent ? "Enter the 6-digit code we emailed you."
                            : "We'll email you a one-time code — no password needed."
        }
        return "Log in with your email and password."
    }

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                authField("Full name", text: $name, contentType: .name)
            }
            if !(useCode && codeSent) {
                authField("Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
            }
            if mode == .signUp || (mode == .logIn && !useCode) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if useCode && codeSent {
                authField("6-digit code", text: $code, keyboard: .numberPad)
                Button("Use a different email") {
                    codeSent = false
                    code = ""
                }
                .font(.footnote)
            }
        }
    }

    private func authField(_ label: String, text: Binding<String>,
                           contentType: UITextContentType? = nil,
                           keyboard: UIKeyboardType = .default) -> some View {
        TextField(label, text: text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(contentType == .name ? .words : .never)
            .autocorrectionDisabled()
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var primaryButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isBusy { ProgressView().tint(.white) }
                Text(buttonTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .disabled(isBusy)
    }

    private var buttonTitle: String {
        if mode == .signUp { return "Create account" }
        if useCode { return codeSent ? "Verify code" : "Send code" }
        return "Log in"
    }

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

    // ─── Social sign-on ─────────────────────────────────────────────────────

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.separator).frame(height: 1)
            Text("or").font(.footnote).foregroundStyle(.secondary)
            Rectangle().fill(.separator).frame(height: 1)
        }
    }

    @ViewBuilder
    private var socialButtons: some View {
        VStack(spacing: 12) {
            // Sign in with Apple is required alongside any third-party social
            // login (App Store Guideline 4.8), and by convention leads.
            SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in
                // Handled by AppleAuthService so the token exchange, error
                // mapping and cancellation behaviour match the Google path.
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.separator, lineWidth: 1)
                    )
                }
                .disabled(isBusy)
            }
        }
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
