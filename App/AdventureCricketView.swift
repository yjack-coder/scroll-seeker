import SwiftUI

struct AdventureCricketView: View {
  var game: AdventureGame
  var posture: AdventurePostureStore
  var onClose: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var roundID = UUID()
  @State private var lead = 0
  @State private var winner: Int?
  @State private var rewardGranted = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        AdventureCricketHeader(posture: posture, lead: lead, winner: winner, rewardGranted: rewardGranted)
        AdventureCricketSides(lead: lead, winner: winner, enabled: game.canPlayCricket) { cheer(player: $0) }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if winner != nil {
          Button("再來一局 · Rematch", systemImage: "arrow.clockwise", action: rematch)
            .buttonStyle(.borderedProminent).tint(SeekerStyle.indigo)
            .controlSize(.large)
            .disabled(!game.canPlayCricket)
        }
        if !game.canPlayCricket {
          Text("The cricket table awaits in the Capital on either grown-up path.")
            .font(.footnote).foregroundStyle(SeekerStyle.ink).multilineTextAlignment(.center)
        }
      }
      .padding(16)
      .background { SilkBackground().ignoresSafeArea() }
      .foregroundStyle(SeekerStyle.indigo)
      .navigationTitle("鬥蟋蟀 · Cricket Table")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark", action: onClose)
        }
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: lead)
    .sensoryFeedback(.selection, trigger: lead)
    .sensoryFeedback(.success, trigger: winner)
  }

  private func cheer(player: Int) {
    guard winner == nil, game.canPlayCricket else { return }
    lead += player == 1 ? 1 : -1
    if abs(lead) >= 12 {
      let winningPlayer = lead > 0 ? 1 : 2
      winner = winningPlayer
      rewardGranted = game.recordCricketWin(roundID: roundID, winner: winningPlayer)
    }
  }

  private func rematch() {
    roundID = UUID()
    lead = 0
    winner = nil
    rewardGranted = false
  }
}

private struct AdventureCricketHeader: View {
  var posture: AdventurePostureStore
  var lead: Int
  var winner: Int?
  var rewardGranted: Bool

  var body: some View {
    VStack(spacing: 9) {
      if let winner {
        Text("Player \(winner) wins")
          .font(.system(.title3, design: .serif).weight(.semibold))
        Text(rewardGranted ? "+5 copper coins for Xiao An" : "This round is complete")
          .font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.red)
      } else {
        Text("Face each other. Cheer your cricket to a lead of 12.")
          .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
      }
      AdventureCricketLeadTrack(lead: lead)
        .frame(height: 24)
      HStack(spacing: 12) {
        Button("Set Tent", systemImage: AdventurePosture.tent.symbol) { posture.set(.tent) }
          .disabled(posture.current == .tent)
        Button("Lay Open", systemImage: AdventurePosture.open.symbol) { posture.set(.open) }
          .disabled(posture.current == .open)
      }
      .buttonStyle(.bordered).controlSize(.small).tint(SeekerStyle.indigo)
      Text("No clock. One cheer per tap. Both players share this screen.")
        .font(.caption).foregroundStyle(SeekerStyle.ink.opacity(0.8))
        .multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .contain)
  }
}

private struct AdventureCricketSides: View {
  var lead: Int
  var winner: Int?
  var enabled: Bool
  var cheer: (Int) -> Void

