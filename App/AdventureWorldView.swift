import SwiftUI

struct AdventureWorldView: View {
  var game: AdventureGame
  var painting: ScrollArchive
  var isActive: Bool
  var controlsEnabled: Bool
  var onHome: () -> Void
  var posture: AdventurePostureStore
  var onSettings: () -> Void
  var onPathEditor: () -> Void
  var showControls = true
  var jumpTrigger = 0
  var lanternLit = false
  var revealProgress: Double = 1
  @State private var viewport: ClosedRange<Double> = 0.87...0.93
  @State private var facingLeft = true
  @State private var activity = 0
  @State private var awake = true
  @State private var holding = false
  @GestureState private var holdGestureActive = false
  @State private var holdEnded = Date.distantPast
  @State private var showHint = false
  @State private var showInventory = false
  @State private var segmentCaption: String?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ScrollSearchCanvas(
        archive: painting, activeTarget: nil,
        foundTargets: awakenedTargets,
        museumMode: false, hintTarget: nil, hintTrigger: 0,
        onTap: { x, _ in
          wake()
          if controlsEnabled && isActive && !holding && Date.now.timeIntervalSince(holdEnded) > 0.2 { game.walk(to: x) }
        },
        onViewportChange: { viewport = $0 },
        chapterID: game.activeActID, startX: game.heroX,
        chapterComplete: game.actComplete,
        chapterRange: 0...1,
        isActive: isActive,
        heroPosition: CGPoint(x: game.heroX, y: game.heroY),
        heroStage: game.selectedOutfit, heroWalking: game.direction != 0 && isActive,
        heroFacingLeft: facingLeft, maximumZoom: game.maximumZoom,
        missionPosition: game.currentMission.flatMap { mission in
          guard mission.trigger != .fold, let x = game.currentMissionTriggerX,
                abs(game.heroX - x) <= 0.02 else { return nil }
          return CGPoint(x: mission.x, y: mission.y)
        },
        lanternRadius: game.hintRadiusMultiplier, heroJumpTrigger: jumpTrigger, lanternLit: lanternLit,
        heroOpacity: game.heroMistOpacity, showsWalkHint: game.showsWalkHint,
        fogEnabled: posture.current == .open, revealProgress: revealProgress,
        excludedTouchRects: controlRects(in: geometry)
      )
        .simultaneousGesture(walkHoldGesture(in: geometry))

        if let segmentCaption, game.heroMistOpacity > 0.99, posture.current != .open {
          VStack(alignment: .leading, spacing: 5) {
            Text(String(segmentCaption.prefix { !$0.isWhitespace })).font(SeekerStyle.brush(28))
            Text(segmentCaption.split(maxSplits: 1, whereSeparator: { $0.isWhitespace }).dropFirst().joined())
              .font(.system(.caption, design: .serif))
          }
            .foregroundStyle(SeekerStyle.indigo)
            .shadow(color: SeekerStyle.paper.opacity(0.95), radius: 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 24).padding(.top, topInset(in: geometry) + 112)
            .transition(.opacity).allowsHitTesting(false).accessibilityHidden(true)
        }

