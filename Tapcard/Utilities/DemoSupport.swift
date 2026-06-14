import Foundation

/// Screenshot/demo hooks, gated entirely behind launch environment variables so
/// they have zero effect in a normal (App Store) launch. Used to capture
/// marketing screenshots of the Review and Result screens without a live
/// backend round-trip.
enum DemoSupport {
    static var seedCards: Bool {
        ProcessInfo.processInfo.environment["TAPCARD_DEMO"] == "1"
    }
    static var startInReview: Bool {
        ProcessInfo.processInfo.environment["TAPCARD_DEMO_REVIEW"] == "1"
    }
    static var startInDone: Bool {
        ProcessInfo.processInfo.environment["TAPCARD_DEMO_DONE"] == "1"
    }
    /// When set, `submit` returns a canned published card instead of calling the API.
    static var fakeSubmit: Bool {
        ProcessInfo.processInfo.environment["TAPCARD_DEMO_FAKE_SUBMIT"] == "1"
    }

    static var demoCard: BusinessCard {
        var c = BusinessCard()
        c.fullName = "Jordan Avery"
        c.jobTitle = "Product Design Lead"
        c.company = "Lumen Studio"
        c.email = "jordan@lumen.studio"
        c.mobile = "+65 9123 4567"
        c.officePhone = "+65 6555 0100"
        c.website = "https://lumen.studio"
        c.address = "71 Ayer Rajah Crescent, Singapore"
        c.linkedin = "linkedin.com/in/jordanavery"
        c.theme = .modern
        return c
    }

    static var demoSavedCards: [SavedCard] {
        [
            SavedCard(id: "demo1", fullName: "Jordan Avery", company: "Lumen Studio",
                      slug: "jordan-avery", url: "https://tapcard.tertiaryinfotech.com/c/jordan-avery",
                      createdAt: Date(timeIntervalSince1970: 1_760_000_000)),
            SavedCard(id: "demo2", fullName: "Mei Lin Tan", company: "Northwind Ventures",
                      slug: "mei-lin-tan", url: "https://tapcard.tertiaryinfotech.com/c/mei-lin-tan",
                      createdAt: Date(timeIntervalSince1970: 1_759_000_000)),
        ]
    }
}
