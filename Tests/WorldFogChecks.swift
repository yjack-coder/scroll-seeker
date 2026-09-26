import Foundation

@main
struct WorldFogChecks {
  @MainActor static func main() throws {
    let file = CommandLine.arguments.dropFirst().first ?? "App/Resources/World/world.json"
    let world = try AdventureWorldArchive.load(from: URL(fileURLWithPath: file))
    let suite = "ScrollSeeker.FogChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      checks += 1
      guard condition() else { fatalError(message) }
    }

    let fog = WorldFogProgress(defaults: defaults)
    fog.configure(world: world)
    check(fog.bands.count == 5, "Six scenes produce five banks")
    let expected = [0.812, 0.656, 0.5, 0.344, 0.188]
    for (band, center) in zip(fog.bands, expected) {
      check(abs(band.center - center) < 0.001, "Bank center comes from the supplied scene overlap")
      check(!band.chineseName.isEmpty && band.chineseName.allSatisfy { !$0.isASCII }, "Calligraphy title excludes English")
    }
    let first = fog.bands[0]
    let now = Date(timeIntervalSince1970: 1_000)
    fog.observe(heroX: world.homeX, at: now)
    check(fog.revealedIDs.isEmpty, "The opening village does not start with cleared future scenery")
    fog.observe(heroX: first.center + 0.041, at: now)
    check(fog.revealedIDs.isEmpty, "Outside the threshold leaves the fog intact")
    fog.observe(heroX: first.center + 0.039, at: now)
    check(fog.revealedIDs == [first.id], "Approaching within four percent lifts the first bank")
    check(fog.titleBand == first && fog.titleDate == now, "Next scene's title accompanies the lift")
    check(fog.revealCount == 1, "One approach emits one reveal event")
    check(fog.liftProgress(for: first, at: now, reduceMotion: false) == 0, "Lift starts opaque")
    check(abs(fog.liftProgress(for: first, at: now.addingTimeInterval(0.75), reduceMotion: false) - 0.5) < 0.0001, "Lift is halfway at 0.75 seconds")
    check(fog.liftProgress(for: first, at: now.addingTimeInterval(1.5), reduceMotion: false) == 1, "Lift ends after 1.5 seconds")
    check(fog.liftProgress(for: first, at: now, reduceMotion: true) == 1, "Reduce Motion immediately clears the bank without translation")
    check(fog.liftProgress(for: first, at: now.addingTimeInterval(-1), reduceMotion: false) == 0, "Clock rollback cannot corrupt animation")
    fog.observe(heroX: first.center + 0.039, at: now.addingTimeInterval(1))
    fog.observe(heroX: first.center + 0.035, at: now.addingTimeInterval(1))
    check(fog.revealCount == 1 && fog.liftDates[first.id] == now, "Repeated samples never restart the lift")
    fog.settle(at: now.addingTimeInterval(3.1))
    check(!fog.hasActiveReveal && fog.titleBand == nil, "Finished effects stop consuming animation updates")
    check(fog.liftProgress(for: first, at: now.addingTimeInterval(4), reduceMotion: false) == 1, "Cleared banks remain cleared after settling")

    let reopened = WorldFogProgress(defaults: defaults)
    reopened.configure(world: world)
    check(reopened.revealedIDs.contains(first.id) && reopened.liftDates.isEmpty, "Saved reveal restores without replaying")
    reopened.observe(heroX: world.homeX, at: now)
    check(reopened.revealedIDs.contains(first.id), "Returning home does not reset exploration")
    reopened.observe(heroX: 0.98, at: now)
    check(reopened.revealCount == 0, "Walking right does not emit a new reveal")
    reopened.observe(heroX: .nan, at: now)
    reopened.observe(heroX: .infinity, at: now)
    reopened.observe(heroX: -1, at: now)
    check(reopened.revealCount == 0, "Invalid positions never change exploration")
    reopened.observe(heroX: 0.05, at: now)
    check(reopened.revealedIDs.count == 5, "Large leftward steps cannot skip fog triggers")
    check(reopened.titleBand == reopened.bands.last, "A scene jump announces the nearest new scene")

    var updated = world
    updated.size[0] += 1
    reopened.configure(world: updated)
    check(reopened.revealedIDs.isEmpty, "A changed world dataset has independent reveal state")
    let resumed = WorldFogProgress(defaults: defaults)
    resumed.configure(world: updated)
    resumed.observe(heroX: 0.4, at: now)
    check(resumed.revealedIDs.count == 3, "Old saves already beyond a bank restore travelled scenery")
    check(resumed.revealCount == 0 && resumed.titleBand == nil, "Restoration does not replay earlier scene introductions")
    resumed.observe(heroX: 0.6, at: now)
    check(resumed.revealedIDs.count == 3, "Rightward backtracking never fogs a scene again")
    print("Passed \(checks) world-fog checks")
  }
}
