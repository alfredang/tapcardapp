import XCTest
import Vision
@testable import Tapcard

private func prefs(_ countryCode: String, whatsappQr: String = "") -> UserPreferences {
    var p = UserPreferences()
    p.countryCode = countryCode
    p.whatsappQr = whatsappQr
    return p
}

final class CardSharingTests: XCTestCase {
    func testScannedCardBecomesContact() {
        var card = BusinessCard()
        card.fullName = " Jane Tan "; card.jobTitle = "CTO"; card.company = "Acme"
        card.email = "jane@acme.sg"; card.mobile = "+65 9000 0000"; card.officePhone = "+65 6000 0000"
        card.whatsapp = "+65 9000 0000"; card.website = "acme.sg"; card.linkedin = "in/janetan"
        let contact = card.toContact()
        XCTAssertEqual(contact.name, "Jane Tan")
        XCTAssertEqual(contact.position, "CTO")
        XCTAssertEqual(contact.company, "Acme")
        XCTAssertEqual(contact.phone, "+65 9000 0000")
        XCTAssertEqual(contact.whatsapp, "+65 9000 0000")
        XCTAssertEqual(contact.notes, "Office: +65 6000 0000\nWebsite: acme.sg\nLinkedIn: in/janetan")
        XCTAssertTrue(contact.id.isEmpty, "a scanned contact is new")

        var landlineOnly = BusinessCard(); landlineOnly.officePhone = "+65 6000 0000"
        XCTAssertEqual(landlineOnly.toContact().phone, "+65 6000 0000")
        XCTAssertEqual(landlineOnly.toContact().notes, "")
    }

