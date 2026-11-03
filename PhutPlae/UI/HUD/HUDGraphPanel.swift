import SwiftUI

struct HUDGraphPanel: View {
    var title: String
    var unit: String
    var valueText: String
    var values: [Double]
    var range: ClosedRange<Double>
    var palette: HUDPalette
    var alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(palette.muted)
            Text(valueText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                let flicker = 0.82 + 0.18 * sin(timeline.date.timeIntervalSinceReferenceDate * 6)
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(palette.glow.opacity(0.35)), lineWidth: 1)
                    drawGraph(context: context, size: size, flicker: flicker)
                }
            }
            .frame(height: 72)
            Text(unit)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(palette.glow.opacity(0.28), lineWidth: 1)
        )
    }

    private func drawGraph(context: GraphicsContext, size: CGSize, flicker: Double) {
        guard values.count > 1 else { return }
        let minV = range.lowerBound
        let maxV = range.upperBound
        let span = max(0.001, maxV - minV)
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - minV) / span
            let y = size.height - CGFloat(normalized) * (size.height - 6) - 3
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(palette.glow.opacity(0.9 * flicker)), lineWidth: 1.3)

        var fill = path
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [palette.glow.opacity(0.28), palette.glow.opacity(0.0)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        ))
    }
}
