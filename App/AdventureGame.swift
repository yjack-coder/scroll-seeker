import Foundation
import Observation

@MainActor
@Observable
final class AdventureGame {
  let archive: AdventureArchive
  var walkPath: AdventureWalkPath
  private(set) var heroX: Double
  private(set) var activeActID: String
  private(set) var selectedOutfit: AdventureStage
  private(set) var completedMissionIDs: Set<String>
  private(set) var coins: Int
  private(set) var inventory: Set<String>
  private(set) var ownedGear: Set<String>
  private(set) var titles: Set<String>
  private(set) var journalEntries: [AdventureJournalEntry]
  private(set) var letters: [AdventureLetter]
  private(set) var lastMotherReply: String
  private(set) var rewardedCricketRounds: Set<UUID>
  private(set) var pendingMission: AdventureMission?
  private(set) var isWorldActive = false
  private(set) var direction = 0
  private(set) var segmentTransitionCount = 0
  private(set) var lastEnteredSegmentName: String?
  private(set) var isDepartingHome = false
  private(set) var showsWalkHint = false
  private var settledSegmentID: String?
  private var hasSeenHomeDeparture = false
  private var unlockedStages: Set<AdventureStage>

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private var ticker: Task<Void, Never>?
  @ObservationIgnored private var lastTick: Date?
  @ObservationIgnored private var destination: Double?
  @ObservationIgnored private var suppressedMissionID: String?
  @ObservationIgnored private var secondsSinceSave: TimeInterval = 0
  private static let persistenceKey = "scrollseeker.adventure.v1.state"
  static let missionRadius = 0.02

  init(
    archive: AdventureArchive,
    defaults: UserDefaults = .standard,
    now: @escaping () -> Date = Date.init,
    walkPath: AdventureWalkPath? = nil
  ) {
    self.archive = archive
    self.defaults = defaults
    self.now = now
    self.walkPath = walkPath ?? AdventureWalkPath(defaults: defaults)
    let saved = defaults.data(forKey: Self.persistenceKey).flatMap {
      try? JSONDecoder().decode(SavedAdventure.self, from: $0)
    }
    hasSeenHomeDeparture = saved?.hasSeenHomeDeparture ?? false
    let sameWorld = archive.world == nil || saved?.worldVersion == archive.world?.geometryVersion
    heroX = sameWorld && saved?.heroX.isFinite == true ? min(1, max(0, saved!.heroX)) : archive.home.x
    activeActID = archive.acts.first { $0.id == saved?.activeActID }?.id ?? "act1"
    completedMissionIDs = (saved?.completedMissionIDs ?? []).intersection(Set(archive.allMissions.map(\.id)))
    coins = max(0, saved?.coins ?? 10)
    inventory = saved?.inventory ?? ["empty_bottle"]
    ownedGear = (saved?.ownedGear ?? []).intersection(Set(archive.gear.map(\.id)))
    titles = saved?.titles ?? []
    journalEntries = (saved?.journalEntries ?? []).map { savedEntry in
      var entry = savedEntry
      if let mission = archive.mission(entry.missionID) { entry.body = mission.journalNarrative }
      return entry
    }
    letters = saved?.letters ?? []
    lastMotherReply = saved?.lastMotherReply ?? saved?.letters?.last?.reply
      ?? "路上慢慢走，娘在家等你。 / Take your time on the road. Mother is waiting at home."
    rewardedCricketRounds = saved?.rewardedCricketRounds ?? []
    let restoredStages = (saved?.unlockedStages ?? []).union([.child])
    unlockedStages = restoredStages
    selectedOutfit = saved.map { restoredStages.contains($0.selectedOutfit) ? $0.selectedOutfit : .child } ?? .child
    heroX = boundedX(heroX)
    settledSegmentID = currentSegment?.id
    save()
  }

