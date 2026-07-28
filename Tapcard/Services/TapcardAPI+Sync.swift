import Foundation

/// Signed-in identity returned by login / register / OTP verify.
struct AuthResult: Sendable {
    let token: String
    let name: String?
    let email: String?
}

/// Token-authenticated endpoints — the iOS twin of the Android `TapcardApi`:
/// mobile auth (login/register/OTP → bearer token) plus two-way sync of
/// contacts, leads, tasks, appointments and the analytics summary.
extension TapcardAPI {

    // ─── HTTP core ──────────────────────────────────────────────────────────

    private static func request(
        _ method: String,
        _ path: String,
        token: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> Data {
        let url = Constants.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200...299).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(WireError.self, from: data), let msg = err.error {
                throw APIError.server(msg)
            }
            throw APIError.server("Server error (\(http.statusCode))")
        }
        return data
    }

    private struct WireError: Codable { let error: String? }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.invalidResponse }
    }

    // ─── Auth ───────────────────────────────────────────────────────────────

    private struct AuthUser: Codable { let id: String?; let name: String?; let email: String? }
    private struct AuthWire: Codable { let token: String?; let user: AuthUser? }
    private struct OtpRequestWire: Codable { let ok: Bool?; let isNewAccount: Bool? }

    private static func authResult(from data: Data) throws -> AuthResult {
        let wire = try decode(AuthWire.self, from: data)
        guard let token = wire.token else { throw APIError.server("No token returned") }
        return AuthResult(token: token, name: wire.user?.name, email: wire.user?.email)
    }

    static func login(email: String, password: String) async throws -> AuthResult {
        let data = try await request("POST", "/api/mobile/login",
                                     body: ["email": email.trimmed, "password": password])
        return try authResult(from: data)
    }

    static func register(name: String, email: String, password: String) async throws -> AuthResult {
        let data = try await request("POST", "/api/mobile/register",
                                     body: ["name": name.trimmed, "email": email.trimmed, "password": password])
        return try authResult(from: data)
    }

    /// Requests a 6-digit code by email. Returns whether this email is new.
    static func requestOtp(email: String) async throws -> Bool {
        let data = try await request("POST", "/api/mobile/otp/request", body: ["email": email.trimmed])
        return try decode(OtpRequestWire.self, from: data).isNewAccount ?? false
    }

    /// Verifies the emailed code; creates the account if new. Returns a token.
    static func verifyOtp(email: String, code: String, name: String?) async throws -> AuthResult {
        var body: [String: Any] = ["email": email.trimmed, "code": code.trimmed]
        if let name, !name.trimmed.isEmpty { body["name"] = name.trimmed }
        let data = try await request("POST", "/api/mobile/otp/verify", body: body)
        return try authResult(from: data)
    }

    /// Exchanges a Google **ID token** (from the native account picker) for a
    /// Tapcard bearer token. The backend verifies the token with Google, then
    /// finds or creates the account and returns the same shape as login/OTP.
    static func googleSignIn(idToken: String, name: String?) async throws -> AuthResult {
        var body: [String: Any] = ["idToken": idToken]
        if let name, !name.trimmed.isEmpty { body["name"] = name.trimmed }
        let data = try await request("POST", "/api/mobile/oauth/google", body: body)
        return try authResult(from: data)
    }

    /// Exchanges an Apple **identity token** for a Tapcard bearer token. `name`
    /// is only ever available on the user's first authorization, so it is sent
    /// when present and omitted thereafter.
    static func appleSignIn(identityToken: String, name: String?) async throws -> AuthResult {
        var body: [String: Any] = ["identityToken": identityToken]
        if let name, !name.trimmed.isEmpty { body["name"] = name.trimmed }
        let data = try await request("POST", "/api/mobile/oauth/apple", body: body)
        return try authResult(from: data)
    }

    /// Permanently deletes the signed-in account (token proves ownership).
    static func deleteAccount(token: String, email: String) async throws {
        _ = try await request("POST", "/api/mobile/delete-account", token: token,
                              body: ["email": email.trimmed])
    }

    // ─── Card sync ──────────────────────────────────────────────────────────

    struct ServerCard: Codable, Identifiable, Equatable, Sendable {
        var id: String = ""
        var slug: String?
        var fullName: String = ""
        var jobTitle: String?
        var company: String?
        var email: String?
        var mobile: String?
        var officePhone: String?
        var website: String?
        var address: String?
        var linkedin: String?
        var twitter: String?
        var theme: String?
        var accentColor: String?

        var publicURL: String {
            "\(Constants.apiBaseURL.absoluteString)/c/\(slug ?? id)"
        }

        /// The server card as the app's editable model — powers the native
        /// preview and the in-app editor.
        var asBusinessCard: BusinessCard {
            var card = BusinessCard()
            card.fullName = fullName
            card.jobTitle = jobTitle ?? ""
            card.company = company ?? ""
            card.email = email ?? ""
            card.mobile = mobile ?? ""
            card.officePhone = officePhone ?? ""
            card.website = website ?? ""
            card.address = address ?? ""
            card.linkedin = linkedin ?? ""
            card.twitter = twitter ?? ""
            card.theme = CardTheme(rawValue: theme ?? "") ?? .modern
            card.accentColor = accentColor ?? Constants.accentHex
            return card
        }
    }

    private struct CardsWire: Codable { let cards: [ServerCard]? }

    static func fetchCards(token: String) async throws -> [ServerCard] {
        let data = try await request("GET", "/api/mobile/cards", token: token)
        return try decode(CardsWire.self, from: data).cards ?? []
    }

    /// Update a published card in place (PATCH). Empty strings are sent
    /// deliberately — that's how a field is cleared on the server.
    static func updateCard(token: String, id: String, card: BusinessCard) async throws {
        // The backend validates website with a strict URL check — prefix bare
        // domains ("tertiaryinfotech.com") so a hand-typed edit doesn't 400.
        var website = card.website.trimmed
        if !website.isEmpty, !website.lowercased().hasPrefix("http") {
            website = "https://" + website
        }
        let body: [String: Any] = [
            "fullName": card.fullName.trimmed,
            "jobTitle": card.jobTitle.trimmed,
            "company": card.company.trimmed,
            "email": card.email.trimmed.lowercased(),
            "mobile": card.mobile.trimmed,
            "officePhone": card.officePhone.trimmed,
            "website": website,
            "address": card.address.trimmed,
            "linkedin": card.linkedin.trimmed,
            "twitter": card.twitter.trimmed,
            "theme": card.theme.rawValue,
            "accentColor": card.accentColor,
        ]
        _ = try await request("PATCH", "/api/mobile/cards/\(id)", token: token, body: body)
    }

    // ─── Contacts sync ──────────────────────────────────────────────────────

    private struct ContactsWire: Codable { let contacts: [WireContact]? }
    private struct ContactWire: Codable { let contact: WireContact? }

    private struct WireContact: Codable {
        let id: String
        let name: String?
        let company: String?
        let position: String?
        let email: String?
        let phone: String?
        let whatsapp: String?
        let address: String?
        let notes: String?
        let tags: String?

        var model: Contact {
            Contact(id: id, name: name ?? "", company: company ?? "", position: position ?? "",
                    email: email ?? "", phone: phone ?? "", whatsapp: whatsapp ?? "",
                    address: address ?? "", notes: notes ?? "", tags: tags ?? "")
        }
    }

    private static func contactBody(_ c: Contact) -> [String: Any] {
        var body: [String: Any] = ["name": c.name.trimmed]
        func put(_ key: String, _ value: String) { if !value.trimmed.isEmpty { body[key] = value.trimmed } }
        put("company", c.company); put("position", c.position); put("email", c.email)
        put("phone", c.phone); put("whatsapp", c.whatsapp); put("address", c.address)
        put("notes", c.notes); put("tags", c.tags)
        return body
    }

    static func fetchContacts(token: String) async throws -> [Contact] {
        let data = try await request("GET", "/api/mobile/contacts", token: token)
        return (try decode(ContactsWire.self, from: data).contacts ?? []).map(\.model)
    }

    static func createContact(token: String, _ contact: Contact) async throws -> Contact {
        let data = try await request("POST", "/api/mobile/contacts", token: token, body: contactBody(contact))
        guard let wire = try decode(ContactWire.self, from: data).contact else { throw APIError.invalidResponse }
        return wire.model
    }

    static func updateContact(token: String, _ contact: Contact) async throws -> Contact {
        let data = try await request("PATCH", "/api/mobile/contacts/\(contact.id)", token: token, body: contactBody(contact))
        guard let wire = try decode(ContactWire.self, from: data).contact else { throw APIError.invalidResponse }
        return wire.model
    }

    static func deleteContact(token: String, id: String) async throws {
        _ = try await request("DELETE", "/api/mobile/contacts/\(id)", token: token)
    }

    // ─── Leads inbox ────────────────────────────────────────────────────────

    private struct LeadsWire: Codable { let leads: [WireLead]? }

    private struct WireLead: Codable {
        let id: String
        let name: String?
        let email: String?
        let phone: String?
        let company: String?
        let message: String?
        let source: String?
        let createdAt: String?

        var model: Lead {
            Lead(id: id, name: name ?? "", email: email ?? "", phone: phone ?? "",
                 company: company ?? "", message: message ?? "",
                 source: source ?? "card", createdAt: createdAt ?? "")
        }
    }

    static func fetchLeads(token: String) async throws -> [Lead] {
        let data = try await request("GET", "/api/mobile/leads", token: token)
        return (try decode(LeadsWire.self, from: data).leads ?? []).map(\.model)
    }

    static func deleteLead(token: String, id: String) async throws {
        _ = try await request("DELETE", "/api/mobile/leads/\(id)", token: token)
    }

    // ─── Planner: tasks ─────────────────────────────────────────────────────

    private struct TasksWire: Codable { let tasks: [CRMTask]? }
    private struct TaskWire: Codable { let task: CRMTask? }

    static func fetchTasks(token: String) async throws -> [CRMTask] {
        let data = try await request("GET", "/api/mobile/tasks", token: token)
        return try decode(TasksWire.self, from: data).tasks ?? []
    }

    static func createTask(token: String, title: String, type: String, dueAt: String?) async throws -> CRMTask {
        var body: [String: Any] = ["title": title.trimmed, "type": type]
        if let dueAt, !dueAt.isEmpty { body["dueAt"] = dueAt }
        let data = try await request("POST", "/api/mobile/tasks", token: token, body: body)
        guard let task = try decode(TaskWire.self, from: data).task else { throw APIError.invalidResponse }
        return task
    }

    static func setTaskStatus(token: String, id: String, status: String) async throws -> CRMTask {
        let data = try await request("PATCH", "/api/mobile/tasks/\(id)", token: token, body: ["status": status])
        guard let task = try decode(TaskWire.self, from: data).task else { throw APIError.invalidResponse }
        return task
    }

    static func updateTask(token: String, id: String, title: String, type: String, dueAt: String?) async throws -> CRMTask {
        let body: [String: Any] = ["title": title.trimmed, "type": type, "dueAt": dueAt as Any]
        let data = try await request("PATCH", "/api/mobile/tasks/\(id)", token: token, body: body)
        guard let task = try decode(TaskWire.self, from: data).task else { throw APIError.invalidResponse }
        return task
    }

    static func deleteTask(token: String, id: String) async throws {
        _ = try await request("DELETE", "/api/mobile/tasks/\(id)", token: token)
    }

    // ─── Planner: appointments ──────────────────────────────────────────────

    private struct AppointmentsWire: Codable { let appointments: [Appointment]? }
    private struct AppointmentWire: Codable { let appointment: Appointment? }

    private static func appointmentBody(name: String, email: String?, startAt: String,
                                        endAt: String, notes: String?) -> [String: Any] {
        var body: [String: Any] = ["name": name.trimmed, "startAt": startAt, "endAt": endAt]
        if let email, !email.trimmed.isEmpty { body["email"] = email.trimmed }
        if let notes, !notes.trimmed.isEmpty { body["notes"] = notes.trimmed }
        return body
    }

    static func fetchAppointments(token: String) async throws -> [Appointment] {
        let data = try await request("GET", "/api/mobile/appointments", token: token)
        return try decode(AppointmentsWire.self, from: data).appointments ?? []
    }

    static func createAppointment(token: String, name: String, email: String?, startAt: String,
                                  endAt: String, notes: String?) async throws -> Appointment {
        let data = try await request("POST", "/api/mobile/appointments", token: token,
                                     body: appointmentBody(name: name, email: email, startAt: startAt, endAt: endAt, notes: notes))
        guard let appt = try decode(AppointmentWire.self, from: data).appointment else { throw APIError.invalidResponse }
        return appt
    }

    static func updateAppointment(token: String, id: String, name: String, email: String?,
                                  startAt: String, endAt: String, notes: String?) async throws -> Appointment {
        let data = try await request("PATCH", "/api/mobile/appointments/\(id)", token: token,
                                     body: appointmentBody(name: name, email: email, startAt: startAt, endAt: endAt, notes: notes))
        guard let appt = try decode(AppointmentWire.self, from: data).appointment else { throw APIError.invalidResponse }
        return appt
    }

    static func deleteAppointment(token: String, id: String) async throws {
        _ = try await request("DELETE", "/api/mobile/appointments/\(id)", token: token)
    }

    // ─── Analytics summary ──────────────────────────────────────────────────

    static func fetchAnalytics(token: String) async throws -> AnalyticsSummary {
        let data = try await request("GET", "/api/mobile/analytics", token: token)
        return try decode(AnalyticsSummary.self, from: data)
    }
}
