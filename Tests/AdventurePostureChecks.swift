import Foundation

@main
@MainActor
struct AdventurePostureChecks {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      precondition(condition(), message)
      checks += 1
    }

    let posture = AdventurePostureStore()
    check(AdventurePosture.allCases.count == 5, "Five discrete posture choices")
    check(posture.current == .folded && posture.previous == .folded && posture.changeCount == 0, "Initial home pose emits no input")
    posture.set(.folded)
    check(posture.changeCount == 0, "Repeated initial folded sample emits nothing")
    var expectedCount = 0
    for next in [AdventurePosture.open, .book, .tent, .laptop, .folded, .open] {
      let old = posture.current
      posture.set(next)
      expectedCount += 1
      check(posture.current == next && posture.previous == old && posture.changeCount == expectedCount, "Actual transition stores old and new pose exactly once")
      for _ in 0..<100 { posture.set(next) }
      check(posture.current == next && posture.previous == old && posture.changeCount == expectedCount, "Repeated sensor samples do not retrigger actions")
    }

    let path = CommandLine.arguments.dropFirst().first ?? "App/Resources/Qingming/story.json"
    let worldURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "App/Resources/World/world.json")
    let archive = try AdventureArchive.load(from: URL(fileURLWithPath: path), worldURL: worldURL)
    let suite = "scrollseeker.posturechecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let legacySuite = suite + ".legacy"
    let legacyDefaults = UserDefaults(suiteName: legacySuite)!
    defer {
      defaults.removePersistentDomain(forName: suite)
      legacyDefaults.removePersistentDomain(forName: legacySuite)
    }
    var instant = Date(timeIntervalSince1970: 2000)
    let walkURL = worldURL
    let game = AdventureGame(archive: archive, defaults: defaults, now: { instant }, walkPath: AdventureWalkPath(defaults: defaults, sourceURL: walkURL))
    check(game.letters.isEmpty && !game.lastMotherReply.isEmpty, "New game has a reassuring Mother reply and no letters")
    let first = game.recordLetterHome()
    check(first.missionID == nil && first.body.contains("Home Village"), "First letter describes the current journey")
    check(first.date == instant && game.lastMotherReply == first.reply, "Sealed letter records date and Mother's reply")
    check(game.coins == 10 && game.completedMissionIDs.isEmpty && game.ownedGear.isEmpty && game.heroX == archive.home.x, "Writing a letter never grants progress, gear or coins and never teleports")

    for id in ["m1", "m2", "m_paperboat", "m3"] {
      game.startWorld()
      game.walk(to: game.currentMission!.x)
      game.tick(delta: 100)
      check(game.pendingMission?.id == id && game.completeMission(id), "Complete authored mission before writing " + id)
      game.stopWorld()
      instant += 30
      let beforeCoins = game.coins
      let beforeGear = game.ownedGear
      let beforeInventory = game.inventory
      let beforeProgress = game.completedMissionIDs
      let letter = game.recordLetterHome()
      check(letter.missionID == id && letter.body.contains(archive.mission(id)!.journalNarrative), "Letter recalls most recent completed scene")
      check(game.coins == beforeCoins && game.ownedGear == beforeGear && game.inventory == beforeInventory && game.completedMissionIDs == beforeProgress, "Letters do not duplicate mission rewards")
    }
    check(game.lastMotherReply == "聽說你幫了船夫？娘很驕傲。 / I heard you helped the boatmen. Mother is proud.", "Boatmen scene gets its specific mother reaction")
    let restored = AdventureGame(archive: archive, defaults: defaults, walkPath: AdventureWalkPath(defaults: defaults, sourceURL: walkURL))
    check(restored.letters == game.letters && restored.lastMotherReply == game.lastMotherReply, "Letters and reply persist across relaunch")
    check(restored.heroX == game.heroX && restored.currentMission?.id == "m4", "Letter save preserves the ongoing journey")
    check(Set(restored.letters.map(\.id)).count == restored.letters.count, "Each letter has a stable unique identity")

    // Re-create the exact pre-letter save schema by removing only the new fields.
    let encoded = defaults.data(forKey: "scrollseeker.adventure.v1.state")!
    var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    legacy.removeValue(forKey: "letters")
    legacy.removeValue(forKey: "lastMotherReply")
    legacy.removeValue(forKey: "rewardedCricketRounds")
    legacyDefaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "scrollseeker.adventure.v1.state")
    let migrated = AdventureGame(archive: archive, defaults: legacyDefaults, walkPath: AdventureWalkPath(defaults: legacyDefaults, sourceURL: walkURL))
    check(migrated.completedMissionIDs == game.completedMissionIDs && migrated.coins == game.coins, "Pre-letter saves keep mission progress and coins")
    check(migrated.ownedGear == game.ownedGear && migrated.heroX == game.heroX && migrated.currentMission?.id == "m4", "Pre-letter saves keep equipment and resume location")
    check(migrated.letters.isEmpty && !migrated.lastMotherReply.isEmpty, "Missing new fields receive defaults without resetting old state")

    for id in ["m4", "m5"] {
      game.startWorld()
      game.walk(to: game.currentMission!.x)
      game.tick(delta: 100)
      check(game.completeMission(id), "Continue journey " + id)
      game.stopWorld()
      let letter = game.recordLetterHome()
      check(letter.missionID == id, "Mother reacts to the newest child milestone")
    }
    check(game.lastMotherReply.contains("soy sauce"), "Soy purchase gets a steady-bottle reply")
    let coinsBeforeDeliveryLetter = game.coins
    _ = game.recordLetterHome()
    check(game.inventory.contains("soy_sauce") && game.coins == coinsBeforeDeliveryLetter && !game.completedMissionIDs.contains("m6"), "Writing home cannot substitute for fold-only delivery")
    check(game.foldHome()?.id == "m6" && game.completeMission("m6"), "The real fold delivery still works")

    for stage in [AdventureStage.scholar, .thief] {
      check(game.selectPath(stage, isPro: true), "Choose unlocked life path")
      while let mission = game.currentMission {
        game.startWorld()
        game.walk(to: mission.x)
        game.tick(delta: 100)
        check(game.completeMission(mission.id), "Complete path milestone " + mission.id)
      }
      game.stopWorld()
      let letter = game.recordLetterHome()
      check(letter.missionID == (stage == .scholar ? "a5" : "b5"), "Ending letter recalls the chosen life's ending")
      check(letter.reply.contains(stage == .scholar ? "imperial list" : "neighbors have eaten"), "Mother has a distinct ending reply")
    }
    let last = AdventureGame(archive: archive, defaults: defaults, walkPath: AdventureWalkPath(defaults: defaults, sourceURL: walkURL))
    check(last.letters.count == game.letters.count && last.lastMotherReply == game.lastMotherReply, "Ending letters also survive relaunch")
    print("Passed \(checks) posture and letter checks")
  }
}
