import Foundation

@main
@MainActor
struct AdventureModelChecks {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      precondition(condition(), message)
      checks += 1
    }
    let path = CommandLine.arguments.dropFirst().first ?? "App/Resources/Qingming/story.json"
    let worldURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "App/Resources/World/world.json")
    let archive = try AdventureArchive.load(from: URL(fileURLWithPath: path), worldURL: worldURL)
    let world = archive.world!
    check(archive.acts.count == 3 && archive.allMissions.count == 17, "All story branches and paper boat decode")
    check(archive.segments.count == 6 && archive.gear.count == 9, "New scenes and original equipment decode")
    check(archive.home.x == world.places["home"]!.x && archive.home.y == world.places["home"]!.y, "Exact new world home position")
    check(archive.hero.chineseName == "小安" && archive.hero.englishName == "Xiao An", "Bilingual hero")
    check(archive.act(for: .child)?.missions.map(\.id) == ["m1", "m2", "m_paperboat", "m3", "m4", "m5", "m6"], "Paper boat appears after directions")
    check(archive.act(for: .thief)?.missions.map(\.x) == ["grain_barge", "city_gate", "ox_cart", "tavern", "city_gate"].map { world.places[$0]!.x }, "Thief places preserve final gate backtracking")
    check(Set(archive.allMissions.map(\.sealName)).count == 17, "Every quest has a unique seal")
    for mission in archive.allMissions {
      check(mission.poemChinese.split(separator: "\n").count == 2 && mission.poemEnglish.split(separator: "\n").count == 2, "Each seal has a bilingual two-line poem")
    }
    let suite = "scrollseeker.adventurechecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("existing journal", forKey: "liubai.entries")
    defaults.set("existing seeker", forKey: "scrollseeker.v1.state")
    let walkURL = worldURL
    let walkPath = AdventureWalkPath(defaults: defaults, sourceURL: walkURL)
    check(walkPath.y(atX: archive.home.x) == 0.64, "Feet begin on the new home's road")
    for x in stride(from: 0.0, through: 1.0, by: 0.01) {
      let y = walkPath.y(atX: x)
      check(y.isFinite && (0...1).contains(y), "Road stays within painting")
    }
    var instant = Date(timeIntervalSince1970: 1000)
    let game = AdventureGame(archive: archive, defaults: defaults, now: { instant }, walkPath: walkPath)
    check(game.heroX == archive.home.x && game.heroY == 0.64, "New adventure begins on the authored feet line")
    check(game.coins == 10 && game.inventory.contains("empty_bottle"), "Mother provides starting supplies")
    check(game.currentMission?.id == "m1" && game.objectiveDirection == -1, "The donkey encounter is left of home")
    check(!game.isWorldActive && game.heroX == archive.home.x, "Launch stays at Home until the player opens the scroll")
    check(game.stage == .child && game.selectedOutfit == .child, "Starts as child")
    check(!game.selectPath(.scholar, isPro: true), "Act two cannot skip childhood")
    check(!game.selectOutfit(.scholar, isPro: true), "Unearned outfit cannot be selected")
    check(game.foldHome() == nil && !game.completeMission("m6"), "Folding without soy does not finish story")
    check(!game.buyGear("cloth_boots", isPro: false), "Insufficient coin purchase rejected")
    game.setDirection(1)
    game.tick(delta: 3)
    check(game.heroX == archive.home.x, "World cannot walk while home or backgrounded")
    game.startWorld()
    game.setDirection(-1)
    game.tick(delta: 100)
    check(game.pendingMission?.id == "m1" && game.heroX == archive.mission("m1")!.x, "Walking across the encounter opens it without skipping")
    check(game.coins == 10 && game.completedMissionIDs.isEmpty, "Arrival never awards success")
    game.tick(delta: 10)
    check(game.heroX == archive.mission("m1")!.x, "Pending challenge stops movement")
    game.dismissMission()
    game.tick(delta: 1)
    check(game.pendingMission == nil, "Dismissed challenge does not reappear on idle frames")
    game.walk(to: game.heroX)
    check(game.pendingMission?.id == "m1", "New walk intent can reopen a challenge at current position")
    check(!game.completeMission("m2"), "Out-of-order mission completion rejected")
    check(game.completeMission("m1"), "Solved first challenge can complete")
    check(game.coins == 15 && game.ownsGear("straw_sandals") && game.walkSpeed == 0.032, "First reward and sandal effect")
    check(!game.completeMission("m1") && game.coins == 15, "Rewards are idempotent")
    check(game.buyGear("cloth_boots", isPro: false) && game.coins == 0 && game.walkSpeed == 0.040, "Coin purchase applies boot effect")
    check(!game.buyGear("cloth_boots", isPro: true) && game.coins == 0, "Duplicate purchase is not charged")
    check(!game.buyGear("brush", isPro: false), "Pro reward gear cannot be claimed as a free purchase")

    game.walk(to: 0.85)
    game.tick(delta: 1)
    let preservedX = game.heroX
    check(game.foldHome() == nil && game.resumeX == preservedX, "Fold preserves world progress before soy")
    game.tick(delta: 50)
    check(game.heroX == preservedX && !game.isWorldActive, "No background walking after fold")
    let resumed = AdventureGame(archive: archive, defaults: defaults, now: { instant }, walkPath: AdventureWalkPath(defaults: defaults, sourceURL: walkURL))
    check(resumed.heroX == preservedX && resumed.currentMission?.id == "m2", "Resume position and mission persist")
    check(resumed.coins == 0 && resumed.ownsGear("cloth_boots"), "Coins and owned gear persist")
    check(!resumed.isWorldActive, "Relaunch does not start moving")

    for id in ["m2", "m_paperboat", "m3", "m4", "m5"] {
      let mission = resumed.currentMission!
      check(mission.id == id, "Authored next mission " + id)
      resumed.startWorld()
      resumed.walk(to: mission.x)
      resumed.tick(delta: 100)
      check(resumed.pendingMission?.id == id, "Crossing raises " + id)
      instant += 60
      check(resumed.completeMission(id), "Minigame success completes " + id)
    }
    check(resumed.inventory.contains("soy_sauce") && !resumed.inventory.contains("empty_bottle"), "Bottle filled with soy")
    check(resumed.ownsGear("rope") && resumed.hintRadiusMultiplier == 1.6, "Authored passive rewards apply")
    check(resumed.buyGear("magnifier", isPro: false) && resumed.maximumZoom == 6 && resumed.coins == 6, "Magnifier costs coins and unlocks 6×")
    resumed.walk(to: archive.home.x)
    resumed.tick(delta: 100)
    check(resumed.pendingMission == nil && resumed.currentMission?.id == "m6", "Walking home does not substitute for folding")
    resumed.walk(to: 0)
    resumed.tick(delta: 100)
    check(resumed.heroX == walkPath.minX, "Child can walk the full new world without an obsolete .42 floor")
    check(!resumed.completeMission("m6"), "Fold-only mission cannot complete before folding")
    let beforeFold = resumed.heroX
    check(resumed.foldHome()?.id == "m6" && resumed.heroX == beforeFold, "Fold offers home delivery while preserving world position")
    check(resumed.completeMission("m6") && resumed.forkUnlocked, "Delivery unlocks life fork")
    check(!resumed.inventory.contains("soy_sauce") && resumed.coins == 16, "Delivery consumes soy and grants authored reward")
    check(resumed.foldHome() == nil && !resumed.completeMission("m6"), "Delivery cannot reward twice")
    check(resumed.stage == .child && resumed.actComplete, "Act one ending remains childhood until path selection")
    check(resumed.objectiveDirection == 1, "Completed errand points right toward the bridge fork")
    resumed.startWorld()
    resumed.walk(to: resumed.bridgeX)
    resumed.tick(delta: 100)
    check(resumed.objectiveDirection == 0, "Fork direction settles at the bridge")
    resumed.walk(to: 0.6)
    resumed.tick(delta: 100)
    check(resumed.objectiveDirection == -1, "East of the fork points left toward the bridge")
    check(!resumed.selectPath(.scholar, isPro: false), "Act two requires Pro")
    check(resumed.selectPath(.scholar, isPro: true), "Pro can choose earned scholar path")
    check(resumed.heroX == world.pathStart(for: .scholar) && resumed.currentMission?.id == "a1", "Scholar begins at the tea house")
    check(resumed.selectedOutfit == .scholar && resumed.canSelectOutfit(.scholar, isPro: true), "Selected path unlocks matching wardrobe")
    check(!resumed.canSelectOutfit(.scholar, isPro: false), "Paid wardrobe remains gated when Pro is unavailable")
    check(resumed.selectOutfit(.child, isPro: false) && resumed.stage == .scholar, "Cosmetic wardrobe does not alter story path")
    resumed.startWorld()
    resumed.walk(to: resumed.currentMission!.x)
    resumed.tick(delta: 100)
    check(resumed.completeMission("a1") && resumed.ownsGear("brush"), "Scholar earns brush from mission")
    check(resumed.selectPath(.thief, isPro: true) && resumed.currentMission?.id == "b1", "Switch to thief preserves other path")
    check(resumed.objectiveDirection == 0 && resumed.heroX == world.pathStart(for: .thief), "Thief begins at the grain barge")
    for id in ["b1", "b2", "b3", "b4", "b5"] {
      let mission = resumed.currentMission!
      check(mission.id == id, "Thief keeps authored backtracking order")
      resumed.startWorld()
      resumed.walk(to: mission.x)
      resumed.tick(delta: 100)
      check(resumed.pendingMission?.id == id && resumed.completeMission(id), "Thief challenge succeeds " + id)
    }
    check(resumed.titles.contains("俠盜 Gentleman Thief") && resumed.actComplete, "Thief ending grants authored title")
    check(resumed.ownsGear("grappling_hook") && resumed.ownsGear("black_cloak"), "Thief gear persists")
    check(resumed.selectPath(.scholar, isPro: true) && resumed.currentMission?.id == "a2", "Returning to scholar resumes completed mission progress")
    let final = AdventureGame(archive: archive, defaults: defaults, walkPath: AdventureWalkPath(defaults: defaults, sourceURL: walkURL))
    check(final.currentMission?.id == "a2" && final.heroX == world.pathStart(for: .scholar), "Chosen path persists")
    check(final.journalEntries.count == final.completedMissionIDs.count && final.journalEntries.count == 13, "Every earned scene has exactly one journal entry")
    check(defaults.string(forKey: "liubai.entries") == "existing journal", "Prior journal storage untouched")
    check(defaults.string(forKey: "scrollseeker.v1.state") == "existing seeker", "Prior hidden-object storage untouched")
    print("Passed \(checks) adventure model checks")
  }
}
