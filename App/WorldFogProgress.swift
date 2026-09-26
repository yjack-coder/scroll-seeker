import Foundation
import Observation

/// Exploration fog belongs to the authored dataset, not a particular view or
/// phone posture. Re-opening the scroll must never replace a lifted bank.
@MainActor
@Observable
final class WorldFogProgress {
  private(set) var bands: [WorldFogBand] = []
  private(set) var revealedIDs: Set<String> = []
  private(set) var liftDates: [String: Date] = [:]
  private(set) var titleBand: WorldFogBand?
  private(set) var titleDate: Date?
  private(set) var revealCount = 0
  @ObservationIgnored private var previousHeroX: Double?
  @ObservationIgnored private var storageKey: String?
  @ObservationIgnored private let defaults: UserDefaults

  static let triggerDistance = 0.04
  static let liftDuration = 1.5
  var hasActiveReveal: Bool { !liftDates.isEmpty || titleBand != nil }

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func configure(world: AdventureWorldArchive) {
    let key = "scrollseeker.fog.v1.\(world.geometryVersion)"
    guard key != storageKey else { return }
    storageKey = key
    bands = zip(world.segments, world.segments.dropFirst()).map { before, after in
      WorldFogBand(id: after.id, center: (before.xRange[0] + after.xRange[1]) / 2, name: after.name)
    }
    let validIDs = Set(bands.map(\.id))
    revealedIDs = Set(defaults.stringArray(forKey: key) ?? []).intersection(validIDs)
    liftDates = [:]
    titleBand = nil
    titleDate = nil
    previousHeroX = nil
  }

  func observe(heroX: Double, at date: Date = .now) {
    guard heroX.isFinite, (0...1).contains(heroX), !bands.isEmpty else { return }
    let previous = previousHeroX
    previousHeroX = heroX
    // Existing saves may start deep inside the world. Earlier scenery has
    // already been explored; do not make the hero walk backward to clear it.
    if previous == nil {
      for band in bands where heroX < band.center - Self.triggerDistance {
        revealedIDs.insert(band.id)
      }
      persist()
    } else if heroX >= previous! {
      return // Approaching from the city/rightward cannot reveal new country.
    }

    var latest: WorldFogBand?
    for band in bands where !revealedIDs.contains(band.id) {
      let near = abs(heroX - band.center) <= Self.triggerDistance
      let crossed = previous.map { $0 > band.center && heroX < band.center } ?? false
      guard near || crossed else { continue }
      revealedIDs.insert(band.id)
      liftDates[band.id] = date
      latest = band
    }
    if let latest {
      titleBand = latest
      titleDate = date
      revealCount += 1
      persist()
    }
  }

  func liftProgress(for band: WorldFogBand, at date: Date, reduceMotion: Bool) -> Double {
    guard revealedIDs.contains(band.id) else { return 0 }
    guard !reduceMotion, let started = liftDates[band.id] else { return 1 }
    let t = min(1, max(0, date.timeIntervalSince(started) / Self.liftDuration))
    return t * t * (3 - 2 * t)
  }

  func settle(at date: Date = .now) {
    liftDates = liftDates.filter { date.timeIntervalSince($0.value) < Self.liftDuration }
    if let titleDate, date.timeIntervalSince(titleDate) >= 3 {
      titleBand = nil
      self.titleDate = nil
    }
  }

  private func persist() {
    guard let storageKey else { return }
    defaults.set(revealedIDs.sorted(), forKey: storageKey)
  }
}

struct WorldFogBand: Equatable, Identifiable {
  var id: String
  var center: Double
  var name: String
  var chineseName: String { String(name.prefix { !$0.isASCII }) }
}
