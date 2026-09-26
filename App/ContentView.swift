import SwiftUI

struct ContentView: View {
  var purchases: PurchaseStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var game: AdventureGame?
  @State private var painting: ScrollArchive?
  @State private var posture = AdventurePostureStore()
  @State private var loadError: String?
  @State private var isOpen = false
  @State private var unroll = 0.0
  @State private var transitioning = false
  @State private var hasHingeData = false
  @State private var panel: AdventurePanel?
  @State private var pendingEnding: AdventureAct?
  @State private var showSettings = false
  @State private var showMembership = false
  @State private var celebrating = false
  @State private var sealingLetter = false
  @State private var dismissedFork = false
  @State private var stampCount = 0
  @State private var foldCount = 0
  @State private var jumpCount = 0
  @State private var lanternLit = false
  @State private var deckMessage: String?
  @State private var transitionTask: Task<Void, Never>?
  @State private var celebrationTask: Task<Void, Never>?
  @State private var openRequestTask: Task<Void, Never>?

  private var canWalk: Bool {
    isOpen && !transitioning && panel == nil && !showSettings && !showMembership
      && !celebrating && !sealingLetter && scenePhase == .active
      && (posture.current == .open || posture.current == .laptop)
      && (game?.activeAct?.free == true || purchases.isPro)
  }
  private var nearFork: Bool {
    guard let game else { return false }
    return game.forkUnlocked && game.activeActID == "act1" && abs(game.heroX - game.bridgeX) < 0.02
  }
  private var examIsPresented: Bool {
    if case .mission(let mission) = panel { return mission.id == "a5" }
    return false
  }