        // Native controls sit above the canvas. The canvas excludes these edge
        // rectangles itself; transparent tap shields would steal button input.
        if showControls {
          VStack(spacing: 0) {
            HStack(alignment: .top) {
              Menu {
                Button("Home · 給娘寫信", systemImage: "house") { controlInteraction(); onHome() }
                Picker("Posture", selection: Binding(get: { posture.current }, set: { controlInteraction(); posture.set($0) })) {
                  ForEach(AdventurePosture.allCases) { value in Label(value.name, systemImage: value.symbol).tag(value) }
                }
                Button("Stop walking", systemImage: "pause") { controlInteraction() }
                Button("Settings", systemImage: "gearshape") { controlInteraction(); onSettings() }
              } label: { edgeIcon("house") }
                .accessibilityLabel("Home and posture menu")
              Spacer()
              Button { controlInteraction(); posture.set(.book) } label: {
                Label("Book", systemImage: "book.closed")
                  .font(.system(size: 11, design: .serif)).padding(.horizontal, 11).padding(.vertical, 8)
                  .background(.ultraThinMaterial, in: Capsule())
              }.accessibilityLabel("Half-open for memories")
              Spacer()
              VStack(spacing: 12) {
                Button { controlInteraction(); showInventory = true } label: { edgeIcon("bag") }
                  .accessibilityLabel("Inventory")
                Button { controlInteraction(); showHint = true } label: { edgeIcon("questionmark") }
                  .accessibilityLabel("Current objective and direction")
              }
            }
            .padding(.top, topInset(in: geometry)).padding(.horizontal, 16)
            Spacer()
            AdventureMiniMap(viewport: viewport, heroX: game.heroX)
              .padding(.horizontal, 14).padding(.bottom, max(12, geometry.safeAreaInsets.bottom + 6))
              .onLongPressGesture(minimumDuration: 2) { controlInteraction(); onPathEditor() }
              .accessibilityAction(named: "Open developer path editor") { controlInteraction(); onPathEditor() }
          }
          .foregroundStyle(SeekerStyle.indigo)
          .opacity(awake || holding ? 1 : 0.4)
          .disabled(!controlsEnabled)
          .allowsHitTesting(controlsEnabled)
          .buttonStyle(.plain)
          .zIndex(1)
        }
      }
    }
    .onChange(of: holdGestureActive) { _, active in if !active { stopHolding() } }
    .onChange(of: controlsEnabled) { _, enabled in if !enabled { stopHolding() } }
    .onChange(of: isActive) { _, active in if !active { stopHolding() } else { wake() } }
    .onDisappear { stopHolding() }
    .task(id: game.segmentTransitionCount) {
      guard game.segmentTransitionCount > 0, let name = game.lastEnteredSegmentName else { return }
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { segmentCaption = name }
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled else { return }
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) { segmentCaption = nil }
    }
    .onChange(of: game.direction) { _, direction in if direction != 0 { facingLeft = direction < 0 } }
    .onChange(of: posture.current) { _, pose in
      if pose != .open && pose != .laptop { showHint = false; showInventory = false }
    }
    .task(id: activity) {
      awake = true
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 1)) { awake = false }
    }
    .sheet(isPresented: $showHint) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text(game.currentMission?.title ?? "虹橋 · Choose your future").font(.system(.title2, design: .serif))
            Text(game.objective).font(.system(.body, design: .serif)).lineSpacing(5)
            Text("Hold the left or right half to walk. Or tap a place on the road. Xiao An follows the painted path.")
              .font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
            if game.currentMission?.trigger == .fold {
              Button("Fold and bring the bottle home") { showHint = false; onHome() }.buttonStyle(SeekerActionStyle())
            } else {
              Button("Walk toward the encounter") {
                showHint = false
                game.walk(to: game.currentMissionTriggerX ?? game.bridgeX)
              }.buttonStyle(SeekerActionStyle())
            }
          }.padding(26).frame(maxWidth: .infinity)
        }
        .background { SilkBackground().ignoresSafeArea() }
        .navigationTitle("娘的叮囑").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHint = false } } }
      }.presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showInventory) {
      NavigationStack {
        List {
          LabeledContent("Copper coins", value: "\(game.coins)")
          Section("Satchel · 行囊") {
            ForEach(game.inventory.sorted(), id: \.self) { item in
              Text(item == "soy_sauce" ? "醬油 · Soy sauce" : "空瓶 · Empty bottle")
            }
            ForEach(game.archive.gear.filter { game.ownedGear.contains($0.id) }) { gear in
              VStack(alignment: .leading, spacing: 4) { Text(gear.name); Text(gear.effect).font(.caption).foregroundStyle(.secondary) }
            }
          }
        }
        .scrollContentBackground(.hidden).background { SilkBackground().ignoresSafeArea() }
        .navigationTitle("行囊 · Inventory").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showInventory = false } } }
      }.presentationDetents([.medium, .large])
    }
  }

  private func edgeIcon(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 16, weight: .medium))
      .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
      .contentShape(Circle())
  }
  private var awakenedTargets: [ScrollTarget] {
    painting.targets.filter { game.completedMissionIDs.contains($0.id) }.map { original in
      var target = original
      if target.x < game.walkPath.minX || target.x > game.walkPath.maxX {
        target.x = min(game.walkPath.maxX, max(game.walkPath.minX, target.x))
        target.y = game.walkPath.y(atX: target.x)
      }
      return target
    }
  }

  private func walkHoldGesture(in geometry: GeometryProxy) -> some Gesture {
    LongPressGesture(minimumDuration: 0.25, maximumDistance: 12)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .updating($holdGestureActive) { value, active, _ in
        if case .second(true, _) = value { active = true }
      }
      .onChanged { value in
        guard controlsEnabled, isActive, !showHint, !showInventory,
              case .second(true, let drag?) = value,
              !controlRects(in: geometry).contains(where: { $0.contains(drag.startLocation) }) else { return }
        if !holding {
          holding = true
          wake()
          game.setDirection(drag.startLocation.x < geometry.size.width / 2 ? -1 : 1)
        }
      }
      .onEnded { _ in stopHolding() }
  }

  private func controlRects(in geometry: GeometryProxy) -> [CGRect] {
    guard showControls else { return [] }
    let top = topInset(in: geometry)
    let bottom = max(12, geometry.safeAreaInsets.bottom + 6)
    return [
      CGRect(x: 12, y: top - 4, width: 52, height: 52),
      CGRect(x: geometry.size.width / 2 - 66, y: top - 4, width: 132, height: 52),
      CGRect(x: geometry.size.width - 64, y: top - 4, width: 52, height: 108),
      CGRect(x: 0, y: geometry.size.height - bottom - 30, width: geometry.size.width, height: bottom + 30)
    ]
  }

  private func stopHolding() {
    guard holding else { return }
    holding = false
    game.setDirection(0)
    holdEnded = .now
    wake()
  }

  private func controlInteraction() {
    holding = false
    game.setDirection(0)
    holdEnded = .now
    wake()
  }
  private func wake() { activity += 1 }
  private func topInset(in geometry: GeometryProxy) -> CGFloat {
    if #available(iOS 27.1, *), let camera = geometry.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed).first {
      return max(14, min(100, camera.frame.maxY + 8))
    }
    return max(14, geometry.safeAreaInsets.top + 6)
  }
}