  var heroY: Double { walkPath.y(atX: heroX) }
  var resumeX: Double { heroX }
  var world: AdventureWorldArchive? { archive.world }
  var bridgeX: Double { world?.bridgeX ?? 0.495 }
  func pathStart(for stage: AdventureStage) -> Double { world?.pathStart(for: stage) ?? 0.495 }
  var mistSpeedMultiplier: Double { 1 + 0.2 * (world?.mistIntensity(at: heroX) ?? 0) }
  var heroMistOpacity: Double { 1 - 0.6 * (world?.mistIntensity(at: heroX) ?? 0) }
  var activeAct: AdventureAct? { archive.acts.first { $0.id == activeActID } }
  var stage: AdventureStage { activeAct?.stage ?? .child }
  var currentMission: AdventureMission? {
    activeAct?.missions.first { !completedMissionIDs.contains($0.id) }
  }
  var currentMissionTriggerX: Double? { currentMission.map { boundedX($0.x) } }
  var actComplete: Bool { activeAct?.missions.isEmpty == false && currentMission == nil }
  var forkUnlocked: Bool {
    archive.acts.first { $0.id == "act1" }?.missions.allSatisfy { completedMissionIDs.contains($0.id) } ?? false
  }
  var currentSegment: AdventureSegment? {
    if let panel = world?.segment(at: heroX)?.panel { return archive.segments.first { $0.id == panel } }
    return archive.segments.first {
      guard let lower = $0.xRange.first, let upper = $0.xRange.last else { return false }
      return (lower...upper).contains(heroX)
    }
  }
  var objective: String {
    if let mission = currentMission { return mission.objective }
    if activeActID == "act1" { return "Return to Rainbow Bridge and choose the life Xiao An will lead." }
    return activeAct?.ending ?? "A story to carry home."
  }
  var objectiveDirection: Int {
    if currentMission == nil, forkUnlocked, activeActID == "act1" {
      return abs(bridgeX - heroX) <= Self.missionRadius ? 0 : (bridgeX < heroX ? -1 : 1)
    }
    guard let mission = currentMission, mission.trigger != .fold, let triggerX = currentMissionTriggerX else { return 0 }
    return abs(triggerX - heroX) <= Self.missionRadius ? 0 : (triggerX < heroX ? -1 : 1)
  }
  var unlockedOutfits: [AdventureStage] { AdventureStage.allCases.filter { unlockedStages.contains($0) } }
  var walkSpeed: Double {
    if ownedGear.contains("cloth_boots") { return 0.040 }
    if ownedGear.contains("straw_sandals") { return 0.032 }
    return 0.025
  }
  var maximumZoom: Double { ownedGear.contains("magnifier") ? 6 : 4 }
  var hintRadiusMultiplier: Double { ownedGear.contains("lantern") ? 1.6 : 1 }
  var completedMissions: [AdventureMission] {
    archive.allMissions.filter { completedMissionIDs.contains($0.id) }
  }
  var canPlayCricket: Bool {
    currentSegment?.id == "Panel6" && activeAct?.free == false && stage != .child
  }

  /// The reveal never moves between scenes. Every ordinary fold/unfold resumes
  /// the same world coordinate; the only scripted walk is this first departure.
  /// Call after the roller has fully opened, so the first steps are visible.
  @discardableResult
  func beginHomeDepartureIfNeeded() -> Bool {
    guard isWorldActive, pendingMission == nil, !hasSeenHomeDeparture,
      activeActID == "act1", completedMissionIDs.isEmpty,
      abs(heroX - archive.home.x) < 0.002 else { return false }
    hasSeenHomeDeparture = true
    isDepartingHome = true
    showsWalkHint = false
    destination = boundedX(heroX - 0.009)
    direction = -1
    save()
    return true
  }

  @discardableResult
  func recordCricketWin(roundID: UUID, winner: Int) -> Bool {
    guard canPlayCricket, (1...2).contains(winner), !rewardedCricketRounds.contains(roundID) else { return false }
    rewardedCricketRounds.insert(roundID)
    coins += 5
    save()
    return true
  }