  var body: some View {
    NavigationStack {
      Group {
        if let game, let painting {
          GeometryReader { geometry in
            ZStack {
              AdventureHomeView(game: game, isPro: purchases.isPro,
                onUnfold: requestOpen, onPaywall: { showMembership = true },
                onSettings: { showSettings = true }, onChoosePath: {
                  dismissedFork = false
                  panel = .fork
                }, isVisible: !isOpen)
                .allowsHitTesting(!isOpen && !transitioning && !celebrating && !sealingLetter)
                .accessibilityHidden(isOpen)
              worldLayer(game: game, painting: painting, geometry: geometry)
                .modifier(ScrollUnrollPresentation(progress: unroll, viewportSize: geometry.size, reduceMotion: reduceMotion))
                .allowsHitTesting(isOpen && !transitioning && !celebrating && !sealingLetter)
                .accessibilityHidden(!isOpen)
              if sealingLetter { AdventureLetterView(onFinished: letterFinished).zIndex(10) }
            }
            .onChange(of: geometry.size) { old, new in
              guard !hasHingeData, abs(new.width - old.width) > 160, !transitioning else { return }
              posture.set(new.width > 600 ? .open : .folded)
            }
          }
          .ignoresSafeArea(.container, edges: isOpen ? .all : [])
          .modifier(AdventurePostureObserver(posture: posture) { hasHingeData = true })
        } else if let loadError {
          ContentUnavailableView { Text("The story could not be opened") }
            description: { Text(loadError) }
            actions: { Button("Try Again", systemImage: "arrow.clockwise", action: load) }
        } else {
          ProgressView("Opening Xiao An’s story…").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .background(SeekerStyle.paper)
      .navigationTitle(isOpen ? "" : "小安的家")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(SeekerStyle.paper, for: .navigationBar)
      .toolbar(isOpen ? .hidden : .visible, for: .navigationBar)
      .toolbar {
        if !isOpen {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Open", action: requestOpen).disabled(celebrating || sealingLetter)
              .accessibilityLabel("Unfold and resume the adventure")
          }
          ToolbarItem(placement: .topBarTrailing) {
            Picker(selection: Binding(get: { posture.current }, set: { posture.set($0) })) {
              ForEach(AdventurePosture.allCases) { value in Text(value.name).tag(value) }
            } label: { Label("Posture", systemImage: "book.closed") }
              .pickerStyle(.menu).labelStyle(.iconOnly)
          }
        }
      }
    }
    .statusBarHidden(isOpen)
    .task { if game == nil { load() } }
    .onChange(of: posture.current) { _, value in postureChanged(value) }
    .onChange(of: canWalk) { _, active in
      if active {
        game?.startWorld()
        _ = game?.beginHomeDepartureIfNeeded()
        considerFork()
      } else { game?.stopWorld() }
    }
    .task(id: game?.pendingMission?.id) {
      guard let mission = game?.pendingMission else { return }
      // Give the actual painted NPC's glow a moment before the conversation.
      if mission.trigger != .fold {
        do { try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 650)) } catch { return }
      }
      guard !Task.isCancelled, game?.pendingMission?.id == mission.id, panel == nil else { return }
      panel = .mission(mission)
    }
    .onChange(of: nearFork) { _, near in
      if near { considerFork() } else { dismissedFork = false }
    }
    .onChange(of: panel) { old, new in
      if old == .fork && new == nil { dismissedFork = true }
    }
    .onChange(of: purchases.isPro) { _, pro in
      if !pro, game?.activeAct?.free == false { posture.set(.folded) }
      if !pro { _ = game?.selectOutfit(.child, isPro: false) }
      if pro, posture.current != .folded { openWorld() }
    }
    .sensoryFeedback(.impact(weight: .heavy, intensity: 0.8), trigger: stampCount)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.35), trigger: foldCount)
    .sensoryFeedback(.selection, trigger: posture.changeCount)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.25), trigger: jumpCount)
    .sheet(isPresented: $showSettings) {
      SeekerSettingsView(purchases: purchases)
        .modifier(AdventurePostureObserver(posture: posture) { hasHingeData = true })
    }
    .sheet(isPresented: $showMembership) {
      MembershipView(purchaseStore: purchases)
        .modifier(AdventurePostureObserver(posture: posture) { hasHingeData = true })
    }
    .fullScreenCover(item: $panel, onDismiss: panelDismissed) { presentation in
      Group {
      if let game, let painting {
        switch presentation {
        case .mission(let mission):
          AdventureMissionView(mission: mission, posture: posture, onComplete: { complete(mission) }, onLeave: {
            game.dismissMission(); panel = nil
          })
        case .reward(let mission):
          AdventureRewardView(archive: game.archive, mission: mission, stage: game.selectedOutfit) {
            if let ending = pendingEnding { pendingEnding = nil; panel = .ending(ending) }
            else { panel = nil }
          }
        case .ending(let act):
          if posture.current == .tent {
            AdventureShadowTheaterView(game: game, posture: posture, ending: act, onContinue: { finishEnding(act) })
          } else {
            AdventureEndingView(act: act) { finishEnding(act) }
              .overlay(alignment: .topTrailing) {
                Button("Tent theater", systemImage: "house") { posture.set(.tent) }
                  .font(.caption).padding(16)
              }
          }
        case .fork:
          AdventureForkView(purchases: purchases, posture: posture, onChoose: { stage in
            if game.selectPath(stage, isPro: purchases.isPro) { panel = nil }
          }, onClose: { dismissedFork = true; panel = nil })
        case .pathEditor:
          AdventurePathEditorView(game: game, painting: painting) { panel = nil }
        case .cricket:
          AdventureCricketView(game: game, posture: posture) { panel = nil }
        }
      }
      }
      .modifier(AdventurePostureObserver(posture: posture) { hasHingeData = true })
    }
  }

  @ViewBuilder
  private func worldLayer(game: AdventureGame, painting: ScrollArchive, geometry: GeometryProxy) -> some View {
    ZStack {
      if posture.current == .laptop {
        VStack(spacing: 0) {
          world(game: game, painting: painting, controls: false)
            .frame(height: AdventureCrease.upperHeight(in: geometry))
          AdventureControlDeck(game: game, enabled: canWalk, talk: talk,
            use: useItem, jump: { jumpCount += 1 }, message: deckMessage,
            posture: posture, onHome: { posture.set(.folded) }, onPathEditor: { panel = .pathEditor })
        }
      } else {
        world(game: game, painting: painting, controls: true)
      }
      if posture.current == .book && panel == nil && !sealingLetter && !celebrating {
        AdventureMemoryView(game: game, painting: painting, posture: posture)
      } else if posture.current == .tent && panel == nil && !sealingLetter && !celebrating {
        AdventureShadowTheaterView(game: game, posture: posture, onCricket: game.canPlayCricket ? { panel = .cricket } : nil)
      }
    }
  }

  private func world(game: AdventureGame, painting: ScrollArchive, controls: Bool) -> some View {
    AdventureWorldView(game: game, painting: painting,
      isActive: isOpen && panel == nil && !showSettings && !showMembership && scenePhase == .active
        && (posture.current == .open || posture.current == .laptop || celebrating),
      controlsEnabled: canWalk, onHome: { posture.set(.folded) }, posture: posture,
      onSettings: { showSettings = true }, onPathEditor: { panel = .pathEditor },
      showControls: controls, jumpTrigger: jumpCount, lanternLit: lanternLit, revealProgress: unroll)
  }

  private func load() {
    do {
      let archive = try AdventureArchive.load()
      game = AdventureGame(archive: archive)
      painting = AdventurePainting.make(story: archive, original: try ScrollArchive.loadWorld())
      loadError = nil
    } catch { loadError = error.localizedDescription }
  }

  private func postureChanged(_ value: AdventurePosture) {
    game?.stopWorld()
    showSettings = false
    showMembership = false
    if value == .folded {
      openRequestTask?.cancel()
      openRequestTask = nil
      if examIsPresented { setOpen(false) }
      else if isOpen || panel != nil {
        if celebrating {
          celebrationTask?.cancel()
          celebrating = false
        }
        game?.dismissMission()
        panel = nil
        sealingLetter = true
      }
    } else {
      openWorld()
      if value == .book, nearFork, !dismissedFork, panel == nil { panel = .fork }
      if canWalk { game?.startWorld() }
    }
  }

  private func letterFinished() {
    guard sealingLetter else { return }
    _ = game?.recordLetterHome()
    sealingLetter = false
    if posture.current == .folded {
      foldHome()
      if panel == nil, let ending = pendingEnding {
        pendingEnding = nil
        panel = .ending(ending)
      }
    }
    else { openWorld() }
  }

  private func requestOpen() {
    if posture.current == .open { openWorld() }
    else { posture.set(.open) }
  }

  private func openWorld() {
    guard let game else { return }
    guard game.activeAct?.free == true || purchases.isPro else { showMembership = true; return }
    guard WorldTileStore.shared.isReady else {
      // Home remains mounted until all six tiles have been fully decoded.
      // A cold unfold must never reveal an empty placeholder or partial map.
      openRequestTask?.cancel()
      openRequestTask = Task { @MainActor in
        _ = await WorldTileStore.shared.awaitReady()
        guard !Task.isCancelled, posture.current != .folded,
          WorldTileStore.shared.isReady,
          game.activeAct?.free == true || purchases.isPro else { return }
        setOpen(true)
      }
      return
    }
    openRequestTask?.cancel()
    openRequestTask = nil
    setOpen(true)
  }

  private func foldHome() {
    guard let game else { return }
    game.stopWorld()
    panel = nil
    setOpen(false)
    if let mission = game.foldHome() { panel = .mission(mission) }
  }

  private func setOpen(_ open: Bool) {
    guard isOpen != open || transitioning else { return }
    transitionTask?.cancel()
    transitioning = !reduceMotion
    isOpen = open
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.5)) { unroll = open ? 1 : 0 }
    foldCount += 1
    if open { ScrollSound.shared.unroll() }
    transitionTask = Task { @MainActor in
      do { try await Task.sleep(for: .seconds(reduceMotion ? 0 : 1.5)) } catch { return }
      guard !Task.isCancelled else { return }
      transitioning = false
      if open { considerFork() }
    }
  }

  private func complete(_ mission: AdventureMission) {
    guard let game, game.completeMission(mission.id) else { return }
    celebrating = true
    stampCount += 1
    if game.actComplete { pendingEnding = game.activeAct; ScrollSound.shared.complete() }
    else { ScrollSound.shared.found() }
    panel = nil
    celebrationTask?.cancel()
    celebrationTask = Task { @MainActor in
      do { try await Task.sleep(for: .seconds(reduceMotion || !isOpen ? 0.35 : (game.actComplete ? 5.3 : 2.8))) }
      catch { return }
      guard !Task.isCancelled else { return }
      celebrating = false
      panel = .reward(mission)
    }
  }

  private func finishEnding(_ act: AdventureAct) {
    panel = nil
    if act.id == "act1" { posture.set(.open) }
  }

  private func panelDismissed() {
    if game?.pendingMission != nil { game?.dismissMission() }
    guard panel == nil, !celebrating, !sealingLetter else { return }
    if let ending = pendingEnding {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(200))
        if panel == nil, !celebrating, !sealingLetter, pendingEnding?.id == ending.id {
          pendingEnding = nil
          panel = .ending(ending)
        }
      }
    }
  }

  private func considerFork() {
    guard canWalk, nearFork, !dismissedFork, panel == nil else { return }
    panel = .fork
  }

  private func talk() {
    guard let game else { return }
    if nearFork { dismissedFork = false; panel = .fork }
    else if let target = game.currentMissionTriggerX, abs(game.heroX - target) < 0.008 { game.walk(to: target) }
    else { deckMessage = "走近緣字再交談 · Walk up to a marked person to talk." }
  }

  private func useItem(_ item: String?) {
    guard let game else { return }
    if item == "soy_sauce" { posture.set(.folded) }
    else if item == "lantern" || game.ownedGear.contains("lantern") {
      lanternLit.toggle()
      deckMessage = lanternLit ? "燈火亮了 · The lantern is lit." : "燈火歇了 · The lantern rests."
    } else {
      deckMessage = "行囊備好了 · Your gear is equipped. The bottle is for Mother’s errand."
    }
  }
}

private enum AdventurePanel: Identifiable, Equatable {
  case mission(AdventureMission)
  case reward(AdventureMission)
  case ending(AdventureAct)
  case fork
  case pathEditor
  case cricket
  var id: String {
    switch self {
    case .mission(let value): "mission-" + value.id
    case .reward(let value): "reward-" + value.id
    case .ending(let value): "ending-" + value.id
    case .fork: "fork"
    case .pathEditor: "path-editor"
    case .cricket: "cricket"
    }
  }
}
