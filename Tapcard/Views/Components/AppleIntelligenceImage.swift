import SwiftUI
import UIKit
import ImagePlayground

/// Apple Intelligence (Image Playground) for a card's banner and profile
/// photo. Generation runs on device; the result is stored like any picked
/// photo. Phones without Apple Intelligence never see the option — every
/// entry point is wrapped in `IfImagePlaygroundSupported`.
enum CardImageKind {
    case banner, avatar

    /// Starting ideas for Image Playground, from the card itself. The person
    /// can edit them in the sheet before generating.
    func concepts(for card: BusinessCard) -> [String] {
        var ideas: [String]
        switch self {
        case .banner:
            ideas = ["abstract background", "\(card.theme.label.lowercased()) colours"]
        case .avatar:
            ideas = ["professional portrait"]
        }
        for field in [card.jobTitle, card.company] where !field.trimmed.isEmpty {
            ideas.append(field.trimmed)
        }
        return ideas
    }

    /// Longest side kept: the avatar renders at 116pt, the banner spans the
    /// screen.
    var maxDimension: CGFloat { self == .avatar ? 512 : 1400 }

    /// Downscale, compress and encode as a base64 data URL — the format the
    /// web builder uploads — keeping payloads well under the API cap.
    func dataURL(for image: UIImage) -> String? {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }
}

/// Shows its content only where Image Playground is available (iOS 18.1+
/// on an Apple Intelligence device, with it turned on).
struct IfImagePlaygroundSupported<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 18.1, *) {
            SupportGate(content: content)
        }
    }

    @available(iOS 18.1, *)
    private struct SupportGate: View {
        @Environment(\.supportsImagePlayground) private var supported
        let content: () -> Content

        var body: some View {
            if supported { content() }
        }
    }
}

extension View {
    /// Presents Image Playground seeded with `concepts` (and `sourceImage`,
    /// which it can turn into a likeness), handing back the chosen image.
    /// A no-op before iOS 18.1.
    func appleIntelligenceImageSheet(isPresented: Binding<Bool>, concepts: [String],
                                     sourceImage: UIImage? = nil,
                                     onImage: @escaping (UIImage) -> Void) -> some View {
        modifier(ImagePlaygroundSheetModifier(isPresented: isPresented, concepts: concepts,
                                              sourceImage: sourceImage, onImage: onImage))
    }
}

private struct ImagePlaygroundSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let concepts: [String]
    let sourceImage: UIImage?
    let onImage: (UIImage) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.1, *) {
            content.imagePlaygroundSheet(
                isPresented: $isPresented,
                concepts: concepts.map { ImagePlaygroundConcept.text($0) },
                sourceImage: sourceImage.map { Image(uiImage: $0) }
            ) { url in
                // The image is a temporary file owned by the system; read it now.
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    onImage(image)
                }
            }
        } else {
            content
        }
    }
}
