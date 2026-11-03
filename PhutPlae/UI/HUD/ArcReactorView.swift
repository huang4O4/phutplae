import SwiftUI

struct ArcReactorView: View {
    var palette: HUDPalette
    var isListening: Bool
    var isBusy: Bool
    var isBooting: Bool
    var isReady: Bool
    var bootProgress: Double
    var energy: Double
    var waveform: [Double]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                drawHalo(context: context, center: center, radius: radius, time: t)
                if isBooting {
                    drawBootSweep(context: context, center: center, radius: radius, time: t)
                } else {
                    drawWaveform(context: context, center: center, radius: radius * 0.78, time: t)
                }
                drawRings(context: context, center: center, radius: radius, time: t)
                drawCore(context: context, center: center, radius: radius * 0.22, time: t)
                drawTicks(context: context, center: center, radius: radius * 0.96, time: t)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isBooting ? "กำลังบูตโมเดล" : (isListening ? "หยุดฟัง" : "เริ่มฟัง"))
        .accessibilityAddTraits(.isButton)
    }

    private func drawHalo(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        let pulse = 0.55 + 0.45 * energy + 0.08 * sin(time * 3.2)
        var glow = context
        glow.addFilter(.blur(radius: 16))
        let halo = CGRect(
            x: center.x - radius * 0.92,
            y: center.y - radius * 0.92,
            width: radius * 1.84,
            height: radius * 1.84
        )
        glow.fill(Path(ellipseIn: halo), with: .color(palette.glow.opacity(0.16 * pulse)))
    }

    private func drawRings(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        let rings: [(CGFloat, CGFloat, Double)] = [
            (0.98, 1.6, 0.18),
            (0.86, 3.2, -0.32),
            (0.72, 2.0, 0.55),
            (0.58, 6.0, -0.8),
            (0.44, 2.4, 0.22)
        ]
        for (scale, width, speed) in rings {
            let rect = CGRect(
                x: center.x - radius * scale,
                y: center.y - radius * scale,
                width: radius * scale * 2,
                height: radius * scale * 2
            )
            var ring = Path()
            let spin = isBooting ? speed * 2.8 : speed
            let start = Angle.degrees(time * spin * 360)
            let sweep = isBooting ? 90.0 + 220.0 * bootProgress : 268.0
            ring.addArc(center: center, radius: radius * scale, startAngle: start, endAngle: start + .degrees(sweep), clockwise: false)
            let ringOpacity = isBooting ? 0.35 + 0.55 * bootProgress : (isListening ? 0.85 : 0.45)
            context.stroke(ring, with: .color(palette.glow.opacity(ringOpacity)), lineWidth: width)

            var ticks = Path()
            ticks.addArc(center: center, radius: radius * scale, startAngle: start + .degrees(280), endAngle: start + .degrees(310), clockwise: false)
            context.stroke(ticks, with: .color(palette.glow.opacity(0.95)), lineWidth: width + 1)
            _ = rect
        }
    }

    private func drawWaveform(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        let bars = waveform.isEmpty ? Array(repeating: 0.05, count: 48) : waveform
        let count = bars.count
        for (index, value) in bars.enumerated() {
            let angle = (Double(index) / Double(count)) * .pi * 2 + time * 0.35
            let idle = 0.08 + 0.04 * sin(time * 4 + Double(index) * 0.4)
            let magnitude = isListening ? max(idle, value) : idle * 0.7
            let inner = radius * 0.62
            let outer = inner + radius * 0.28 * magnitude
            let start = CGPoint(
                x: center.x + CGFloat(cos(angle)) * inner,
                y: center.y + CGFloat(sin(angle)) * inner
            )
            let end = CGPoint(
                x: center.x + CGFloat(cos(angle)) * outer,
                y: center.y + CGFloat(sin(angle)) * outer
            )
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(palette.glow.opacity(0.35 + 0.55 * magnitude)), lineWidth: 2)
        }
    }

    private func drawCore(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        let beat: Double = {
            if isBooting { return 0.62 + 0.28 * bootProgress + 0.10 * sin(time * 10) }
            if isListening { return 0.82 + 0.35 * energy + 0.08 * sin(time * 8) }
            return 0.7 + 0.06 * sin(time * 2.2)
        }()
        let coreRadius = radius * beat
        var blur = context
        blur.addFilter(.blur(radius: 10))
        blur.fill(
            Path(ellipseIn: CGRect(x: center.x - coreRadius * 1.6, y: center.y - coreRadius * 1.6, width: coreRadius * 3.2, height: coreRadius * 3.2)),
            with: .color(palette.glow.opacity(0.35))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.95), palette.glow, palette.glow.opacity(0.1)]),
                center: center,
                startRadius: 2,
                endRadius: coreRadius
            )
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - coreRadius * 1.15, y: center.y - coreRadius * 1.15, width: coreRadius * 2.3, height: coreRadius * 2.3)),
            with: .color(Color.white.opacity(0.7)),
            lineWidth: 1.2
        )

        let label: String = {
            if isBooting { return String(format: "BOOT %02.0f", bootProgress * 100) }
            if isReady && isBusy { return "SYNC" }
            if isListening { return "HALT" }
            return isReady ? "READY" : "WAIT"
        }()
        context.draw(
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.9)),
            at: CGPoint(x: center.x, y: center.y + radius * 2.15)
        )
    }

    private func drawBootSweep(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        let start = Angle.degrees(time * 420)
        var sweep = Path()
        sweep.addArc(center: center, radius: radius * 0.80, startAngle: start, endAngle: start + .degrees(74), clockwise: false)
        context.stroke(sweep, with: .color(palette.glow.opacity(0.95)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        var trail = Path()
        trail.addArc(center: center, radius: radius * 0.80, startAngle: start - .degrees(80), endAngle: start, clockwise: false)
        context.stroke(trail, with: .color(palette.glow.opacity(0.25)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let bars = 36
        for index in 0..<bars {
            let visible = Double(index) / Double(bars) < max(0.08, bootProgress)
            guard visible else { continue }
            let angle = Double(index) / Double(bars) * .pi * 2
            let inner = radius * 0.50
            let outer = inner + radius * 0.12
            var path = Path()
            path.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
            context.stroke(path, with: .color(palette.glow.opacity(0.7)), lineWidth: 2)
        }
    }

    private func drawTicks(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: TimeInterval) {
        for i in 0..<60 {
            let angle = Double(i) / 60 * .pi * 2 + time * 0.08
            let inner = radius * (i.isMultiple(of: 5) ? 0.90 : 0.94)
            var path = Path()
            path.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius))
            context.stroke(path, with: .color(palette.glow.opacity(i.isMultiple(of: 5) ? 0.7 : 0.25)), lineWidth: 1)
        }
    }
}
