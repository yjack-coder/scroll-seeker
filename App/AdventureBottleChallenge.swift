import SwiftUI

struct AdventureBottleChallenge: View {
    var onSuccess: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var bargained = false
    @State private var adjustment = 0.0
    @State private var elapsed = 0.0
    @State private var steadySeconds = 0.0
    @State private var hasAdjusted = false
    @State private var finished = false

    private var lean: Double { min(1, max(-1, adjustment + sin(elapsed * 0.65 + 0.85) * 0.34 + sin(elapsed * 1.7) * 0.12)) }
    private var steady: Bool { abs(lean) < 0.16 && hasAdjusted }

    var body: some View {
        VStack(spacing: 22) {
            if !bargained {
                AdventureChoiceChallenge(questions: AdventureQuestion.forMission("m5")) { bargained = true }
            } else {
                Text("把瓶子穩住三秒").font(SeekerStyle.brush(26))
                Text("Slide left or right to balance the bottle. Keep its marker inside the gold center for three seconds.")
                    .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                SauceBottleDrawing()
                    .frame(width: 85, height: 130)
                    .rotationEffect(.degrees(reduceMotion ? 0 : lean * 18), anchor: .bottom)
                    .padding(.vertical, 10)
                    .accessibilityHidden(true)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SeekerStyle.indigo.opacity(0.12)).frame(height: 14)
                        Capsule().fill(SeekerStyle.gold.opacity(0.7))
                            .frame(width: geometry.size.width * 0.16, height: 18)
                            .offset(x: geometry.size.width * 0.42)
                        Circle().fill(steady ? SeekerStyle.gold : SeekerStyle.red)
                            .frame(width: 22, height: 22)
                            .offset(x: (geometry.size.width - 22) * (lean + 1) / 2)
                    }
                }
                .frame(height: 24).accessibilityHidden(true)
                Text(steady ? "穩住了 · STEADY" : (lean > 0 ? "往左一點 · A LITTLE LEFT" : "往右一點 · A LITTLE RIGHT"))
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(steady ? SeekerStyle.gold : SeekerStyle.red)
                    .accessibilityAddTraits(.updatesFrequently)
                Slider(value: $adjustment, in: -1...1) {
                    Text("Balance the bottle / 調整瓶子重心")
                } minimumValueLabel: {
                    Text("左").font(SeekerStyle.brush(22))
                } maximumValueLabel: {
                    Text("右").font(SeekerStyle.brush(22))
                }
                .tint(SeekerStyle.gold)
                .accessibilityValue("\(Int((adjustment + 1) * 50)) percent, \(steady ? "steady" : lean > 0 ? "move left" : "move right")")
                .onChange(of: adjustment) { _, _ in hasAdjusted = true }
                ProgressView(value: min(3, steadySeconds), total: 3)
                    .tint(SeekerStyle.gold)
                    .accessibilityLabel("Bottle steady")
                    .accessibilityValue("\(Int(steadySeconds)) of three seconds")
                Text("\(steadySeconds, specifier: "%.1f") / 3.0 秒 · seconds")
                    .font(.system(.caption, design: .serif).monospacedDigit()).foregroundStyle(SeekerStyle.gold)
                Text("灑了也不扣錢，調整後再試。No coins are lost. Find the balance and try again.")
                    .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.ink.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(SeekerStyle.ink)
        .task(id: bargained) {
            guard bargained else { return }
            while !Task.isCancelled && !finished {
                do { try await Task.sleep(for: .milliseconds(60)) } catch { break }
                guard scenePhase == .active else { continue }
                elapsed += 0.06
                if steady { steadySeconds += 0.06 } else { steadySeconds = max(0, steadySeconds - 0.12) }
                if steadySeconds >= 3 {
                    finished = true
                    onSuccess()
                }
            }
        }
    }
}

private struct SauceBottleDrawing: View {
    var body: some View {
        Canvas { context, size in
            var bottle = Path()
            bottle.move(to: CGPoint(x: size.width * 0.35, y: 0))
            bottle.addLine(to: CGPoint(x: size.width * 0.65, y: 0))
            bottle.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.25))
            bottle.addQuadCurve(to: CGPoint(x: size.width * 0.88, y: size.height * 0.43), control: CGPoint(x: size.width * 0.88, y: size.height * 0.29))
            bottle.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.95))
            bottle.addQuadCurve(to: CGPoint(x: size.width * 0.12, y: size.height * 0.95), control: CGPoint(x: size.width * 0.5, y: size.height * 1.02))
            bottle.addLine(to: CGPoint(x: size.width * 0.12, y: size.height * 0.43))
            bottle.addQuadCurve(to: CGPoint(x: size.width * 0.35, y: size.height * 0.25), control: CGPoint(x: size.width * 0.12, y: size.height * 0.29))
            bottle.closeSubpath()
            context.fill(bottle, with: .color(SeekerStyle.gold.opacity(0.2)))
            context.stroke(bottle, with: .color(SeekerStyle.ink), lineWidth: 2)
            let label = CGRect(x: size.width * 0.24, y: size.height * 0.47, width: size.width * 0.52, height: size.height * 0.34)
            context.fill(Path(label), with: .color(SeekerStyle.paper))
            context.draw(Text("醬").font(SeekerStyle.brush(26)).foregroundStyle(SeekerStyle.red), at: CGPoint(x: label.midX, y: label.midY))
        }
    }
}
