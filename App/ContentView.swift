import SwiftUI

struct ContentView: View {
  var purchases: PurchaseStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var game: SeekerGame?
  @State private var loadError: String?
  @State private var inChapter = false
  @State private var isOpen = false
  @State private var unroll = 0.0
  @State private var viewport: ClosedRange<Double> = 0.94...1
  @State private var hintTarget: ScrollTarget?
  @State private var hintTrigger = 0
  @State private var feedback: SearchTapFeedback?
  @State private var pendingDiscovery: ScrollTarget?
  @State private var story: ScrollTarget?
  @State private var showCompletion = false
  @State private var showSettings = false
  @State private var showMembership = false
  @State private var museumMode = false
  @State private var stampCount = 0
  @State private var unfoldCount = 0
  @State private var discoveryTask: Task<Void, Never>?
  @State private var transitionTask: Task<Void, Never>?
  @State private var isTransitioning = false
  @State private var hasHingeData = false

  private var searching: Bool {
    inChapter && isOpen && !isTransitioning && pendingDiscovery == nil && story == nil && !showCompletion
      && !showSettings && !showMembership && scenePhase == .active
  }

  var body: some View {
    NavigationStack {
      Group {
        if let game {
          GeometryReader { geometry in
            ZStack {
              if inChapter {
                SeekerClueView(game: game) { setOpen(true) }
                  .opacity(isOpen ? 0 : 1).allowsHitTesting(!isOpen).accessibilityHidden(isOpen)
                painting(game: game, size: geometry.size)
              } else {
                SeekerHomeView(game: game, isPro: purchases.isPro, selectChapter: begin)
              }
            }
            .onChange(of: geometry.size) { old, new in
              guard inChapter, !hasHingeData, abs(new.width - old.width) > 160 else { return }
              setOpen(new.width > 600)
            }
          }
          .modifier(SeekerHingeObserver(enabled: inChapter, change: followHinge))
        } else if let loadError {
          ContentUnavailableView {
            Text("The scroll could not be opened")
          } description: { Text(loadError) } actions: {
            Button("Try Again", systemImage: "arrow.clockwise", action: load)
          }
        } else {
          ProgressView("Opening the archive…").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .background(SeekerStyle.paper)
      .navigationTitle(inChapter ? (game?.chapter?.englishName ?? "Scroll Seeker") : "")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(inChapter ? SeekerStyle.paper : SeekerStyle.indigo, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(inChapter ? .light : .dark, for: .navigationBar)
      .toolbar {
        if inChapter {
          ToolbarItem(placement: .topBarLeading) {
            Button("Chapters", systemImage: "chevron.left", action: leaveChapter)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button(isOpen ? "Folded" : "Open") { setOpen(!isOpen) }
              .accessibilityLabel(isOpen ? "Fold scroll, show clue" : "Open scroll, search painting")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Settings", systemImage: "gearshape") { showSettings = true }
            .foregroundStyle(inChapter ? SeekerStyle.indigo : SeekerStyle.paper)
            .disabled(pendingDiscovery != nil)
        }
      }
    }
    .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: stampCount)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.35), trigger: unfoldCount)
    .task { if game == nil { load() } }
    .onChange(of: searching) { _, value in game?.setSearching(value) }
    .onChange(of: purchases.isPro) { _, isPro in
      if !isPro {
        museumMode = false
        if game?.chapter?.free == false { leaveChapter() }
      }
    }
    .sheet(isPresented: $showSettings) { SeekerSettingsView(purchases: purchases) }
    .sheet(isPresented: $showMembership) { MembershipView(purchaseStore: purchases) }
    .sheet(item: $story, onDismiss: finishStory) { target in
      SeekerStoryView(target: target, isNew: pendingDiscovery != nil, chapterComplete: game?.chapterComplete ?? false) { story = nil }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showCompletion) {
      if let game {
        SeekerCompletionView(game: game) {
          showCompletion = false
          leaveChapter()
        } explore: { showCompletion = false }
          .presentationDetents([.large]).presentationDragIndicator(.visible)
      }
    }
  }

  private func painting(game: SeekerGame, size: CGSize) -> some View {
    ScrollSearchCanvas(
      archive: game.archive, activeTarget: pendingDiscovery ?? game.currentTarget,
      foundTargets: game.allFoundTargets, museumMode: museumMode && purchases.isPro,
      hintTarget: hintTarget, hintTrigger: hintTrigger, onTap: tapped,
      onViewportChange: { viewport = $0 }, feedback: feedback,
      chapterID: game.selectedChapterID ?? "river", startX: 1,
      chapterComplete: game.chapterComplete,
      chapterRange: (game.chapter?.xRange.first ?? 0.4)...(game.chapter?.xRange.last ?? 1),
      isActive: inChapter && isOpen && story == nil && !showCompletion && !showSettings && !showMembership && scenePhase == .active
    )
    .overlay(alignment: .topLeading) {
      if let target = pendingDiscovery ?? game.currentTarget {
        Button { setOpen(false) } label: {
          HStack(spacing: 10) {
            ClueArtwork(target: target).frame(width: 48, height: 48).clipShape(Circle())
              .overlay { Circle().strokeBorder(SeekerStyle.gold, lineWidth: 2) }
            VStack(alignment: .leading, spacing: 3) {
              Text(target.chineseName).font(SeekerStyle.brush(20))
              Text("\(game.foundCount) / 5 found · View clue").font(.system(.caption2, design: .serif))
            }
          }
          .padding(10).foregroundStyle(SeekerStyle.ink)
          .background(SeekerStyle.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
          .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.5), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current clue: \(target.englishName). \(game.foundCount) of 5 found. Fold to view.")
        .padding(16)
      }
    }
    .overlay(alignment: .bottom) {
      VStack(spacing: 12) {
        HStack(alignment: .bottom) {
          Button {
            if purchases.isPro { museumMode.toggle() } else { showMembership = true }
          } label: {
            Label(museumMode ? "Museum on" : "Museum", systemImage: "book.closed")
              .font(.system(.caption, design: .serif)).padding(.horizontal, 14).padding(.vertical, 13)
              .background(museumMode ? SeekerStyle.indigo : SeekerStyle.paper.opacity(0.95), in: Capsule())
              .foregroundStyle(museumMode ? SeekerStyle.paper : SeekerStyle.indigo)
          }
          .accessibilityHint("Revisit stories by tapping found seals. Requires Pro.")
          .disabled(pendingDiscovery != nil)
          Spacer()
          if game.currentTarget != nil {
            Button(action: requestHint) {
              Label(purchases.isPro ? "Hint" : "Hint · \(max(0, 1 - game.hintsUsed))", systemImage: "magnifyingglass")
                .font(.system(.caption, design: .serif)).padding(.horizontal, 16).padding(.vertical, 13)
                .foregroundStyle(SeekerStyle.paper).background(SeekerStyle.indigo, in: Capsule())
            }.disabled(pendingDiscovery != nil)
          } else {
            Button("Collected seals") { showCompletion = true }
              .font(.system(.caption, design: .serif)).padding(13)
              .background(SeekerStyle.paper, in: Capsule())
          }
        }
        SeekerMinimap(viewport: viewport, found: game.allFoundTargets)
      }.padding(.horizontal, 20).padding(.bottom, 16)
    }
    .modifier(ScrollUnrollPresentation(progress: unroll, viewportSize: size, reduceMotion: reduceMotion))
    .opacity(unroll > 0 ? 1 : 0)
    .allowsHitTesting(isOpen && !isTransitioning).accessibilityHidden(!isOpen)
  }

  private func load() {
    do { game = SeekerGame(archive: try ScrollArchive.load()); loadError = nil }
    catch { loadError = error.localizedDescription }
  }

  private func begin(_ chapter: ScrollChapter) {
    guard chapter.free || purchases.isPro else { showMembership = true; return }
    game?.startChapter(chapter)
    hintTarget = nil
    feedback = nil
    transitionTask?.cancel()
    isTransitioning = false
    inChapter = true
    isOpen = false
    unroll = 0
  }

  private func leaveChapter() {
    discoveryTask?.cancel()
    transitionTask?.cancel()
    isTransitioning = false
    game?.setSearching(false)
    inChapter = false
    isOpen = false
    unroll = 0
    pendingDiscovery = nil
    story = nil
    museumMode = false
  }

  private func setOpen(_ open: Bool) {
    guard inChapter, open != isOpen || (open && unroll < 1) || isTransitioning else { return }
    transitionTask?.cancel()
    isTransitioning = !reduceMotion
    isOpen = open
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.5)) { unroll = open ? 1 : 0 }
    unfoldCount += 1
    if open { ScrollSound.shared.unroll() }
    transitionTask = Task { @MainActor in
      do { try await Task.sleep(for: .seconds(reduceMotion ? 0 : 1.5)) } catch { return }
      guard !Task.isCancelled else { return }
      isTransitioning = false
    }
  }

