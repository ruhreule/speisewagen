import SwiftUI

struct SpeisewagenLogo: View {
    var size: CGFloat = 40

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 60

            // Wagon body
            ctx.fill(
                Path(roundedRect: CGRect(x: 4*s, y: 16*s, width: 52*s, height: 26*s), cornerRadius: 5*s),
                with: .color(.swAccent)
            )
            // Top highlight stripe
            ctx.fill(
                Path(roundedRect: CGRect(x: 4*s, y: 16*s, width: 52*s, height: 5*s), cornerRadius: 5*s),
                with: .color(.white.opacity(0.18))
            )
            // Windows
            for xo in [9.0, 25.0, 41.0] {
                ctx.fill(
                    Path(roundedRect: CGRect(x: xo*s, y: 21*s, width: 11*s, height: 9*s), cornerRadius: 2*s),
                    with: .color(.white.opacity(0.85))
                )
            }
            // Bottom stripe
            ctx.fill(Path(CGRect(x: 4*s, y: 38*s, width: 52*s, height: 4*s)), with: .color(.black.opacity(0.15)))
            // Couplers
            for xo in [1.0, 56.0] {
                ctx.fill(
                    Path(roundedRect: CGRect(x: xo*s, y: 26*s, width: 3*s, height: 6*s), cornerRadius: 1.5*s),
                    with: .color(Color(white: 0.6))
                )
            }
            // Undercarriage
            ctx.fill(
                Path(roundedRect: CGRect(x: 8*s, y: 41*s, width: 44*s, height: 3*s), cornerRadius: 1*s),
                with: .color(Color(white: 0.33))
            )
            // Wheels (cx=16, cx=44; cy=50; r=7/4/1.5)
            for cx in [16.0, 44.0] {
                ctx.fill(Path(ellipseIn: CGRect(x: (cx-7)*s,   y: 43*s,    width: 14*s, height: 14*s)), with: .color(Color(white: 0.20)))
                ctx.fill(Path(ellipseIn: CGRect(x: (cx-4)*s,   y: 46*s,    width: 8*s,  height: 8*s)),  with: .color(Color(white: 0.33)))
                ctx.fill(Path(ellipseIn: CGRect(x: (cx-1.5)*s, y: 48.5*s,  width: 3*s,  height: 3*s)),  with: .color(Color(white: 0.67)))
            }
            // Fork stem
            var fork = Path()
            fork.move(to: CGPoint(x: 28*s, y: 22.5*s))
            fork.addLine(to: CGPoint(x: 28*s, y: 29*s))
            ctx.stroke(fork, with: .color(.swAccent), style: StrokeStyle(lineWidth: 1.2*s, lineCap: .round))
            // Fork arch
            var arch = Path()
            arch.move(to: CGPoint(x: 26.5*s, y: 22.5*s))
            arch.addQuadCurve(to: CGPoint(x: 29.5*s, y: 22.5*s), control: CGPoint(x: 28*s, y: 25.5*s))
            ctx.stroke(arch, with: .color(.swAccent), style: StrokeStyle(lineWidth: 1.1*s, lineCap: .round))
            // Knife stem
            var knife = Path()
            knife.move(to: CGPoint(x: 31*s, y: 22.5*s))
            knife.addLine(to: CGPoint(x: 31*s, y: 29*s))
            ctx.stroke(knife, with: .color(.swAccent), style: StrokeStyle(lineWidth: 1.2*s, lineCap: .round))
            // Knife blade
            var blade = Path()
            blade.move(to: CGPoint(x: 29.8*s, y: 22.5*s))
            blade.addLine(to: CGPoint(x: 29.8*s, y: 25.5*s))
            blade.addQuadCurve(to: CGPoint(x: 31*s, y: 25.5*s), control: CGPoint(x: 30.4*s, y: 26*s))
            ctx.stroke(blade, with: .color(.swAccent), style: StrokeStyle(lineWidth: 1.1*s, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}
