import Foundation
import FoundationModels

/// Apple Intelligence pass over the OCR output. The heuristic `ContactParser`
/// gets line order and labels wrong on busy cards (e.g. picking the company
/// "Tertiary" as the person's name instead of "Dr. Alfred Ang"); the on-device
/// foundation model reads the card as a whole and reliably separates the
/// person from the brand. Runs entirely on-device — no card text leaves the
/// phone. Only available on Apple Intelligence hardware with iOS 26+; callers
/// fall back to `ContactParser` otherwise.
@available(iOS 26.0, *)
enum AIContactExtractor {

    @Generable
    struct ExtractedContact {
        @Guide(description: "The PERSON's full name, including honorifics (e.g. \"Dr. Alfred Ang\"). Never the company, brand or product name. Empty if no person is named.")
        var fullName: String
        @Guide(description: "The person's job title(s), e.g. \"Managing Director\".")
        var jobTitle: String
        @Guide(description: "The company or organisation name.")
        var company: String
        @Guide(description: "Email address, empty if absent.")
        var email: String
        @Guide(description: "Mobile phone number, empty if absent.")
        var mobile: String
        @Guide(description: "Office/landline phone number, empty if absent.")
        var officePhone: String
        @Guide(description: "Website URL, empty if absent.")
        var website: String
        @Guide(description: "Postal address only — street, unit, city, postcode. No slogans, certifications or contact details.")
        var address: String
    }

    /// True when the on-device model is ready (Apple Intelligence enabled,
    /// model downloaded).
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    static func extract(fromLines lines: [String]) async throws -> ExtractedContact {
        let session = LanguageModelSession(instructions: """
            You extract contact fields from business-card text produced by OCR. \
            The lines may be out of order and mixed with slogans, certification \
            lists and other noise. Distinguish carefully between the PERSON \
            (a human name, often near a job title or honorific like Dr.) and \
            the COMPANY (a brand, often the largest text or part of a logo). \
            Copy values verbatim from the text; leave a field empty when the \
            card does not contain it.
            """)
        let prompt = "Business card text:\n" + lines.joined(separator: "\n")
        let response = try await session.respond(to: prompt, generating: ExtractedContact.self)
        return response.content
    }
}

@available(iOS 26.0, *)
extension BusinessCard {
    /// Overlay the AI extraction on the heuristic parse — a non-empty AI field
    /// wins, anything the model left blank keeps the heuristic value.
    mutating func refine(with ai: AIContactExtractor.ExtractedContact) {
        func pick(_ new: String, _ old: String) -> String {
            new.trimmed.isEmpty ? old : new.trimmed
        }
        fullName = pick(ai.fullName, fullName)
        jobTitle = pick(ai.jobTitle, jobTitle)
        company = pick(ai.company, company)
        email = pick(ai.email, email)
        mobile = pick(ai.mobile, mobile)
        officePhone = pick(ai.officePhone, officePhone)
        website = pick(ai.website, website)
        address = pick(ai.address, address)
    }
}
