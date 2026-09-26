import Foundation

@main
@MainActor
struct AdventureWorldChecks {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      precondition(condition(), message)
      checks += 1
    }
    let storyURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Resources/Qingming/story.json")
    let worldURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "App/Resources/World/world.json")
    let originalWorld = try Data(contentsOf: worldURL)
    let originalStory = try Data(contentsOf: storyURL)
    let world = try AdventureWorldArchive.load(from: worldURL)
    let archive = try AdventureArchive.load(from: storyURL, worldURL: worldURL)
    let suppliedMetadata = try JSONSerialization.jsonObject(with: originalWorld) as! [String: Any]
    let suppliedSize = suppliedMetadata["size"] as! [Double]
    let suppliedWalkpath = suppliedMetadata["walkpath"] as! [[Double]]
    check(world.size == suppliedSize && world.walkpath == suppliedWalkpath, "Latest teammate world geometry loads exactly")
    check(world.segments.count == 6 && world.places.count == 13, "All six scenes and thirteen landmarks load")
    check(AdventureWorldArchive.mistCenters == [0.188, 0.344, 0.5, 0.656, 0.812], "Mist matches the latest five scene joins")
    var changedGeometry = world
    changedGeometry.walkpath[3][1] += 0.001
    check(world.geometryVersion != changedGeometry.geometryVersion, "Changing even one road point invalidates historical path overrides")
    let reloadedWorld = try AdventureWorldArchive.load(from: worldURL)
    check(world.geometryVersion == reloadedWorld.geometryVersion, "World identity is stable across loads")
    let suite = "scrollseeker.worldchecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let legacySuite = suite + ".legacy"
    let legacyDefaults = UserDefaults(suiteName: legacySuite)!
    let smoothSuite = suite + ".smooth"
    let smoothDefaults = UserDefaults(suiteName: smoothSuite)!
    defer {
      defaults.removePersistentDomain(forName: suite)
      legacyDefaults.removePersistentDomain(forName: legacySuite)
      smoothDefaults.removePersistentDomain(forName: smoothSuite)
    }
    let legacyPath = Data("{\"points\":[[0.9,0.1],[0.03,0.2]]}".utf8)
    defaults.set(legacyPath, forKey: "scrollseeker.adventure.v1.walkpath")
    defaults.set(legacyPath, forKey: "scrollseeker.adventure.world1.walkpath")
    let path = AdventureWalkPath(defaults: defaults, sourceURL: worldURL)
    check(path.points.count == world.walkpath.count && path.y(atX: archive.home.x) == 0.64, "Historical path overrides cannot distort the new world")
    let game = AdventureGame(archive: archive, defaults: defaults, walkPath: path)
    let smoothGame = AdventureGame(archive: archive, defaults: smoothDefaults, walkPath: AdventureWalkPath(defaults: smoothDefaults, sourceURL: worldURL))
    let firstEncounter = smoothGame.currentMission!.x
    let approachDistance = smoothGame.heroX - firstEncounter - 0.019
    smoothGame.startWorld()
    smoothGame.setDirection(-1)
    smoothGame.tick(delta: approachDistance / smoothGame.walkSpeed)
    check(smoothGame.pendingMission?.id == "m1", "Entering the generous radius opens the nearby encounter")
    check(abs(smoothGame.heroX - (firstEncounter + 0.019)) < 0.000001, "Encounter stops at the actual walking position without a two-percent jump")
    check(smoothGame.heroY == smoothGame.walkPath.y(atX: smoothGame.heroX), "Encounter feet remain on the traced road")
    smoothGame.stopWorld()
    check(game.heroX == world.homeX && game.heroY == 0.64, "New game begins at the new home with feet on the road")
    check(game.bridgeX == world.places["rainbow_bridge"]!.x, "Bridge fork is driven by metadata")
    check(game.pathStart(for: .scholar) == world.places["tea_house"]!.x && game.pathStart(for: .thief) == world.places["grain_barge"]!.x, "Life paths start at their named places")
    game.startWorld()
    check(game.heroX == world.homeX, "Opening cannot skip unfinished home quest")
    func finish(_ id: String) {
      precondition(game.currentMission?.id == id)
      if game.currentMission?.trigger == .fold { _ = game.foldHome() }
      else {
        game.startWorld()
        game.walk(to: game.currentMission!.x)
        game.tick(delta: 100)
      }
      check(game.completeMission(id), "Complete scene " + id)
    }
    finish("m1")
    let villageX = game.heroX
    _ = game.foldHome()
    game.startWorld()
    check(game.heroX == villageX && game.currentSegment?.id == world.segments.first!.panel, "Completed village still resumes without a scene teleport")
    check(game.heroX > archive.mission("m2")!.x && game.direction == 0, "Unfolding waits before the next encounter")
    let advancedX = game.heroX
    game.startWorld()
    check(game.heroX == advancedX, "Repeated open samples cannot advance another scene")
    finish("m2")
    _ = game.foldHome()
    let afterDirections = game.heroX
    game.startWorld()
    check(game.heroX == afterDirections, "Unfold cannot skip the unfinished paper boat")
    finish("m_paperboat")
    check(game.coins == 23 && archive.mission("m_paperboat")!.sealName == "紙船", "Paper boat awards five copper and its own seal exactly once")
    check(!game.completeMission("m_paperboat") && game.coins == 23, "Paper boat reward cannot repeat")
    let willowX = game.heroX
    _ = game.foldHome()
    game.startWorld()
    check(game.heroX == willowX && game.currentSegment?.id == "Panel2", "Completed willow scene still resumes at the exact paper boat spot")
    check(game.segmentTransitionCount > 0 && game.lastEnteredSegmentName == world.segments[1].name, "Walking arrival exposes the new scene name after mist")
    finish("m3")
    finish("m4")
    let riverX = game.heroX
    _ = game.foldHome()
    game.startWorld()
    check(game.heroX == riverX, "Completed river scene resumes without snapping to the market")
    finish("m5")
    let beforeFold = game.heroX
    check(game.foldHome()?.id == "m6" && game.heroX == beforeFold, "Home delivery preserves exact world resume position")
    check(game.completeMission("m6"), "Fold delivery completes the expanded childhood")
    check(game.forkUnlocked && game.completedMissionIDs.count == 7, "Life fork includes the paper boat quest")

    // Current saves preserve x. Old-world saves migrate x once but keep all earnings.
    let currentState = defaults.data(forKey: "scrollseeker.adventure.v1.state")!
    var legacy = try JSONSerialization.jsonObject(with: currentState) as! [String: Any]
    legacy.removeValue(forKey: "worldVersion")
    legacy["heroX"] = 0.12
    legacyDefaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "scrollseeker.adventure.v1.state")
    let migrated = AdventureGame(archive: archive, defaults: legacyDefaults, walkPath: AdventureWalkPath(defaults: legacyDefaults, sourceURL: worldURL))
    check(migrated.heroX == world.homeX, "Prior-world position migrates to the new Home")
    check(migrated.coins == game.coins && migrated.completedMissionIDs == game.completedMissionIDs && migrated.ownedGear == game.ownedGear && migrated.journalEntries == game.journalEntries, "World migration preserves all earnings and memories")
    migrated.startWorld()
    migrated.walk(to: 0.90)
    migrated.tick(delta: 100)
    migrated.stopWorld()
    let reloaded = AdventureGame(archive: archive, defaults: legacyDefaults, walkPath: AdventureWalkPath(defaults: legacyDefaults, sourceURL: worldURL))
    check(reloaded.heroX == migrated.heroX && reloaded.heroX != world.homeX, "World migration is one-time, then resumes exact position")

    for center in AdventureWorldArchive.mistCenters {
      check(abs(world.mistIntensity(at: center) - 1) < 0.000001, "Mist peaks at its authored center")
      check(world.mistIntensity(at: center + 0.026) == 0 && world.mistIntensity(at: center - 0.026) == 0, "Mist clears outside its narrow band")
      for offset in stride(from: -0.025, through: 0.025, by: 0.001) {
        let value = world.mistIntensity(at: center + offset)
        check((0...1).contains(value) && value.isFinite, "Smooth mist stays bounded")
        check(abs(value - world.mistIntensity(at: center - offset)) < 0.000001, "Mist fades symmetrically in both walking directions")
      }
    }
    // No missions remain in the child act, allowing an unobstructed mist sample.
    game.startWorld()
    game.walk(to: 0.5)
    game.tick(delta: 100)
    check(abs(game.heroMistOpacity - 0.4) < 0.000001 && abs(game.mistSpeedMultiplier - 1.2) < 0.000001, "Hero fades to .4 and walks twenty percent faster at mist center")
    let transitionBefore = game.segmentTransitionCount
    game.walk(to: 0.48)
    game.tick(delta: 100)
    check(game.segmentTransitionCount == transitionBefore, "Segment announcement waits until leaving the mist")
    game.walk(to: 0.474)
    game.tick(delta: 100)
    check(game.heroMistOpacity == 1 && game.mistSpeedMultiplier == 1, "Clear road restores full opacity and normal pace")
    check(game.lastEnteredSegmentName == world.segment(at: game.heroX)?.name, "Arrival name follows the active scene")
    game.stopWorld()
    check(game.selectPath(.scholar, isPro: true), "Scholar route remains gated by earned childhood")
    for id in ["a1", "a2", "a3", "a4", "a5"] { finish(id) }
    check(game.heroX == world.places["poetry_tower"]!.x && game.canPlayCricket, "Scholar ends at Poetry Tower in the Capital")
    check(game.selectPath(.thief, isPro: true), "Second life remains independently playable")
    for id in ["b1", "b2", "b3", "b4"] { finish(id) }
    _ = game.foldHome()
    let thiefX = game.heroX
    game.startWorld()
    check(game.heroX == thiefX && game.objectiveDirection == 1, "Returning to the city gate never advances away from a backtracking quest")
    finish("b5")
    check(game.heroX == world.places["city_gate"]!.x && !game.canPlayCricket, "Thief ending returns to the City Gate, not the Capital")
    let finalWorld = try Data(contentsOf: worldURL)
    let finalStory = try Data(contentsOf: storyURL)
    check(originalWorld == finalWorld && originalStory == finalStory, "Runtime remapping never changes either supplied JSON file")
    print("Passed \(checks) six-scene world, migration, mist, and continuous-resume checks")
  }
}
