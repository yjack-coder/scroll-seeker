import SwiftUI

struct AdventureShadowTheaterView: View {
  var game: AdventureGame
  var posture: AdventurePostureStore
  var ending: AdventureAct? = nil
  var onContinue: (() -> Void)? = nil
  var onCricket: (() -> Void)? = nil
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var beat = 0
  @State private var replay = 0

  private var sceneAct: AdventureAct? {
    if let ending { return ending }
    for entry in game.journalEntries.reversed() {
      if let act = game.archive.acts.first(where: { $0.id == entry.actID }),
        act.missions.allSatisfy({ game.completedMissionIDs.contains($0.id) }) { return act }
    }
    return game.activeAct
  }

  private var isEnding: Bool {
    ending != nil || sceneAct?.missions.allSatisfy { game.completedMissionIDs.contains($0.id) } == true
  }

  private var captions: [String] {
    guard let act = sceneAct else {
      return ["皮影戲 · Shadow Theater", "A small life inside a great painting.", "The story is yours to unfold."]
    }
    if !isEnding {
      return [act.intro, "小安的故事才剛剛開始。\nXiao An’s story is only beginning.", "一盞燈，一段路。\nA little light, a long road ahead."]
    }
    if act.stage == .child {
      return ["一瓶醬油，帶回了家。\nA bottle of soy sauce, brought home to Mother.", "十年後 · Ten years later", act.outro ?? act.name]
    }
    return [act.intro, act.missions.last?.title ?? act.name, act.ending ?? act.name]
  }

  private var playbackID: String { "\(sceneAct?.id ?? "intro")-\(isEnding)-\(replay)" }

  var body: some View {
    VStack(spacing: 13) {
      Text("皮影戲 · SHADOW THEATER").font(.system(.caption, design: .serif)).tracking(2.2)
        .foregroundStyle(SeekerStyle.paper)
      GeometryReader { geometry in
        let width = max(1, (geometry.size.width - 14) / 2)
        HStack(spacing: 14) {
          AdventureShadowScreen(stage: sceneAct?.stage ?? .child, beat: beat, caption: captions[min(beat, captions.count - 1)],
            isEnding: isEnding, oppositeSide: false, animated: !reduceMotion && scenePhase == .active)
            .frame(width: width)
          AdventureShadowScreen(stage: sceneAct?.stage ?? .child, beat: beat, caption: captions[min(beat, captions.count - 1)],
            isEnding: isEnding, oppositeSide: true, animated: !reduceMotion && scenePhase == .active)
            .frame(width: width).rotationEffect(.degrees(180))
        }
      }
      HStack(spacing: 13) {
        Button("Replay", systemImage: "arrow.clockwise") { replay += 1 }
          .buttonStyle(.bordered).tint(SeekerStyle.paper)
        Spacer(minLength: 5)
        if let onContinue {
          Button("Continue the story", action: onContinue).buttonStyle(.borderedProminent).tint(SeekerStyle.red)
        } else {
          Button("Open to continue") { posture.set(.open) }
            .buttonStyle(.borderedProminent).tint(SeekerStyle.red)
        }
      }
      if game.canPlayCricket, let onCricket {
        Button("鬥蟋蟀 · Two-player cricket", action: onCricket)
          .font(.system(.subheadline, design: .serif)).buttonStyle(.bordered).tint(SeekerStyle.paper)
      }
    }
    .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SeekerStyle.indigo.ignoresSafeArea())
    .task(id: playbackID) {
      beat = 0
      for next in 1...2 {
        do { try await Task.sleep(for: .seconds(5.2)) } catch { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { beat = next }
      }
    }
  }
}

private struct AdventureShadowScreen: View {
  var stage: AdventureStage
  var beat: Int
  var caption: String
  var isEnding: Bool
  var oppositeSide: Bool
  var animated: Bool

  var body: some View {
    VStack(spacing: 12) {
      Text("清明影戲").font(SeekerStyle.brush(23)).foregroundStyle(SeekerStyle.ink)
      GeometryReader { geometry in
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animated)) { timeline in
          let movement = animated ? sin(timeline.date.timeIntervalSinceReferenceDate * 0.65) * 4 : 0
          ZStack(alignment: .bottom) {
            WorldPaintingCrop(center: WorldPaintingArt.point(for:
              stage == .child && beat == 0 ? "home" : stage == .thief && beat < 2 ? "grain_barge" : stage == .scholar ? "poetry_tower" : "city_gate"))
              .saturation(0).contrast(1.15).opacity(0.72)
            HStack(alignment: .bottom, spacing: 14) {
              AdventureHeroSprite(stage: stage == .child && isEnding && beat > 0 ? .scholar : stage,
                walking: animated, height: max(50, min(137, geometry.size.height * 0.57)))
                .brightness(-1).offset(x: movement)
            }.padding(.bottom, 7)
          }
          .scaleEffect(x: oppositeSide ? -1 : 1, y: 1)
        }
      }.frame(minHeight: 95)
        .accessibilityHidden(true)
      Text(caption).font(.system(.subheadline, design: .serif)).lineSpacing(4)
        .multilineTextAlignment(.center).foregroundStyle(SeekerStyle.ink)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 5) {
        ForEach(0..<3) { index in
          Capsule().fill(SeekerStyle.ink.opacity(index == beat ? 0.8 : 0.2)).frame(width: index == beat ? 18 : 5, height: 4)
        }
      }.accessibilityLabel("Scene \(beat + 1) of 3")
    }
    .padding(15).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      RoundedRectangle(cornerRadius: 8)
        .fill(.radialGradient(colors: [Color(red: 1, green: 0.93, blue: 0.72), SeekerStyle.paper, SeekerStyle.gold.opacity(0.85)], center: .center, startRadius: 5, endRadius: 310))
        .shadow(color: Color.orange.opacity(0.20), radius: 18)
    }
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold, lineWidth: 2) }
  }
}