  var body: some View {
    GeometryReader { geometry in
      let layout = geometry.size.width > geometry.size.height * 1.2
        ? AnyLayout(HStackLayout(spacing: 16))
        : AnyLayout(VStackLayout(spacing: 16))
      layout {
        AdventureCricketPlayer(player: 2, lead: -lead, winner: winner, enabled: enabled) { cheer(2) }
          .rotationEffect(.degrees(180))
        AdventureCricketPlayer(player: 1, lead: lead, winner: winner, enabled: enabled) { cheer(1) }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct AdventureCricketPlayer: View {
  var player: Int
  var lead: Int
  var winner: Int?
  var enabled: Bool
  var cheer: () -> Void

  private var accent: Color { player == 1 ? SeekerStyle.indigo : SeekerStyle.red }

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        HStack {
          Text("Player \(player)").font(.system(.headline, design: .serif))
          Spacer()
          Text(player == 1 ? "青翅 · Jade Wing" : "金將 · Golden General")
            .font(.system(.caption, design: .serif))
        }
        AdventureCricketDrawing(ink: accent)
          .frame(height: 92).frame(maxWidth: .infinity)
          .accessibilityHidden(true)
        Text(winner == player ? "勝 · Victory" : winner != nil ? "A worthy match" : lead == 0 ? "Evenly matched" : lead > 0 ? "Ahead by \(lead)" : "Behind by \(-lead)")
          .font(.system(.subheadline, design: .serif)).monospacedDigit()
        Button(action: cheer) {
          Text("助威 · Cheer")
            .font(.system(.title3, design: .serif).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(SeekerStyle.paper)
            .background(accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(AdventureCricketCheerStyle())
        .disabled(winner != nil || !enabled)
        .opacity(winner == nil && enabled ? 1 : 0.55)
        .accessibilityLabel("Player \(player), cheer your cricket")
        .accessibilityHint("Adds one cheer toward a lead of twelve. There is no time limit.")
        .accessibilityValue(lead == 0 ? "Even score" : "Lead \(lead)")
      }
      .padding(15).frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SeekerStyle.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.28), lineWidth: 1) }
    .accessibilityElement(children: .contain)
  }
}

private struct AdventureCricketLeadTrack: View {
  var lead: Int

  var body: some View {
    HStack(spacing: 8) {
      Text("P2").font(.caption.weight(.semibold))
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(SeekerStyle.gold.opacity(0.28)).frame(height: 6)
          Rectangle().fill(SeekerStyle.ink.opacity(0.3)).frame(width: 1, height: 16)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
          Circle().fill(SeekerStyle.red).frame(width: 13, height: 13)
            .position(x: 7 + (geometry.size.width - 14) * CGFloat(lead + 12) / 24, y: geometry.size.height / 2)
        }.frame(maxHeight: .infinity)
      }
      Text("P1").font(.caption.weight(.semibold))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Cricket match lead")
    .accessibilityValue(lead == 0 ? "Even" : "Player \(lead > 0 ? 1 : 2) leads by \(abs(lead)) of twelve")
  }
}

private struct AdventureCricketDrawing: View {
  var ink: Color

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 250, size.height / 100)
      let origin = CGPoint(x: (size.width - 250 * scale) / 2, y: (size.height - 100 * scale) / 2)
      func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
      }
      func line(_ coordinates: [(CGFloat, CGFloat)], width: CGFloat = 1.8) {
        var path = Path()
        for (index, coordinate) in coordinates.enumerated() {
          if index == 0 { path.move(to: point(coordinate.0, coordinate.1)) }
          else { path.addLine(to: point(coordinate.0, coordinate.1)) }
        }
        context.stroke(path, with: .color(ink.opacity(0.88)), style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
      }
      let abdomen = CGRect(x: point(65, 36).x, y: point(65, 36).y, width: 93 * scale, height: 29 * scale)
      context.fill(Path(ellipseIn: abdomen), with: .color(ink.opacity(0.76)))
      context.stroke(Path(ellipseIn: abdomen), with: .color(ink), lineWidth: 1.5 * scale)
      context.fill(Path(ellipseIn: CGRect(x: point(151, 31).x, y: point(151, 31).y, width: 32 * scale, height: 32 * scale)), with: .color(ink))
      context.fill(Path(ellipseIn: CGRect(x: point(176, 34).x, y: point(176, 34).y, width: 5 * scale, height: 5 * scale)), with: .color(SeekerStyle.gold))
      line([(71, 41), (126, 48), (151, 43)], width: 1)
      line([(83, 49), (121, 23), (142, 75), (171, 88)], width: 2.5)
      line([(93, 54), (66, 71), (39, 88)], width: 2)
      line([(134, 54), (155, 76), (183, 81)])
      line([(145, 48), (179, 64), (203, 65)])
      line([(170, 34), (197, 12), (232, 9)], width: 1)
      line([(175, 40), (210, 24), (242, 26)], width: 1)
      line([(69, 50), (43, 46), (25, 36)], width: 1)
    }
  }
}

private struct AdventureCricketCheerStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
  }
}