  func ownsGear(_ id: String) -> Bool { ownedGear.contains(id) }
  func isStageUnlocked(_ stage: AdventureStage) -> Bool { unlockedStages.contains(stage) }
  func canSelectOutfit(_ stage: AdventureStage, isPro: Bool) -> Bool {
    unlockedStages.contains(stage) && (stage == .child || isPro)
  }

  @discardableResult
  func selectOutfit(_ stage: AdventureStage, isPro: Bool) -> Bool {
    guard canSelectOutfit(stage, isPro: isPro) else { return false }
    selectedOutfit = stage
    save()
    return true
  }

  @discardableResult
  func selectPath(_ stage: AdventureStage, isPro: Bool) -> Bool {
    guard stage != .child, forkUnlocked, isPro, let act = archive.act(for: stage) else { return false }
    stopWorld()
    activeActID = act.id
    unlockedStages.insert(stage)
    selectedOutfit = stage
    heroX = boundedX(pathStart(for: stage))
    settledSegmentID = currentSegment?.id
    pendingMission = nil
    suppressedMissionID = nil
    save()
    return true
  }

  @discardableResult
  func buyGear(_ id: String, isPro: Bool) -> Bool {
    guard let gear = archive.gear.first(where: { $0.id == id }), !ownedGear.contains(id),
      !gear.isPro || isPro, let cost = gear.cost, cost > 0, coins >= cost else { return false }
    coins -= cost
    ownedGear.insert(id)
    save()
    return true
  }

