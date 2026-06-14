import SwiftUI
import Observation
import UIKit

/// Drives the scan → review → publish flow.
@MainActor
@Observable
final class ScanViewModel {
    enum Stage: Equatable {
        case idle          // ready to scan
        case recognizing   // running OCR
        case review        // editable extracted fields
        case submitting    // posting to backend
        case done(OnboardResult)
    }

    struct OnboardResult: Equatable {
        let card: PublishedCard
        let isNewAccount: Bool
        let password: String?
    }

    var stage: Stage = .idle
    var card = BusinessCard()
    var errorMessage: String?

    init() {
        // Screenshot/demo seam — inert unless the launch env var is set.
        if DemoSupport.startInDone {
            card = DemoSupport.demoCard
            stage = .done(OnboardResult(
                card: PublishedCard(id: "demo", slug: "jordan-avery",
                                    url: "https://tapcard.tertiaryinfotech.com/c/jordan-avery"),
                isNewAccount: true, password: "k3y9p2m7"))
        } else if DemoSupport.startInReview {
            card = DemoSupport.demoCard
            stage = .review
        }
    }

    /// OCR a freshly scanned card image and populate the editable fields.
    func handleScanned(image: UIImage) async {
        stage = .recognizing
        errorMessage = nil
        guard let cgImage = image.cgImage else {
            errorMessage = "Couldn't read that image. Try again."
            stage = .idle
            return
        }
        do {
            let lines = try await OCRService.recognizeLines(in: cgImage)
            card = ContactParser.parse(lines: lines)
            stage = .review
        } catch {
            errorMessage = "Text recognition failed. You can enter details manually."
            card = BusinessCard()
            stage = .review
        }
    }

    /// Skip scanning and enter details by hand.
    func startManualEntry() {
        card = BusinessCard()
        stage = .review
    }

    /// Publish the card + set up the account on the backend.
    func submit(into account: AccountStore) async {
        guard card.isValid else {
            errorMessage = "A name and a valid email are required."
            return
        }
        stage = .submitting
        errorMessage = nil
        if DemoSupport.fakeSubmit {
            let demo = OnboardResponse(
                ok: true, isNewAccount: true, email: card.email.lowercased(),
                password: "k3y9p2m7",
                card: PublishedCard(id: "demo", slug: "jordan-avery",
                                    url: "https://tapcard.tertiaryinfotech.com/c/jordan-avery"))
            account.record(demo, card: card)
            stage = .done(OnboardResult(card: demo.card, isNewAccount: true, password: demo.password))
            return
        }
        do {
            let response = try await TapcardAPI.onboard(card)
            account.record(response, card: card)
            stage = .done(OnboardResult(
                card: response.card,
                isNewAccount: response.isNewAccount,
                password: response.password
            ))
        } catch {
            errorMessage = error.localizedDescription
            stage = .review
        }
    }

    func reset() {
        card = BusinessCard()
        errorMessage = nil
        stage = .idle
    }
}
