import SwiftUI

/// Twenty illustrated headers, shared by the card and the template gallery.
struct CardDesignBanner: View {
    let theme: CardTheme

    var body: some View {
        theme.banner.overlay {
            Canvas { context, size in
                let w = size.width, h = size.height
                func line(_ points: [CGPoint], opacity: Double = 0.25, width: CGFloat = 1.5) {
                    var path = Path()
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: width)
                }
                func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, filled: Bool = false) {
                    let path = Path(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2))
                    if filled { context.fill(path, with: .color(.white.opacity(0.16))) }
                    else { context.stroke(path, with: .color(.white.opacity(0.28)), lineWidth: 1.5) }
                }
                switch theme {
                case .corporate:
                    for i in 0..<8 { let x = CGFloat(i)*w/6; line([.init(x:x,y:0),.init(x:x+h,y:h)]) }
                case .modern:
                    circle(w*0.82,h*0.25,h*0.8,filled:true); circle(w*0.15,h,h*0.65)
                case .minimalist:
                    var frame = Path(); frame.addRect(CGRect(x:14,y:14,width:w-28,height:h-28))
                    context.stroke(frame,with:.color(.black.opacity(0.25)),lineWidth:1)
                    line([.init(x:w*0.7,y:0),.init(x:w*0.7,y:h)],opacity:0.7)
                case .dark:
                    for x in stride(from:CGFloat(0),through:w,by:22) { line([.init(x:x,y:0),.init(x:x,y:h)],opacity:0.1) }
                    for y in stride(from:CGFloat(0),through:h,by:22) { line([.init(x:0,y:y),.init(x:w,y:y)],opacity:0.1) }
                case .creative:
                    for i in 0..<8 { let x = CGFloat(i)*w/7; circle(x,h*0.3,16,filled:i%2==0); line([.init(x:x,y:h*0.7),.init(x:x+12,y:h*0.9)],width:5) }
                case .luxury:
                    for inset in [CGFloat(9),16] {
                        var p = Path(); p.addRect(CGRect(x:inset,y:inset,width:w-2*inset,height:h-2*inset))
                        context.stroke(p,with:.color(Color(hex:"#F0D27A").opacity(0.75)),lineWidth:1)
                    }
                case .ocean, .teal:
                    for i in 0..<5 {
                        let y = h*0.25+CGFloat(i)*h*0.18
                        var p = Path(); p.move(to:.init(x:0,y:y))
                        p.addCurve(to:.init(x:w,y:y),control1:.init(x:w*0.3,y:y-h*0.5),control2:.init(x:w*0.65,y:y+h*0.5))
                        context.stroke(p,with:.color(.white.opacity(theme == .ocean ? 0.26 : 0.4)),lineWidth:theme == .ocean ? 2 : 5)
                    }
                case .forest:
                    for i in 0..<7 { let x=CGFloat(i)*w/6; line([.init(x:x-35,y:h),.init(x:x,y:h*0.15),.init(x:x+35,y:h)],width:2) }
                case .sunset:
                    circle(w*0.75,h*0.45,h*0.48,filled:true)
                    for i in 0..<5 { let y=h*0.6+CGFloat(i)*10; line([.init(x:0,y:y),.init(x:w,y:y)],opacity:0.35) }
                case .rose:
                    for i in 0..<5 { circle(w*0.2+CGFloat(i)*w*0.15,h*0.5,h*0.36) }
                case .indigo:
                    for i in 0..<7 { let x=CGFloat(i)*w/6; line([.init(x:x-25,y:0),.init(x:x+25,y:h*0.5),.init(x:x-25,y:h)],width:3) }
                case .amber:
                    for i in 0..<13 {
                        let angle=Double(i)*Double.pi/12
                        line([.init(x:w*0.5,y:h),.init(x:w*0.5+cos(angle)*w,y:h-sin(angle)*w)],opacity:0.35)
                    }
                case .crimson:
                    for i in 0..<6 { let x=CGFloat(i)*w/5; line([.init(x:x-40,y:0),.init(x:x+20,y:h)],opacity:0.18,width:18) }
                case .lavender:
                    for i in 0..<4 { circle(w*0.2+CGFloat(i)*w*0.22,h*0.5,h*0.5,filled:true) }
                case .midnight:
                    for i in 0..<30 { circle(CGFloat((i*67)%301)/301*w,CGFloat((i*37)%101)/101*h,i%5==0 ? 2.5 : 1,filled:true) }
                    line([.init(x:w*0.1,y:h*0.7),.init(x:w*0.35,y:h*0.3),.init(x:w*0.65,y:h*0.55),.init(x:w*0.9,y:h*0.15)])
                case .sky:
                    for i in 0..<5 { circle(CGFloat(i)*w/4,h*0.85,h*0.45,filled:true) }
                case .mint:
                    for x in stride(from:CGFloat(10),through:w,by:24) {
                        for y in stride(from:CGFloat(10),through:h,by:24) { circle(x,y,2,filled:true) }
                    }
                case .peach:
                    for i in 0..<6 { let x=CGFloat(i)*w/5; line([.init(x:x-25,y:0),.init(x:x+25,y:h)],opacity:0.3,width:28) }
                case .graphite:
                    for i in 0..<8 { let x=CGFloat(i)*w/7; line([.init(x:x-35,y:h),.init(x:x,y:0),.init(x:x+35,y:h)],opacity:0.22) }
                }
            }
        }.clipped().accessibilityHidden(true)
    }
}

extension CardTheme {
    var designName: String {
        switch self {
        case .corporate: "Executive Lines"
        case .modern: "Orbit"
        case .minimalist: "Editorial"
        case .dark: "Blueprint"
        case .creative: "Confetti"
        case .luxury: "Gold Frame"
        case .ocean: "Ocean Waves"
        case .forest: "Alpine"
        case .sunset: "Golden Hour"
        case .rose: "Petal Rings"
        case .indigo: "Prism"
        case .teal: "Flow"
        case .amber: "Sunburst"
        case .crimson: "Velocity"
        case .lavender: "Soft Bloom"
        case .midnight: "Constellation"
        case .sky: "Cloudscape"
        case .mint: "Dot Studio"
        case .peach: "Ribbon"
        case .graphite: "Facet"
        }
    }
    var cornerRadius: CGFloat {
        switch self {
        case .minimalist, .luxury, .corporate: 12
        case .creative, .lavender, .peach, .mint: 28
        default: 20
        }
    }
    var identityFont: Font {
        switch self {
        case .luxury, .minimalist, .rose: .system(.title2, design: .serif).weight(.semibold)
        case .creative, .lavender, .mint, .peach: .system(.title2, design: .rounded).bold()
        default: .title2.bold()
        }
    }
}