  func startWorld() {
    guard !isWorldActive else { return }
    isWorldActive = true
    lastTick = now()
    ticker = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
        guard !Task.isCancelled, self != nil else { break }
        self?.advanceClock()
      }
    }
  }

  func stopWorld() {
    isWorldActive = false
    if isDepartingHome { showsWalkHint = true }
    isDepartingHome = false
    direction = 0
    destination = nil
    ticker?.cancel()
    ticker = nil
    lastTick = nil
    save()
  }

  func setDirection(_ value: Int) {
    guard pendingMission == nil else { return }
    if value != 0 { acknowledgeWalking() }
    else if isDepartingHome { return }
    direction = value == 0 ? 0 : (value < 0 ? -1 : 1)
    destination = nil
    if direction != 0 { suppressedMissionID = nil }
    else { save() }
  }

  func walk(to x: Double) {
    guard x.isFinite, pendingMission == nil else { return }
    acknowledgeWalking()
    destination = boundedX(x)
    direction = destination! == heroX ? 0 : (destination! < heroX ? -1 : 1)
    suppressedMissionID = nil
    if direction == 0, let mission = currentMission, mission.trigger != .fold, let triggerX = currentMissionTriggerX,
      abs(triggerX - heroX) <= Self.missionRadius {
      pendingMission = mission
      destination = nil
    }
  }

  /// Called by the internal clock; exposed so movement and crossing are testable
  /// without real-time delays or a simulator.
  func tick(delta: TimeInterval) {
    guard isWorldActive, pendingMission == nil, direction != 0, delta.isFinite, delta > 0 else { return }
    let previousX = heroX
    let speed = isDepartingHome ? 0.00625 : walkSpeed * mistSpeedMultiplier
    var nextX = boundedX(heroX + Double(direction) * speed * delta)
    if let destination {
      nextX = direction < 0 ? max(destination, nextX) : min(destination, nextX)
    }
    if let mission = currentMission, mission.trigger != .fold, mission.id != suppressedMissionID,
      let triggerX = currentMissionTriggerX,
      (min(previousX, nextX) - Self.missionRadius...max(previousX, nextX) + Self.missionRadius).contains(triggerX) {
      // Entering the generous encounter radius must not teleport the hero to
      // the NPC. Only a step which actually crosses its x is clamped there.
      let crossed = (min(previousX, nextX)...max(previousX, nextX)).contains(triggerX)
      heroX = crossed ? triggerX : nextX
      updateSegmentArrival()
      pendingMission = mission
      direction = 0
      destination = nil
      save()
      return
    }
    heroX = nextX
    updateSegmentArrival()
    if nextX == previousX || nextX == destination {
      direction = 0
      destination = nil
      if isDepartingHome { isDepartingHome = false; showsWalkHint = true }
    }
    secondsSinceSave += delta
    if secondsSinceSave >= 1 || direction == 0 { save() }
  }

  func dismissMission() {
    suppressedMissionID = pendingMission?.id
    pendingMission = nil
    direction = 0
    destination = nil
  }

  /// A sealed letter is a memory, never another mission completion or reward.
  @discardableResult
  func recordLetterHome() -> AdventureLetter {
    let recentMission = journalEntries.last.flatMap { archive.mission($0.missionID) }
    let body: String
    if let recentMission {
      body = "娘，我想告訴您：\(recentMission.chineseName)。\nMother, a small story from the road: \(recentMission.journalNarrative)"
    } else {
      let place = currentSegment
      body = "娘，我走到了\(place?.chineseName ?? "路上")，會記得回家的路。\nMother, I am at \(place?.englishName ?? "the beginning of the road"). \(objective)"
    }
    let reply = motherReply(after: recentMission?.id)
    let letter = AdventureLetter(id: UUID(), date: now(), body: body, reply: reply, missionID: recentMission?.id)
    letters.append(letter)
    lastMotherReply = reply
    save()
    return letter
  }

  @discardableResult
  func foldHome() -> AdventureMission? {
    stopWorld()
    pendingMission = nil
    guard let mission = currentMission, mission.trigger == .fold,
      completedMissionIDs.contains("m5"), inventory.contains("soy_sauce") else { return nil }
    pendingMission = mission
    return mission
  }

  @discardableResult
  func completeMission(_ id: String) -> Bool {
    guard let mission = currentMission, mission.id == id, pendingMission?.id == id,
      !completedMissionIDs.contains(id) else { return false }
    if mission.trigger == .fold {
      guard completedMissionIDs.contains("m5"), inventory.contains("soy_sauce") else { return false }
      inventory.remove("soy_sauce")
    }
    completedMissionIDs.insert(id)
    coins += max(0, mission.reward.coins ?? 0)
    if let gear = mission.reward.gear { ownedGear.insert(gear) }
    if let item = mission.reward.item {
      if item == "soy_sauce" { inventory.remove("empty_bottle") }
      inventory.insert(item)
    }
    if let title = mission.reward.title { titles.insert(title) }
    journalEntries.append(AdventureJournalEntry(
      id: id, missionID: id, actID: activeActID, title: mission.title,
      body: mission.journalNarrative, date: now()
    ))
    pendingMission = nil
    direction = 0
    destination = nil
    suppressedMissionID = nil
    save()
    return true
  }

  private func boundedX(_ x: Double) -> Double {
    min(walkPath.maxX, max(walkPath.minX, x))
  }

  private func acknowledgeWalking() {
    isDepartingHome = false
    showsWalkHint = false
    hasSeenHomeDeparture = true
  }

  private func updateSegmentArrival() {
    guard (world?.mistIntensity(at: heroX) ?? 0) == 0,
      let segment = currentSegment, segment.id != settledSegmentID else { return }
    settledSegmentID = segment.id
    lastEnteredSegmentName = segment.name
    segmentTransitionCount += 1
  }

  @discardableResult
  func saveWalkPath(points: [AdventurePathPoint]) -> Bool {
    guard walkPath.save(points: points) else { return false }
    stopWorld()
    heroX = boundedX(heroX)
    save()
    return true
  }

  func reloadWalkPath() {
    stopWorld()
    walkPath.reload()
    heroX = boundedX(heroX)
    save()
  }

  private func motherReply(after missionID: String?) -> String {
    switch missionID {
    case "m1": "聽說你幫炭翁找回了驢兒？心善的孩子，路也會善待你。 / You helped the charcoal seller with his donkeys? A kind heart makes the road kinder."
    case "m2": "肯問路，就不怕路遠。記得謝謝那些旅人。 / When you are willing to ask, no road is too long. Remember to thank the travelers."
    case "m_paperboat": "一隻小船也能載好大的心願。謝謝你陪那孩子。 / A little boat can carry a very big wish. Thank you for keeping that child company."
    case "m3": "聽說你幫了船夫？娘很驕傲。 / I heard you helped the boatmen. Mother is proud."
    case "m4": "虹橋上的那一聲，救了多少人的心。安兒，你很勇敢。 / Your warning at the bridge spared so many worried hearts. You were brave, An."
    case "m5": "醬油買好了？慢慢走，穩穩拿，娘不急。 / You have the soy sauce? Walk slowly and hold it steady. Mother can wait."
    case "m6": "醬油是甜是鹹，都不及你平安回家。 / Sweet or salty, the sauce matters less than seeing you home safely."
    case "a5": "金榜上有你的名字，娘心裡一直有你。 / Your name is on the imperial list. It has always had a place in Mother’s heart."
    case "b5": "街坊吃飽了，娘就知道你沒忘了善良。 / The neighbors have eaten well. Mother knows you have not forgotten kindness."
    case "a1", "a2", "a3", "a4": "書要用心讀，路也要用心走。娘信你。 / Read with care, and walk with care. Mother believes in you."
    case "b1", "b2", "b3", "b4": "幫別人，也要顧好自己。夜深了，記得回家。 / Care for others, and take care of yourself. When night falls, remember home."
    default: "第一步也值得寫成一封信。別著急，娘一直在家等你。 / Even a first step is worth a letter. Do not hurry; Mother is waiting at home."
    }
  }

  private func advanceClock() {
    let instant = now()
    defer { lastTick = instant }
    guard let lastTick else { return }
    tick(delta: min(0.1, max(0, instant.timeIntervalSince(lastTick))))
  }

  private func save() {
    secondsSinceSave = 0
    let state = SavedAdventure(
      heroX: heroX, activeActID: activeActID, selectedOutfit: selectedOutfit,
      completedMissionIDs: completedMissionIDs, coins: coins, inventory: inventory,
      ownedGear: ownedGear, titles: titles, journalEntries: journalEntries,
      unlockedStages: unlockedStages, letters: letters, lastMotherReply: lastMotherReply,
      rewardedCricketRounds: rewardedCricketRounds,
      worldVersion: archive.world?.geometryVersion,
      hasSeenHomeDeparture: hasSeenHomeDeparture
    )
    if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.persistenceKey) }
  }

  private struct SavedAdventure: Codable {
    var heroX: Double
    var activeActID: String
    var selectedOutfit: AdventureStage
    var completedMissionIDs: Set<String>
    var coins: Int
    var inventory: Set<String>
    var ownedGear: Set<String>
    var titles: Set<String>
    var journalEntries: [AdventureJournalEntry]
    var unlockedStages: Set<AdventureStage>
    // Optional for backward compatibility with saves made before letters existed.
    var letters: [AdventureLetter]?
    var lastMotherReply: String?
    var rewardedCricketRounds: Set<UUID>?
    var worldVersion: String?
    var hasSeenHomeDeparture: Bool?
  }
}

struct AdventureJournalEntry: Identifiable, Codable, Hashable {
  var id: String
  var missionID: String
  var actID: String
  var title: String
  var body: String
  var date: Date
}

struct AdventureLetter: Identifiable, Codable, Hashable {
  var id: UUID
  var date: Date
  var body: String
  var reply: String
  var missionID: String?
}
