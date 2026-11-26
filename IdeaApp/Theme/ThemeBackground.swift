import SwiftUI
import UIKit

/// The content layer behind everything. Liquid Glass controls float above it,
/// so the theme shows through the toolbars, chips and composer.
struct ThemeBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch theme.id {
            case Theme.farm.id: FarmBackground()
            case Theme.mono.id: MonoBackground()
            default: Color(uiColor: .systemBackground)
            }
        }
        .ignoresSafeArea()
    }
}

/// Near-black with a faint dot grid, like graph paper in a terminal.
private struct MonoBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            var dots = Path()
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x, y: y, width: 1.6, height: 1.6))
                    x += spacing
                }
                y += spacing
            }
            context.fill(dots, with: .color(.white.opacity(0.08)))
        }
        .background(Color(hex: 0x0A0A0A))
    }
}

/// A sky, a sun, a few clouds and rolling hills with flowers.
private struct FarmBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x7CC8F5), Color(hex: 0xBFE6FB), Color(hex: 0xF3FAF0)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(hex: 0xFFD54A))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: 0xFFC83D).opacity(0.7), radius: 40)
                    .position(x: size.width * 0.8, y: max(size.height * 0.2, 150))

                Cloud()
                    .frame(width: 150, height: 44)
                    .position(x: size.width * 0.26, y: size.height * 0.16)
                Cloud()
                    .frame(width: 110, height: 34)
                    .position(x: size.width * 0.66, y: size.height * 0.26)

                Hill(baseline: 0.70, amplitude: 26, waves: 0.9, phase: 0.4)
                    .fill(Color(hex: 0xA6DB86))
                Hill(baseline: 0.78, amplitude: 22, waves: 1.2, phase: 2.0)
                    .fill(Color(hex: 0x6FBF63))
                Flowers(top: 0.80)
                Hill(baseline: 0.88, amplitude: 16, waves: 1.5, phase: 3.6)
                    .fill(Color(hex: 0x4E9E4F))
                Flowers(top: 0.9, seed: 7)
            }
        }
    }
}

private struct Cloud: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Capsule().frame(width: w, height: h * 0.6).offset(y: h * 0.2)
                Circle().frame(width: h * 0.9).offset(x: -w * 0.15, y: 0)
                Circle().frame(width: h * 0.75).offset(x: w * 0.15, y: h * 0.05)
            }
            .frame(width: w, height: h)
            .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private struct Hill: Shape {
    var baseline: CGFloat
    var amplitude: CGFloat
    var waves: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.height * baseline
        let steps = 48
        path.move(to: CGPoint(x: 0, y: rect.height))
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let y = baseY - amplitude * sin(t * .pi * 2 * waves + phase)
            path.addLine(to: CGPoint(x: rect.width * t, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Little dots of color scattered across a hill. Positions are deterministic.
private struct Flowers: View {
    var top: CGFloat
    var seed: UInt64 = 3

    private static let colors: [Color] = [
        Color(hex: 0xFF7AA8), Color(hex: 0xFFE14D), .white, Color(hex: 0xB78CFF), Color(hex: 0xFF8C42),
    ]

    var body: some View {
        Canvas { context, size in
            var state = seed
            func next() -> CGFloat {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
            }
            let count = Int(size.width / 9)
            for _ in 0..<count {
                let x = next() * size.width
                let y = size.height * (top + next() * (1 - top))
                let radius = 1.8 + next() * 2.2
                let color = Self.colors[Int(next() * CGFloat(Self.colors.count)) % Self.colors.count]
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}
