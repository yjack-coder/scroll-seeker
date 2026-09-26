import Foundation

@main
struct SeekerModelChecks {
  @MainActor
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ description: String) {
      precondition(condition(), description)
      checks += 1
    }

    let archivePath = CommandLine.arguments.dropFirst().first ?? "App/Resources/Qingming/targets.json"
    let archive = try ScrollArchive.load(from: URL(fileURLWithPath: archivePath))
    check(archive.tiles.count == 8, "Eight panorama tiles")
    check(archive.targets.count == 10, "Ten real targets")
    check(archive.chapters.count == 2, "Two chapters")
    check(ScrollArchive.fullWidth == 25609 && ScrollArchive.fullHeight == 1200, "Correct full panorama dimensions")
    let river = archive.chapters[0]
    let city = archive.chapters[1]
    check(river.chineseName == "汴河" && river.englishName == "The River", "Chapter names")
    check(archive.targets(for: river.id).map(\.id) == ["donkeys", "cargo_boat", "rainbow_bridge", "scaffold_tower", "sailboat"], "River progresses from right to left")
    check(archive.targets(for: city.id).map(\.id) == ["city_gate", "camels", "wine_shop_sign", "sedan_chair", "ox_cart"], "City progresses from right to left")
    let donkey = archive.targets(for: river.id)[0]
    check(donkey.chineseName == "驢隊" && donkey.englishName == "Donkey Caravan", "Target names")
    check(SeekerGame.targetAt(x: donkey.x, y: donkey.y, candidates: [donkey]) == donkey, "Exact normalized target hit")
    check(SeekerGame.targetAt(x: donkey.x + 0.015, y: donkey.y, candidates: [donkey]) == donkey, "Full generous horizontal radius")
    check(SeekerGame.targetAt(x: donkey.x, y: donkey.y + 0.12, candidates: [donkey]) == donkey, "Full generous vertical radius")
    check(SeekerGame.targetAt(x: donkey.x + 0.014, y: donkey.y + 0.11, candidates: [donkey]) == nil, "Elliptical corner excluded")
    check(SeekerGame.targetAt(x: donkey.x + 0.016, y: donkey.y, candidates: [donkey]) == nil, "Outside radius excluded")
    check(SeekerGame.targetAt(x: .nan, y: donkey.y, candidates: [donkey]) == nil, "Invalid coordinate excluded")
    check(SeekerGame.targetAt(x: -0.1, y: donkey.y, candidates: [donkey]) == nil, "Outside painting excluded")
    var neighbor = donkey
    neighbor.id = "neighbor"
    neighbor.x -= 0.008
    check(SeekerGame.targetAt(x: neighbor.x + 0.001, y: neighbor.y, candidates: [donkey, neighbor]) == neighbor, "Nearest overlapping target wins")

    let suite = "scrollseeker.modelchecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("preserve-me", forKey: "liubai.entries")
    var instant = Date(timeIntervalSince1970: 1000)
    let game = SeekerGame(archive: archive, defaults: defaults, now: { instant })
    check(game.chapter == nil && game.currentTarget == nil, "Fresh game has no selected chapter")
    game.setSearching(true)
    check(!game.isSearching, "Cannot time missing chapter")
    game.startChapter(river)
    check(game.currentTarget == donkey && game.foundCount == 0, "Start chapter at countryside")
    check(game.canHint(isPro: false), "One free hint available")
    check(game.requestHint(isPro: false) == donkey, "Hint reveals current target")
    check(game.hintsUsed == 1 && !game.canHint(isPro: false), "Free hint consumed")
    check(game.requestHint(isPro: false) == nil, "No second free hint")
    check(game.requestHint(isPro: true) == donkey && game.hintsUsed == 2, "Pro hints unlimited")
    check(!game.find(archive.targets(for: river.id)[1]), "Cannot find out of order")
    game.setSearching(true)
    instant += 12
    game.setSearching(false)
    check(game.elapsedSeconds == 12, "Active search time accumulated")
    instant += 100
    game.setSearching(false)
    check(game.elapsedSeconds == 12, "Closed or background time excluded")
    game.setSearching(true)
    instant += 8
    check(game.find(donkey), "Current target found")
    check(!game.isSearching && game.elapsedSeconds == 20, "Story pauses timer")
    check(!game.find(donkey), "Duplicate target rejected")
    check(game.foundCount == 1 && game.currentTarget?.id == "cargo_boat", "Next clue derived")
    game.nextClue()
    check(game.currentTarget?.id == "cargo_boat", "Next clue does not skip target")

    let restored = SeekerGame(archive: archive, defaults: defaults, now: { instant })
    check(restored.chapter == river && restored.currentTarget?.id == "cargo_boat", "Selection and progression persist")
    check(restored.hintsUsed == 2 && !restored.canHint(isPro: false), "Hints survive relaunch")
    check(restored.elapsedSeconds == 20 && !restored.isSearching, "Time survives relaunch without continuing in background")
    check(defaults.string(forKey: "liubai.entries") == "preserve-me", "Existing Liubai state preserved")
    restored.startChapter(city)
    check(restored.currentTarget?.id == "city_gate" && restored.hintsUsed == 0, "Chapters have independent progression and hints")
    restored.setSearching(true)
    instant += 5
    restored.setSearching(false)
    check(restored.seconds(for: city) == 5 && restored.seconds(for: river) == 20 && restored.totalElapsedSeconds == 25, "Per-chapter and total time")
    check(restored.foundTargets.isEmpty && restored.allFoundTargets == [donkey], "Museum collection includes other chapters")
    restored.startChapter(river)
    check(restored.foundCount == 1 && restored.elapsedSeconds == 20, "Returning preserves chapter state")
    while let target = restored.currentTarget {
      check(restored.find(target), "Find remaining target " + target.id)
    }
    check(restored.chapterComplete && restored.progress(for: river) == 5, "Completion after all five found")
    restored.setSearching(true)
    check(!restored.isSearching && !restored.canHint(isPro: true), "Completed chapter cannot search or consume hints")
    let final = SeekerGame(archive: archive, defaults: defaults)
    check(final.chapterComplete && final.foundIDs.count == 5, "Completion survives relaunch")
    print("Passed \(checks) Scroll Seeker model checks")
  }
}