struct AdventureMiniMap: View {
  var viewport: ClosedRange<Double>
  var heroX: Double
  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width - 14
      Capsule().fill(.ultraThinMaterial)
      Capsule().fill(SeekerStyle.ink.opacity(0.2)).frame(height: 2).padding(.horizontal, 7).offset(y: 10)
      RoundedRectangle(cornerRadius: 2).strokeBorder(SeekerStyle.indigo.opacity(0.85), lineWidth: 1)
        .frame(width: max(6, width * (viewport.upperBound - viewport.lowerBound)), height: 12)
        .offset(x: 7 + width * viewport.lowerBound, y: 5)
      Circle().fill(SeekerStyle.red).frame(width: 6, height: 6)
        .position(x: 7 + width * heroX, y: 11)
    }
    .frame(height: 22).contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Map, Xiao An at \(Int(heroX * 100)) percent; visible \(Int(viewport.lowerBound * 100)) to \(Int(viewport.upperBound * 100)) percent. Hold two seconds to edit the road.")
  }
}

struct AdventureWalkControl: View {
  var direction: Int
  var enabled: Bool
  var change: (Int) -> Void
  var step: () -> Void
  @State private var pressing = false
  var body: some View {
    Label(direction < 0 ? "向左" : "向右", systemImage: direction < 0 ? "arrow.left" : "arrow.right")
      .font(.system(.caption, design: .serif).weight(.medium))
      .frame(maxWidth: .infinity).frame(height: 48)
      .background(pressing ? SeekerStyle.gold.opacity(0.9) : SeekerStyle.paper.opacity(0.95), in: Capsule())
      .contentShape(Capsule())
      .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
        guard enabled, !pressing else { return }
        pressing = true; change(direction)
      }.onEnded { _ in pressing = false; change(0) })
      .onChange(of: enabled) { _, value in if !value { pressing = false } }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(direction < 0 ? "Walk left toward the city" : "Walk right toward home")
      .accessibilityAddTraits(.isButton).accessibilityAction { if enabled { step() } }
  }
}

enum AdventurePainting {
  static func make(story: AdventureArchive, original: ScrollArchive) -> ScrollArchive {
    ScrollArchive(painting: original.painting, tiles: original.tiles,
      chapters: story.acts.map { act in ScrollChapter(id: act.id, title: act.name, subtitle: act.intro, xRange: [0, 1], free: act.free) },
      targets: story.acts.flatMap { act in act.missions.map { mission in
        ScrollTarget(id: mission.id, chapter: act.id, clue: "clues/\(clueID(for: mission.id) ?? "donkeys").jpg", name: mission.title, hint: mission.objective, story: mission.journalNarrative, x: mission.x, y: mission.y, seal: mission.sealName)
      } }, pixelSize: original.pixelSize)
  }
  static func clueID(for missionID: String) -> String? {
    ["m1": "donkeys", "m4": "rainbow_bridge", "a1": "scaffold_tower", "a2": "city_gate", "a3": "camels", "a4": "wine_shop_sign", "a5": "sedan_chair", "b1": "cargo_boat", "b2": "sailboat", "b3": "ox_cart", "b4": "sedan_chair", "b5": "city_gate"][missionID]
  }
}