  private func followHinge(_ fraction: Double, _ settled: Bool) {
    guard inChapter else { return }
    hasHingeData = true
    if settled { setOpen(fraction > 0.5) }
    else {
      transitionTask?.cancel()
      isTransitioning = true
      isOpen = fraction > 0.02
      unroll = reduceMotion ? (isOpen ? 1 : 0) : fraction
    }
  }

  private func requestHint() {
    guard let game, let target = game.requestHint(isPro: purchases.isPro) else { showMembership = true; return }
    hintTarget = target
    hintTrigger += 1
  }

  private func tapped(_ x: Double, _ y: Double) {
    guard let game, pendingDiscovery == nil else { return }
    if let target = SeekerGame.targetAt(x: x, y: y, candidates: game.currentTarget.map { [$0] } ?? []), game.find(target) {
      pendingDiscovery = target
      feedback = SearchTapFeedback(x: target.x, y: target.y, isFound: true)
      stampCount += 1
      hintTarget = nil
      if game.chapterComplete { ScrollSound.shared.complete() } else { ScrollSound.shared.found() }
      discoveryTask?.cancel()
      discoveryTask = Task { @MainActor in
        do { try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : (game.chapterComplete ? 5.3 : 2.8))) }
        catch { return }
        guard inChapter, !Task.isCancelled else { return }
        story = target
      }
    } else if let found = SeekerGame.targetAt(x: x, y: y, candidates: game.allFoundTargets) {
      if purchases.isPro { museumMode = true; story = found }
      else { showMembership = true }
    } else { feedback = SearchTapFeedback(x: x, y: y, isFound: false) }
  }

  private func finishStory() {
    let wasDiscovery = pendingDiscovery != nil
    pendingDiscovery = nil
    if wasDiscovery && game?.chapterComplete == true { showCompletion = true }
    game?.setSearching(searching)
  }
}
