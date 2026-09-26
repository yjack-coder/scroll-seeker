import SwiftUI

struct AdventureBridgeChallenge: View {
    var posture: AdventurePostureStore
    var onSuccess: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed = 0.0
    @State private var layout = BridgeLayout(width: 600, hinge: 300)
    @State private var mastLowered = false
    @State private var bumped = false
    @State private var finished = false
    @State private var relaxed = false
    @State private var message = "船從右方駛來。等它靠近橋，再半摺。The boat approaches from the right. Wait until it nears the bridge."
    @State private var foldFeedback = 0

    private var journeyDuration: Double { relaxed ? 19 : 11 }
    private var startX: Double { max(layout.hinge + 80, layout.width - 52) }
    private var boatX: Double { startX - (startX - layout.hinge + 160) * min(1, elapsed / journeyDuration) }
    private var distanceToBridge: Double { boatX - layout.hinge }
    private var windowOpen: Bool { !bumped && !mastLowered && (22...125).contains(distanceToBridge) }

    var body: some View {
        VStack(spacing: 18) {
            Text("半摺放桅！").font(SeekerStyle.brush(29))
            Text("Half-fold to lower the mast!").font(.system(.title3, design: .serif))
            Text("The bridge sits on the fold. Change to Book posture while the boat is in the gold approach zone.")
                .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)

            GeometryReader { geometry in
                Canvas { context, size in drawScene(context: &context, size: size) }
                    .onGeometryChange(for: BridgeLayout.self) { proxy in
                        BridgeLayout(width: proxy.size.width, hinge: hingeCenter(in: proxy))
                    } action: { layout = $0 }
            }
            .frame(height: 250)
            .background(SeekerStyle.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel("A boat approaches the bridge from the right")
            .accessibilityValue(bumped ? "The mast touched the bridge. Retry." : mastLowered ? "Mast lowered. The boat is passing." : windowOpen ? "Half-fold now" : "Wait for the boat")

            Text(bumped ? "咚！ · A LITTLE BUMP" : mastLowered ? "桅杆放下了 · MAST LOWERED" : windowOpen ? "現在半摺 · HALF-FOLD NOW" : "等等 · WAIT")
                .font(.system(.headline, design: .serif)).foregroundStyle(windowOpen ? SeekerStyle.red : SeekerStyle.gold)
                .accessibilityAddTraits(.updatesFrequently)
            Text(message).font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
                .frame(minHeight: 52)

            if bumped {
                Button("再來一次 · Try again", action: retry).buttonStyle(SeekerActionStyle())
            } else {
                Button(posture.current == .book ? "先展開 · Open before half-folding" : "半摺 · Half-fold") {
                    posture.set(posture.current == .book ? .open : .book)
                }
                .buttonStyle(SeekerActionStyle())
                .disabled(mastLowered)
            }
            HStack(spacing: 8) {
                Text("摺法提示 · FOLD HINT").font(.system(.caption2, design: .serif).weight(.semibold))
                Text("Book posture, or use Half-fold above.").font(.system(.caption, design: .serif))
            }
            .padding(12).frame(maxWidth: .infinity)
            .background(SeekerStyle.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            Toggle("從容航行 · Slower approach", isOn: $relaxed)
                .font(.system(.subheadline, design: .serif))
                .disabled(mastLowered)
                .onChange(of: relaxed) { _, _ in retry() }
        }
        .foregroundStyle(SeekerStyle.ink)
        .onAppear { relaxed = reduceMotion || voiceOver }
        .onChange(of: posture.current) { _, pose in
            guard pose == .book, !bumped, !finished, !mastLowered else { return }
            if windowOpen {
                mastLowered = true
                foldFeedback += 1
                message = "恰到好處！船正在穿過橋洞。Just in time. The boat is slipping beneath the arch."
            } else {
                message = "還早一點。先展開，等船進入金色區間再半摺。A little early. Open, then half-fold when the boat reaches the gold zone."
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: foldFeedback)
        .task {
            while !Task.isCancelled && !finished {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
                guard scenePhase == .active, !bumped else { continue }
                elapsed += 0.05
                if !mastLowered && distanceToBridge < 22 {
                    bumped = true
                    message = "桅杆輕輕碰了橋。沒有損失，展開再試一次。The mast gently bumped the bridge. No harm done—open and try again."
                } else if mastLowered && distanceToBridge < -100 {
                    finished = true
                    onSuccess()
                }
            }
        }
    }

    private func retry() {
        elapsed = 0
        bumped = false
        mastLowered = false
        message = "先等船靠近，再半摺放桅。Wait for the boat to approach, then half-fold to lower its mast."
        posture.set(.open)
    }

    private func hingeCenter(in geometry: GeometryProxy) -> CGFloat {
        if #available(iOS 27.1, *), let region = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed).first {
            return region.frame.midX
        }
        return geometry.size.width / 2
    }

    private func drawScene(context: inout GraphicsContext, size: CGSize) {
        let hinge = CGFloat(layout.hinge)
        let water = size.height * 0.76
        var river = Path()
        for index in 0..<5 {
            let y = water + CGFloat(index) * 9
            river.move(to: CGPoint(x: 18, y: y))
            river.addQuadCurve(to: CGPoint(x: size.width - 18, y: y), control: CGPoint(x: size.width / 2, y: y - 4))
        }
        context.stroke(river, with: .color(SeekerStyle.gold.opacity(0.3)), lineWidth: 1)
        let approach = CGRect(x: hinge + 22, y: water - 18, width: min(103, max(0, size.width - hinge - 22)), height: 44)
        context.fill(Path(roundedRect: approach, cornerRadius: 7), with: .color(SeekerStyle.gold.opacity(windowOpen ? 0.28 : 0.12)))
        var arch = Path()
        arch.move(to: CGPoint(x: hinge - 105, y: water))
        arch.addQuadCurve(to: CGPoint(x: hinge + 105, y: water), control: CGPoint(x: hinge, y: water - 185))
        context.stroke(arch, with: .color(SeekerStyle.ink), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        var crease = Path()
        crease.move(to: CGPoint(x: hinge, y: 12))
        crease.addLine(to: CGPoint(x: hinge, y: size.height - 9))
        context.stroke(crease, with: .color(SeekerStyle.red.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
        context.draw(Text("摺 · FOLD").font(.system(size: 10, design: .serif)).foregroundStyle(SeekerStyle.red), at: CGPoint(x: hinge, y: 17))

        let x = CGFloat(boatX)
        let bowY = water - 1
        var hull = Path()
        hull.move(to: CGPoint(x: x - 42, y: bowY - 13))
        hull.addLine(to: CGPoint(x: x + 42, y: bowY - 13))
        hull.addQuadCurve(to: CGPoint(x: x - 32, y: bowY + 10), control: CGPoint(x: x + 25, y: bowY + 15))
        hull.closeSubpath()
        context.fill(hull, with: .color(SeekerStyle.indigo))
        var mast = Path()
        mast.move(to: CGPoint(x: x, y: bowY - 13))
        mast.addLine(to: CGPoint(x: mastLowered ? x - 50 : x, y: mastLowered ? bowY - 35 : bowY - 115))
        context.stroke(mast, with: .color(SeekerStyle.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        if !mastLowered {
            let sail = CGRect(x: x + 3, y: bowY - 107, width: 31, height: 63)
            context.fill(Path(sail), with: .color(SeekerStyle.paper))
            context.stroke(Path(sail), with: .color(SeekerStyle.gold), lineWidth: 1)
        }
        if bumped {
            context.draw(Text("咚").font(SeekerStyle.brush(34)).foregroundStyle(SeekerStyle.red), at: CGPoint(x: hinge + 15, y: water - 122))
        }
    }

    private struct BridgeLayout: Equatable { var width: Double; var hinge: Double }
}
