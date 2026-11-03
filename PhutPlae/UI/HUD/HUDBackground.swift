import SwiftUI

struct HUDBackground: View {
    var palette: HUDPalette
    var energy: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(HUDPalette.void))

                var haze = context
                haze.addFilter(.blur(radius: 90))
                let core = CGRect(
                    x: size.width * 0.18,
                    y: size.height * 0.22,
                    width: size.width * 0.64,
                    height: size.width * 0.64
                )
                haze.fill(
                    Path(ellipseIn: core.insetBy(dx: 20, dy: 40)),
                    with: .color(palette.glow.opacity(0.10 + 0.10 * energy))
                )

                drawGrid(context: context, size: size, time: t)
                drawScan(context: context, size: size, time: t)
                drawVignette(context: context, size: size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        var path = Path()
        let step: CGFloat = 28
        let drift = CGFloat(time.truncatingRemainder(dividingBy: 2.8) / 2.8) * step
        var x: CGFloat = drift - step
        while x < size.width + step {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = drift - step
        while y < size.height + step {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        context.stroke(path, with: .color(palette.glow.opacity(0.05)), lineWidth: 0.6)
    }

    private func drawScan(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let y = size.height * CGFloat((sin(time * 0.55) + 1) / 2)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(palette.glow.opacity(0.18)), lineWidth: 1.2)
    }

    private func drawVignette(context: GraphicsContext, size: CGSize) {
        let inset = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 12)
        context.stroke(
            Path(roundedRect: inset, cornerRadius: 26),
            with: .color(palette.glow.opacity(0.22)),
            lineWidth: 1
        )
        context.stroke(
            Path(roundedRect: inset.insetBy(dx: 3, dy: 3), cornerRadius: 23),
            with: .color(palette.glow.opacity(0.08)),
            lineWidth: 0.6
        )
    }
}
