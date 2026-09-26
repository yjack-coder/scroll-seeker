import SwiftUI

struct AdventureStealthChallenge: View {
    var missionID: String
    var posture: AdventurePostureStore
    var onSuccess: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed = 0.0
    @State private var progress = 0.0
    @State private var holding = false
    @State private var relaxed = false
    @State private var message = "先觀察，再行動。Watch first; then move."
    @State private var finished = false
    @State private var lastStep = Date.distantPast
    @State private var isHidden = false
    @State private var didHide = false
    @State private var checkpoint = 0.0
    @State private var foldFeedback = 0

    private var guardAway: Bool {
        let period = relaxed ? 10.0 : 6.0
        let fraction = elapsed.truncatingRemainder(dividingBy: period) / period
        return (relaxed ? 0.2...0.8 : 0.35...0.8).contains(fraction)
    }
    private var destination: String {
        switch missionID { case "b1": "糧倉 · GRAIN"; case "b2": "城內 · THROUGH THE GATE"; case "b3": "貨堆 · COVER"; default: "城外 · FREEDOM" }
    }

    var body: some View {
        VStack(spacing: 22) {
            Text(missionID == "b5" ? "摺身避燈，夜出城門" : "摺起作屏，藏住身影")
                .font(SeekerStyle.brush(25)).multilineTextAlignment(.center)
            Text("Move while the lantern turns away. Change to Book or Tent posture to hide behind the folding screen. Open only when the guard looks away.")
                .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
            VStack(spacing: 8) {
                Text(guardAway ? "背身 · LOOKING AWAY" : "巡視 · WATCHING")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(guardAway ? SeekerStyle.gold : SeekerStyle.red)
                Text(isHidden ? "屏風後 · HIDDEN BEHIND THE FOLD" : guardAway ? "可以走了 · You may move" : "快摺起作屏 · Fold to hide")
                    .font(.system(.subheadline, design: .serif))
            }
            .frame(maxWidth: .infinity).padding(18)
            .background(SeekerStyle.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine).accessibilityAddTraits(.updatesFrequently)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Path { cone in
                        cone.move(to: CGPoint(x: geometry.size.width * 0.9, y: 0))
                        cone.addLine(to: CGPoint(x: geometry.size.width * 0.18, y: 88))
                        cone.addLine(to: CGPoint(x: geometry.size.width * 0.84, y: 88))
                        cone.closeSubpath()
                    }
                    .fill(SeekerStyle.gold.opacity(guardAway ? 0.025 : 0.24))
                    if isHidden {
                        Path { screen in
                            screen.move(to: CGPoint(x: geometry.size.width / 2 - 42, y: 14))
                            screen.addLine(to: CGPoint(x: geometry.size.width / 2, y: 38))
                            screen.addLine(to: CGPoint(x: geometry.size.width / 2 + 42, y: 14))
                            screen.addLine(to: CGPoint(x: geometry.size.width / 2 + 42, y: 87))
                            screen.addLine(to: CGPoint(x: geometry.size.width / 2, y: 110))
                            screen.addLine(to: CGPoint(x: geometry.size.width / 2 - 42, y: 87))
                            screen.closeSubpath()
                        }
                        .fill(SeekerStyle.indigo.opacity(0.4))
                    }
                    Capsule().fill(SeekerStyle.gold.opacity(0.24)).frame(height: 4).offset(y: 53)
                    AdventureHeroSprite(stage: .thief,
                        walking: !isHidden && guardAway && (holding || Date.now.timeIntervalSince(lastStep) < 0.35),
                        facingLeft: false, height: 96)
                        .position(x: 32 + max(0, geometry.size.width - 64) * progress,
                                  y: 108 - 96 * (AdventureHeroSprite.footFraction(for: .thief) - 0.5))
                        .animation(reduceMotion ? nil : .linear(duration: 0.14), value: progress)
                        .opacity(isHidden ? 0.28 : 1)
                }
                .frame(height: 112)
            }
            .frame(height: 112).accessibilityHidden(true)
            HStack {
                Text("藏身處 · COVER")
                Spacer()
                Text(destination)
            }
            .font(.system(.caption2, design: .serif)).foregroundStyle(SeekerStyle.gold)
            Button {} label: {
                Text(holding ? "走 · MOVING" : "按住前行 · HOLD TO MOVE")
                    .frame(maxWidth: .infinity).frame(minHeight: 35)
            }
            .buttonStyle(SeekerActionStyle())
            .disabled(isHidden)
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in holding = true }
                .onEnded { _ in holding = false })
            .accessibilityLabel("Hold to move while the watchman looks away")
            .accessibilityHint("Alternatively, use Take one quiet step below.")
            Button("輕走一步 · Take one quiet step") { takeStep() }
                .buttonStyle(SeekerActionStyle(secondary: true))
                .disabled(isHidden)
                .accessibilityHint(guardAway ? "The watchman is looking away. Safe to step." : "The watchman is looking at you. Wait.")
            HStack(spacing: 12) {
                Button("帳篷藏身 · Hide · Tent") { posture.set(.tent) }
                    .buttonStyle(SeekerActionStyle(secondary: !isHidden))
                Button("展開前行 · Unfold · Move") { posture.set(.open) }
                    .buttonStyle(SeekerActionStyle(secondary: isHidden))
            }
            Text("摺法提示 · Book and Tent create a hiding screen. Open when the lantern turns away. The buttons perform the same posture changes.")
                .font(.system(.caption, design: .serif)).padding(12)
                .background(SeekerStyle.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            Text(message).font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.gold)
                .multilineTextAlignment(.center).frame(minHeight: 42)
            ProgressView(value: progress)
                .tint(SeekerStyle.gold).accessibilityLabel("Safe passage")
                .accessibilityValue("\(Int(progress * 100)) percent")
            Toggle("從容步調 · Slower patrol", isOn: $relaxed)
                .font(.system(.subheadline, design: .serif))
            Text("被發現會退回最近的藏身處，不失去銅錢。If seen, return to the last checkpoint. You lose no coins.")
                .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.ink.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(SeekerStyle.ink)
        .onAppear {
            relaxed = reduceMotion || voiceOver
            isHidden = posture.current == .book || posture.current == .tent
        }
        .onChange(of: posture.current) { _, pose in
            holding = false
            if pose == .book || pose == .tent {
                isHidden = true
                didHide = true
                foldFeedback += 1
                message = "畫卷成了屏風，身影藏在摺痕後。The scroll becomes a screen. Your silhouette rests behind the fold."
            } else if pose == .open {
                isHidden = false
                if !guardAway && progress > checkpoint + 0.01 { noticed() }
                else { message = "展開了。看清燈影，再繼續走。Open again. Watch the lantern before moving." }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: foldFeedback)
        .onChange(of: scenePhase) { _, new in if new != .active { holding = false } }
        .task {
            while !Task.isCancelled && !finished {
                do { try await Task.sleep(for: .milliseconds(80)) } catch { break }
                guard scenePhase == .active else { continue }
                elapsed += 0.08
                if !isHidden && !guardAway && progress > checkpoint + 0.01 { noticed() }
                if holding && !isHidden {
                    if guardAway { advance(by: 0.013) }
                    else { noticed() }
                }
            }
        }
    }

    private func takeStep() {
        guard !finished, !isHidden, Date.now.timeIntervalSince(lastStep) > 0.3 else { return }
        lastStep = .now
        if guardAway { advance(by: 0.13) } else { noticed() }
    }
    private func advance(by amount: Double) {
        guard !finished else { return }
        progress = min(didHide ? 1 : 0.88, progress + amount)
        checkpoint = min(0.75, floor(progress / 0.25) * 0.25)
        message = "腳步很輕，繼續留意守衛。Quietly done. Keep watching the guard."
        if progress >= 0.88 && !didHide {
            holding = false
            message = "最後一段路，要先摺起屏風藏一次。Use Book or Tent to hide once before the final stretch."
        }
        if progress >= 1 {
            finished = true
            holding = false
            onSuccess()
        }
    }
    private func noticed() {
        holding = false
        progress = checkpoint
        message = "燈照過來了！退回最近的藏身處，再試。The lantern found you. Back to your last checkpoint, then try again."
    }
}
