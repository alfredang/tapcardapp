import SwiftUI

/// Google's four-colour "G" mark, drawn as vector paths — the iOS counterpart of
/// the Android app's `ic_google.xml`. Drawn rather than shipped as an asset so
/// it stays crisp at any size and adds no binary payload.
///
/// The geometry is Google's official mark on a 48×48 grid, scaled to fit.
/// Google's branding guidelines require the logo be used unmodified, so the
/// colours are fixed and do not adapt to light/dark mode.
struct GoogleGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            let transform = CGAffineTransform(scaleX: scale, y: scale)

            for segment in Self.segments {
                var path = segment.path
                path = path.applying(transform)
                context.fill(path, with: .color(segment.color))
            }
        }
        .accessibilityHidden(true)
    }

    private struct Segment {
        let path: Path
        let color: Color
    }

    private static let segments: [Segment] = [
        // Blue — right arm of the G.
        Segment(
            path: Path {
                $0.move(to: CGPoint(x: 46.98, y: 24.55))
                $0.addCurve(to: CGPoint(x: 46.6, y: 20),
                            control1: CGPoint(x: 46.98, y: 22.98),
                            control2: CGPoint(x: 46.84, y: 21.46))
                $0.addLine(to: CGPoint(x: 24, y: 20))
                $0.addLine(to: CGPoint(x: 24, y: 29.02))
                $0.addLine(to: CGPoint(x: 36.94, y: 29.02))
                $0.addCurve(to: CGPoint(x: 32.16, y: 36.2),
                            control1: CGPoint(x: 36.36, y: 31.98),
                            control2: CGPoint(x: 34.68, y: 34.5))
                $0.addLine(to: CGPoint(x: 32.16, y: 42.2))
                $0.addLine(to: CGPoint(x: 39.89, y: 42.2))
                $0.addCurve(to: CGPoint(x: 46.98, y: 24.55),
                            control1: CGPoint(x: 44.4, y: 38.02),
                            control2: CGPoint(x: 46.98, y: 31.84))
                $0.closeSubpath()
            },
            color: Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
        ),
        // Green — bottom sweep.
        Segment(
            path: Path {
                $0.move(to: CGPoint(x: 24, y: 48))
                $0.addCurve(to: CGPoint(x: 39.89, y: 42.2),
                            control1: CGPoint(x: 30.48, y: 48),
                            control2: CGPoint(x: 35.93, y: 45.87))
                $0.addLine(to: CGPoint(x: 32.16, y: 36.2))
                $0.addCurve(to: CGPoint(x: 24, y: 38.48),
                            control1: CGPoint(x: 30.01, y: 37.64),
                            control2: CGPoint(x: 27.24, y: 38.48))
                $0.addCurve(to: CGPoint(x: 11.43, y: 29.27),
                            control1: CGPoint(x: 17.74, y: 38.48),
                            control2: CGPoint(x: 13.43, y: 34.25))
                $0.addLine(to: CGPoint(x: 3.44, y: 29.27))
                $0.addLine(to: CGPoint(x: 3.44, y: 35.46))
                $0.addCurve(to: CGPoint(x: 24, y: 48),
                            control1: CGPoint(x: 7.4, y: 43.32),
                            control2: CGPoint(x: 15.06, y: 48))
                $0.closeSubpath()
            },
            color: Color(red: 52 / 255, green: 168 / 255, blue: 83 / 255)
        ),
        // Yellow — left edge.
        Segment(
            path: Path {
                $0.move(to: CGPoint(x: 11.43, y: 29.27))
                $0.addCurve(to: CGPoint(x: 10.75, y: 24),
                            control1: CGPoint(x: 10.99, y: 27.63),
                            control2: CGPoint(x: 10.75, y: 25.85))
                $0.addCurve(to: CGPoint(x: 11.43, y: 18.73),
                            control1: CGPoint(x: 10.75, y: 22.15),
                            control2: CGPoint(x: 10.99, y: 20.37))
                $0.addLine(to: CGPoint(x: 11.43, y: 12.54))
                $0.addLine(to: CGPoint(x: 3.44, y: 12.54))
                $0.addCurve(to: CGPoint(x: 3.44, y: 35.46),
                            control1: CGPoint(x: 1.25, y: 16.89),
                            control2: CGPoint(x: 0, y: 21.31))
                $0.addLine(to: CGPoint(x: 11.43, y: 29.27))
                $0.closeSubpath()
            },
            color: Color(red: 251 / 255, green: 188 / 255, blue: 5 / 255)
        ),
        // Red — top sweep.
        Segment(
            path: Path {
                $0.move(to: CGPoint(x: 24, y: 9.52))
                $0.addCurve(to: CGPoint(x: 32.66, y: 12.91),
                            control1: CGPoint(x: 27.54, y: 9.52),
                            control2: CGPoint(x: 30.71, y: 10.74))
                $0.addLine(to: CGPoint(x: 39.62, y: 5.95))
                $0.addCurve(to: CGPoint(x: 24, y: 0),
                            control1: CGPoint(x: 35.9, y: 2.48),
                            control2: CGPoint(x: 30.47, y: 0))
                $0.addCurve(to: CGPoint(x: 3.44, y: 12.54),
                            control1: CGPoint(x: 15.06, y: 0),
                            control2: CGPoint(x: 7.4, y: 4.68))
                $0.addLine(to: CGPoint(x: 11.43, y: 18.73))
                $0.addCurve(to: CGPoint(x: 24, y: 9.52),
                            control1: CGPoint(x: 13.43, y: 13.75),
                            control2: CGPoint(x: 17.74, y: 9.52))
                $0.closeSubpath()
            },
            color: Color(red: 234 / 255, green: 67 / 255, blue: 53 / 255)
        ),
    ]
}
