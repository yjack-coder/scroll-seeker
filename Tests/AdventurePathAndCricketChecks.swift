import Foundation

@main
@MainActor
struct AdventurePathAndCricketChecks {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      precondition(condition(), message)
      checks += 1
    }
    let storyURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Resources/Qingming/story.json")
    let pathURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "App/Resources/World/world.json")
    let originalPathData = try Data(contentsOf: pathURL)
    let archive = try AdventureArchive.load(from: storyURL, worldURL: pathURL)
    let suite = "scrollseeker.pathchecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let cricketSuite = suite + ".cricket"
    let cricketDefaults = UserDefaults(suiteName: cricketSuite)!
    defer {
      defaults.removePersistentDomain(forName: suite)
      cricketDefaults.removePersistentDomain(forName: cricketSuite)
    }
    let path = AdventureWalkPath(defaults: defaults, sourceURL: pathURL)
    check(path.points.count == archive.world!.walkpath.count && path.lastError == nil, "Loads all authored walking points")
    check(path.maxX == archive.world!.walkpath.first!.first! && path.minX == archive.world!.walkpath.last!.first!, "Walking bounds match authored endpoints")
    check(path.y(atX: archive.home.x) == 0.64, "Feet start at the latest authored home height")
    for point in path.points {
      let sample = path.point(atX: point.x)!
      check(abs(Double(sample.x) - point.x) < 0.000_001 && abs(Double(sample.y) - point.y) < 0.000_001, "Catmull–Rom passes through every traced point")
    }
    for x in stride(from: 0.0, through: 1.0, by: 0.001) {
      let sample = path.point(atX: x)!
      check(sample.x.isFinite && sample.y.isFinite && (path.minX...path.maxX).contains(Double(sample.x)) && (0...1).contains(Double(sample.y)), "All spline samples remain finite and within the scroll")
    }
    for point in path.points.dropFirst().dropLast() {
      let epsilon = 0.000_000_1
      let leftSlope = (path.y(atX: point.x) - path.y(atX: point.x - epsilon)) / epsilon
      let rightSlope = (path.y(atX: point.x + epsilon) - path.y(atX: point.x)) / epsilon
      check(abs(leftSlope - rightSlope) < 0.02, "Adjacent spline segments share a smooth tangent")
    }
    check(path.point(atX: 1)?.x == path.maxX && path.point(atX: 0)?.x == path.minX, "Sampling beyond the road returns its endpoints")
    check(path.point(atX: .nan) == nil, "Non-finite sampling is rejected")
    let draft = [AdventurePathPoint(x: 0.8, y: 0.3), AdventurePathPoint(x: 0.5, y: 0.6), AdventurePathPoint(x: 0.1, y: 0.5)]
    check(path.save(points: draft), "Local path edits can be saved")
    let restoredPath = AdventureWalkPath(defaults: defaults, sourceURL: pathURL)
    check(restoredPath.points.map(\.x) == draft.map(\.x) && restoredPath.points.map(\.y) == draft.map(\.y), "Local override survives reload")
    check(!path.save(points: [draft[0]]), "Cannot delete below two points")
    check(!path.save(points: [draft[0], draft[0]]), "Duplicate x positions are rejected")
    check(!path.save(points: draft.reversed()), "Left-to-right ordering is rejected")
    check(!path.save(points: [.init(x: 0.9, y: .nan), .init(x: 0.1, y: 0.5)]), "NaN coordinates are rejected")
    check(!path.save(points: [.init(x: 0.9, y: 1.1), .init(x: 0.1, y: 0.5)]), "Coordinates beyond the painting are rejected")
    check(path.points == draft, "Invalid edits preserve the last valid path")
    let exported = try JSONSerialization.jsonObject(with: Data(path.jsonString.utf8)) as! [String: Any]
    check((exported["points"] as? [[Double]]) == draft.map { [$0.x, $0.y] }, "Copy JSON uses the original pair-array schema")
    let unchangedPathData = try Data(contentsOf: pathURL)
    check(unchangedPathData == originalPathData, "Local overrides never rewrite the bundled trace")

    let editedGame = AdventureGame(archive: archive, defaults: defaults, walkPath: restoredPath)
    check(editedGame.heroX == 0.8 && editedGame.heroY == 0.3, "Restored hero clamps to an edited path endpoint")
    check(editedGame.currentMission?.x == archive.world?.places["lost_donkey"]?.x && editedGame.currentMissionTriggerX == 0.8, "Authored mission stays unchanged while its encounter clamps to the road")
    editedGame.walk(to: 1)
    check(editedGame.pendingMission?.id == "m1" && editedGame.heroX == 0.8, "Endpoint encounter does not move feet off the road")
    check(editedGame.completeMission("m1"), "Clamped encounter still completes normally")
    let shorter = [AdventurePathPoint(x: 0.7, y: 0.4), AdventurePathPoint(x: 0.1, y: 0.6)]
    check(editedGame.saveWalkPath(points: shorter), "Game accepts a validated edited road")
    check(editedGame.heroX == 0.7 && editedGame.heroY == 0.4 && !editedGame.isWorldActive, "Saving a shorter path clamps and pauses the hero")
    editedGame.startWorld()
    editedGame.walk(to: 0.65)
    editedGame.tick(delta: 100)
    check(editedGame.heroX <= 0.7 && editedGame.heroY == editedGame.walkPath.y(atX: editedGame.heroX), "Movement always places feet on the live spline")
    let beforeFold = editedGame.heroX
    _ = editedGame.foldHome()
    check(editedGame.heroX == beforeFold, "Fold does not teleport along the road")

    let cricketPath = AdventureWalkPath(defaults: cricketDefaults, sourceURL: pathURL)
    let game = AdventureGame(archive: archive, defaults: cricketDefaults, walkPath: cricketPath)
    let unavailableRound = UUID()
    check(!game.canPlayCricket && !game.recordCricketWin(roundID: unavailableRound, winner: 1) && game.coins == 10, "Cricket rewards are unavailable in childhood outside the Capital")
    while let mission = game.currentMission {
      if mission.trigger == .fold { _ = game.foldHome() }
      else {
        game.startWorld()
        game.walk(to: mission.x)
        game.tick(delta: 100)
      }
      check(game.completeMission(mission.id), "Complete childhood before cricket unlock")
    }
    check(game.selectPath(.scholar, isPro: true), "Enter an earned Pro story path")
    check(!game.canPlayCricket && !game.recordCricketWin(roundID: UUID(), winner: 1), "Paid path alone cannot award cricket outside the Capital")
    for id in ["a1", "a2", "a3"] {
      game.startWorld()
      game.walk(to: game.currentMission!.x)
      game.tick(delta: 100)
      check(game.completeMission(id), "Travel toward the Capital")
    }
    game.walk(to: 0.14)
    game.tick(delta: 100)
    game.stopWorld()
    check(game.canPlayCricket && game.currentSegment?.id == "Panel6", "Cricket unlocks in the Capital on a grown-up path")
    let round = UUID()
    let coins = game.coins
    check(!game.recordCricketWin(roundID: round, winner: 0) && game.coins == coins, "Invalid winner cannot receive coins")
    check(game.recordCricketWin(roundID: round, winner: 1) && game.coins == coins + 5, "A completed local match awards exactly five copper coins")
    check(!game.recordCricketWin(roundID: round, winner: 2) && game.coins == coins + 5, "A match cannot award twice even with another winner")
    let loadedGame = AdventureGame(archive: archive, defaults: cricketDefaults, walkPath: AdventureWalkPath(defaults: cricketDefaults, sourceURL: pathURL))
    check(!loadedGame.recordCricketWin(roundID: round, winner: 1) && loadedGame.coins == coins + 5, "Reward deduplication persists across relaunch")
    check(loadedGame.recordCricketWin(roundID: UUID(), winner: 2) && loadedGame.coins == coins + 10, "A new rematch can award once for the other player")
    print("Passed \(checks) walking path and cricket reward checks")
  }
}