    func testLinkedInHandlesAndURLsResolveToProfile() {
        for input in ["jordanavery", "in/jordanavery", "linkedin.com/in/jordanavery", "https://www.linkedin.com/in/jordanavery?trk=profile"] {
            var card = BusinessCard(); card.linkedin = input
            let result = WhatsAppLink.linkedInURL(for: card)
            XCTAssertNotNil(result)
            XCTAssertEqual(URL(string: result!)?.path, "/in/jordanavery")
            XCTAssertNil(URLComponents(string: result!)?.query)
        }
    }
    func testLinkedInRejectsUnrelatedHostsAndMalformedProfiles() {
        for input in ["https://linkedin.com.evil.example/in/jordan", "https://evil.example/in/jordan", "https://linkedin.com", "https://www.linkedin.com/in/", "https://user:pass@linkedin.com/in/jordan", "not a profile"] {
            var card = BusinessCard(); card.linkedin = input
            XCTAssertNil(WhatsAppLink.linkedInURL(for: card), input)
        }
    }
    func testWhatsAppQRPreservesExistingQueryAndSeparateLinkedInTarget() {
        var details = BusinessCard(); details.mobile = "+65 9123 4567"; details.linkedin = "jordanavery"
        let card = SavedCard(id:"1", fullName:"Jordan", company:"", slug:"jordan", url:"https://tapcard.example/c/jordan?ref=mobile", createdAt:Date(), details:details)
        let whatsapp = CardQRTarget(card:card, mode:.whatsapp, preferences: prefs("65"))
        let items = URLComponents(string:whatsapp.url!)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name:"ref",value:"mobile")))
        XCTAssertTrue(items.contains(URLQueryItem(name:"wa",value:"1")))
        XCTAssertEqual(whatsapp.whatsappNumber, "+65 9123 4567")
        let linkedin = CardQRTarget(card:card, mode:.linkedin, preferences: prefs("65"))
        XCTAssertEqual(linkedin.url,"https://www.linkedin.com/in/jordanavery")
        let plain = CardQRTarget(card:card, mode:.card, preferences: prefs("65"))
        XCTAssertFalse(URLComponents(string:plain.url!)!.queryItems!.contains { $0.name == "wa" })
    }
    func testQRModesWithoutTheirDetailAskForIt() {
        var details = BusinessCard(); details.email = "j@example.com"
        let card = SavedCard(id:"1", fullName:"Jordan", company:"", slug:"jordan", url:"https://tapcard.example/c/jordan", createdAt:Date(), details:details)
        XCTAssertNil(CardQRTarget(card:card, mode:.whatsapp, preferences: prefs("65")).url)
        XCTAssertNil(CardQRTarget(card:card, mode:.linkedin, preferences: prefs("65")).url)
        XCTAssertNotNil(CardQRTarget(card:card, mode:.card, preferences: prefs("65")).url)
    }
    /// The reported bug: a local "96983731" produced wa.me/96983731, which
    /// WhatsApp rejects as missing a country code.
    func testLocalNumbersGetTheCountryCode() {
        let cases: [(String, String, String)] = [
            ("96983731","65","6596983731"), ("9698 3731","65","6596983731"), ("+65 9698 3731","65","6596983731"),
            ("6588666375","65","6588666375"), ("65123456","65","6565123456"), ("0065 9698 3731","65","6596983731"),
            ("012-345 6789","60","60123456789"), ("60123456789","60","60123456789"), ("9123456789","91","919123456789"),
            ("919123456789","91","919123456789"), ("(415) 555-0123","1","14155550123"), ("+60 12-345 6789","65","60123456789"),
            ("","65",""),
        ]
        for (input, cc, want) in cases {
            XCTAssertEqual(PhoneNumber.internationalDigits(input, countryCode: cc), want, "\(input) cc \(cc)")
        }
        var card = BusinessCard(); card.mobile = "96983731"
        XCTAssertEqual(WhatsAppLink.number(for: card, countryCode: "65"), "6596983731")
        XCTAssertEqual(PhoneNumber.display(digits: "6596983731", countryCode: "65"), "+65 9698 3731")
        XCTAssertEqual(PhoneNumber.display(digits: "60123456789", countryCode: "60"), "+60 1 2345 6789")
    }
    func testLegacyDefaultAccentMeansMatchDesign() throws {
        let legacy = Data(##"{"fullName":"J","accentColor":"#6A47F5","theme":"OCEAN"}"##.utf8)
        XCTAssertNil(try JSONDecoder().decode(BusinessCard.self, from: legacy).customAccentHex)
        let chosen = Data(##"{"fullName":"J","accentColor":"#E11D48"}"##.utf8)
        XCTAssertEqual(try JSONDecoder().decode(BusinessCard.self, from: chosen).customAccentHex, "#E11D48")
    }
    func testOldSavedCardStillLoadsWithNewDesigns() throws {
        let old = Data(#"{"fullName":"Jordan","email":"jordan@example.com"}"#.utf8)
        let card = try JSONDecoder().decode(BusinessCard.self, from:old)
        XCTAssertTrue(card.isValid)
        XCTAssertEqual(card.theme,.modern)
        XCTAssertEqual(card.profilePhoto, "")
    }

    func testWhatsAppContactLinkIsFoundInPastedText() {
        XCTAssertEqual(WhatsAppLink.contactLink(in: "  https://wa.me/qr/ABCDEF1234XYZ1 "), "https://wa.me/qr/ABCDEF1234XYZ1")
        XCTAssertEqual(WhatsAppLink.contactLink(in: "Follow this link to add me as a contact on WhatsApp: https://wa.me/qr/K3JX5Q7ZLMUKA1"),
                       "https://wa.me/qr/K3JX5Q7ZLMUKA1")
        XCTAssertEqual(WhatsAppLink.contactLink(in: "api.whatsapp.com/qr/K3JX5Q7ZLMUKA1"), "https://wa.me/qr/K3JX5Q7ZLMUKA1")
        XCTAssertNil(WhatsAppLink.contactLink(in: "https://wa.me/6596983731"))
        XCTAssertNil(WhatsAppLink.contactLink(in: "hello"))
    }
    /// With the owner's WhatsApp contact link on file, the WhatsApp QR is that
    /// link — the same code WhatsApp shows — even without a number on the card.
    func testWhatsAppQRUsesTheContactLinkWhenSet() {
        let card = SavedCard(id:"1", fullName:"Jordan", company:"", slug:"jordan", url:"https://tapcard.example/c/jordan", createdAt:Date(), details:BusinessCard())
        let target = CardQRTarget(card: card, mode: .whatsapp, preferences: prefs("65", whatsappQr: "https://wa.me/qr/K3JX5Q7ZLMUKA1"))
        XCTAssertEqual(target.url, "https://wa.me/qr/K3JX5Q7ZLMUKA1")
        XCTAssertTrue(target.addsWhatsAppContact)
        let card2 = CardQRTarget(card: card, mode: .card, preferences: prefs("65", whatsappQr: "https://wa.me/qr/K3JX5Q7ZLMUKA1"))
        XCTAssertEqual(card2.url?.hasPrefix("https://tapcard.example/c/jordan"), true)
        XCTAssertFalse(card2.addsWhatsAppContact)
    }
    /// The WhatsApp mark over the centre must not cost a scan — for the short
    /// contact link and the longer card hand-off alike.
    @MainActor
    func testBrandedWhatsAppQRStillDecodes() throws {
        let payloads = ["https://wa.me/qr/K3JX5Q7ZLMUKA1",
                        "https://tapcard.tertiaryinfotech.com/c/dr-alfred-ang-rlbg?wa=1&src=qr"]
        let images = try payloads.map {
            try XCTUnwrap(QRCodeImage.shareImage(payload: $0, mode: .whatsapp)?.cgImage)
        }
        if let dir = ProcessInfo.processInfo.environment["QR_SNAPSHOT_DIR"] {
            for (image, name) in zip(images, ["qr-contact.png", "qr-chat.png"]) {
                try UIImage(cgImage: image).pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
            }
        }
        for (image, payload) in zip(images, payloads) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                // The Simulator has no Vision inference; this runs on device.
                throw XCTSkip("Vision unavailable here: \(error.localizedDescription)")
            }
            XCTAssertEqual(request.results?.first?.payloadStringValue, payload)
        }
    }
}
