import Foundation

@main
@MainActor
struct AdventureDepartureChecks {
  static func main() throws {
    var checks = 0
    func check(_ value: @autoclosure () -> Bool, _ message: String) {
      precondition(value(), message)
      checks += 1
    }
    let worldURL = URL(fileURLWithPath: "App/Resources/World/world.json")
    let archive = try AdventureArchive.load(
      from: URL(fileURLWithPath: "App/Resources/Qingming/story.json"), worldURL: worldURL)
    let suite = "scrollseeker.departurechecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let game = AdventureGame(archive: archive, defaults: defaults,
      walkPath: AdventureWalkPath(defaults: defaults, sourceURL: worldURL))
    check(!game.isWorldActive && game.heroX == archive.home.x, "First launch is at Home and does not move")
    check(!game.beginHomeDepartureIfNeeded(), "Hidden folded world cannot begin the intro")
    game.startWorld()
    check(game.beginHomeDepartureIfNeeded() && game.isDepartingHome && game.direction == -1,
      "First revealed world walks left automatically")
    check(!game.beginHomeDepartureIfNeeded(), "Repeated ready events cannot replay or extend the walk")
    game.setDirection(0)
    check(game.isDepartingHome && game.direction == -1, "A held-control cleanup cannot cancel the scripted walk")
    for _ in 0..<90 {
      let before = game.heroX
      game.tick(delta: 1 / 60)
      check(game.heroX <= before && before - game.heroX < 0.00011, "Intro steps are continuous and leftward")
      check(game.heroY == game.walkPath.y(atX: game.heroX), "Every introduction frame follows the authored road")
    }
    check(!game.isDepartingHome && game.direction == 0 && game.showsWalkHint, "Intro ends by waiting with the walk hint")
    check(abs(game.heroX - (archive.home.x - 0.009)) < 0.0000001, "Only a few steps are walked")
    check(game.pendingMission == nil && game.completedMissionIDs.isEmpty, "Introduction grants nothing and skips no encounter")
    let waitingX = game.heroX
    game.tick(delta: 100)
    check(game.heroX == waitingX, "Hero waits indefinitely for player input")
    for _ in 0..<5 {
      _ = game.foldHome()
      game.startWorld()
      check(!game.beginHomeDepartureIfNeeded() && game.heroX == waitingX, "Fold and reopen preserve the exact same position")
    }
    game.setDirection(-1)
    check(!game.showsWalkHint && !game.isDepartingHome, "Manual walking dismisses the hint")
    game.tick(delta: 0.1)
    let manualX = game.heroX
    game.stopWorld()
    let reloaded = AdventureGame(archive: archive, defaults: defaults,
      walkPath: AdventureWalkPath(defaults: defaults, sourceURL: worldURL))
    check(!reloaded.isWorldActive && reloaded.heroX == manualX, "Relaunch opens the hub but keeps the journey coordinate")
    reloaded.startWorld()
    check(!reloaded.beginHomeDepartureIfNeeded(), "Persisted introduction never repeats on relaunch")
    reloaded.stopWorld()
    print("Passed \(checks) Home departure and five-unfold continuity checks")
  }
}
