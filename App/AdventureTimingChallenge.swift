import SwiftUI

struct AdventureTimingChallenge: View {
    var kind: TrialKind
    var onSuccess: () -> Void
    var posture: AdventurePostureStore? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var began = Date.now
    @State private var hits = 0
    @State private var lastSuccessfulCycle = -1
    @State private var message = "等候金色區間。Wait for the gold window."
    @State private var relaxed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 0.25 : 1.0 / 30)) { timeline in
            let beat = beat(at: timeline.date)
            let ready = window.contains(beat.phase)
            Group {
                if posture?.current == .laptop && kind == .rowing {
                    AdventureLaptopLayout {
                        timingScene(phase: beat.phase, ready: ready)
                    } controls: {
                        timingControls
                    }
                } else {
                    VStack(spacing: 22) {
                        timingScene(phase: beat.phase, ready: ready)
                        timingControls
                    }
                }
            }
            .foregroundStyle(SeekerStyle.ink)
        }
        .onAppear { relaxed = reduceMotion || voiceOver }
        .sensoryFeedback(.selection, trigger: hits)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: posture?.changeCount ?? 0)
    }

    private func timingScene(phase: Double, ready: Bool) -> some View {
        VStack(spacing: 22) {
                Text(kind.instructionChinese).font(SeekerStyle.brush(25)).multilineTextAlignment(.center)
                Text(kind.instructionEnglish).font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                HStack {
                    Text("\(hits) / \(kind.required) \(kind.progressLabel)")
                    Spacer()
                    Text(ready ? "現在 · NOW" : "預備 · WAIT")
                        .fontWeight(.semibold)
                }
                .font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.gold)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SeekerStyle.indigo.opacity(0.12)).frame(height: 18)
                        Capsule().fill(SeekerStyle.gold.opacity(0.68))
                            .frame(width: geometry.size.width * (window.upperBound - window.lowerBound), height: 18)
                            .offset(x: geometry.size.width * window.lowerBound)
                        if !reduceMotion {
                            Circle().fill(SeekerStyle.indigo).frame(width: 26, height: 26)
                                .overlay { Circle().strokeBorder(SeekerStyle.paper, lineWidth: 2) }
                                .offset(x: (geometry.size.width - 26) * phase)
                        }
                    }
                    .frame(height: 30)
                }
                .frame(height: 30).accessibilityHidden(true)
                Text(ready ? kind.cue : "聽，等下一拍。Listen; wait for the next opening.")
                    .font(SeekerStyle.brush(23)).foregroundStyle(ready ? SeekerStyle.red : SeekerStyle.ink)
                    .frame(minHeight: 60).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var timingControls: some View {
        VStack(spacing: 22) {
                Button(kind.action) { attempt() }
                    .buttonStyle(SeekerActionStyle())
                    .accessibilityHint("Activate while the status says Now. \(hits) of \(kind.required) completed.")
                Text(message).font(.system(.subheadline, design: .serif))
                    .foregroundStyle(SeekerStyle.gold).multilineTextAlignment(.center).frame(minHeight: 44)
                Toggle("從容節奏 · Slower timing", isOn: $relaxed)
                    .font(.system(.subheadline, design: .serif))
                    .onChange(of: relaxed) { _, _ in began = .now; lastSuccessfulCycle = -1 }
                Text("錯過也沒關係，再試一次。No penalty for a missed beat; try again.")
                    .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.ink.opacity(0.7))
        }
    }

    private var period: Double { relaxed ? 7 : kind.period }
    private var window: ClosedRange<Double> { relaxed ? 0.25...0.8 : kind.window }
    private func beat(at date: Date) -> (phase: Double, cycle: Int) {
        let elapsed = max(0, date.timeIntervalSince(began))
        return (elapsed.truncatingRemainder(dividingBy: period) / period, Int(elapsed / period))
    }
    private func attempt() {
        guard hits < kind.required else { return }
        let current = beat(at: .now)
        guard window.contains(current.phase) else {
            message = "早了一點或晚了一點。等金色區間，再試。A little early or late. Wait for the gold window and try again."
            return
        }
        guard current.cycle != lastSuccessfulCycle else {
            message = "這一拍做得很好，等下一拍。That beat is complete. Wait for the next one."
            return
        }
        lastSuccessfulCycle = current.cycle
        hits += 1
        message = "正是時候。Well timed."
        if hits == kind.required { onSuccess() }
    }

    enum TrialKind {
        case rowing, warning, docking, purse
        var required: Int { switch self { case .rowing: 3; case .docking: 2; default: 1 } }
        var period: Double { switch self { case .rowing: 2.8; case .warning: 4; case .docking: 3.2; case .purse: 3.6 } }
        var window: ClosedRange<Double> { switch self { case .rowing: 0.39...0.64; case .warning: 0.60...0.84; case .docking: 0.38...0.70; case .purse: 0.52...0.76 } }
        var progressLabel: String { switch self { case .rowing: "次齊拉 · pulls"; case .docking: "步 · steps"; default: "次 · opening" } }
        var action: String { switch self { case .rowing: "拉！ · PULL"; case .warning: "小心橋！ · SHOUT"; case .docking: "上船 · STEP ABOARD"; case .purse: "取錢袋 · TAKE THE PURSE" } }
        var cue: String { switch self { case .rowing: "同心拉！ · Pull together!"; case .warning: "就是現在！ · Warn them now!"; case .docking: "船靠近了 · The boat is close"; case .purse: "錢袋露出來了 · The purse is within reach" } }
        var instructionChinese: String { switch self { case .rowing: "跟著船夫，齊拉三次"; case .warning: "等船夫看見你，再喊一聲"; case .docking: "等船靠近，穩穩走上兩步"; case .purse: "等轎身晃動，抓住空隙" } }
        var instructionEnglish: String { switch self { case .rowing: "Pull on three separate beats, while the marker is inside the gold window."; case .warning: "Shout while the marker is in gold—after the crew can hear you, before the boat reaches the bridge."; case .docking: "Take two steps on separate openings as the boat comes alongside."; case .purse: "Choose the instant when the sedan sways and the purse comes within reach." } }
    }
}
