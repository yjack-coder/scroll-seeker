import Foundation
import Observation

@MainActor
@Observable
final class SeekerGame {
  let archive: ScrollArchive
  private(set) var selectedChapterID: String?
  private(set) var foundIDs: Set<String>
  private(set) var elapsedSeconds: TimeInterval = 0
  private(set) var isSearching = false

  private var hintCounts: [String: Int]
  private var chapterTimes: [String: TimeInterval]
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private var searchStartedAt: Date?
  @ObservationIgnored private var ticker: Task<Void, Never>?
  private static let persistenceKey = "scrollseeker.v1.state"

  init(
    archive: ScrollArchive,
    defaults: UserDefaults = .standard,
    now: @escaping () -> Date = Date.init
  ) {
    self.archive = archive
    self.defaults = defaults
    self.now = now
    let saved = defaults.data(forKey: Self.persistenceKey).flatMap {
      try? JSONDecoder().decode(SavedProgress.self, from: $0)
    }
    let validIDs = Set(archive.targets.map(\.id))
    foundIDs = (saved?.foundIDs ?? []).intersection(validIDs)
    hintCounts = (saved?.hintCounts ?? [:]).mapValues { max(0, $0) }
    chapterTimes = (saved?.chapterTimes ?? [:]).mapValues { $0.isFinite ? max(0, $0) : 0 }
    selectedChapterID = archive.chapters.first { $0.id == saved?.selectedChapterID }?.id
    elapsedSeconds = chapterTimes[selectedChapterID ?? "", default: 0]
  }

  var chapter: ScrollChapter? {
    archive.chapters.first { $0.id == selectedChapterID }
  }

  var chapterTargets: [ScrollTarget] {
    guard let selectedChapterID else { return [] }
    return archive.targets(for: selectedChapterID)
  }

  var foundTargets: [ScrollTarget] {
    chapterTargets.filter { foundIDs.contains($0.id) }
  }

  var allFoundTargets: [ScrollTarget] {
    archive.targets.filter { foundIDs.contains($0.id) }.sorted { $0.x > $1.x }
  }

  var currentTarget: ScrollTarget? {
    chapterTargets.first { !foundIDs.contains($0.id) }
  }

  var foundCount: Int { foundTargets.count }

  var chapterComplete: Bool {
    !chapterTargets.isEmpty && foundCount == chapterTargets.count
  }

  var hintsUsed: Int {
    hintCounts[selectedChapterID ?? "", default: 0]
  }

  var totalElapsedSeconds: TimeInterval {
    chapterTimes.reduce(0) { total, entry in
      total + (entry.key == selectedChapterID ? 0 : entry.value)
    } + elapsedSeconds
  }

  func startChapter(_ chapter: ScrollChapter) {
    guard archive.chapters.contains(where: { $0.id == chapter.id }) else { return }
    setSearching(false)
    selectedChapterID = chapter.id
    elapsedSeconds = chapterTimes[chapter.id, default: 0]
    save()
  }

  func isFound(_ target: ScrollTarget) -> Bool {
    foundIDs.contains(target.id)
  }

  func progress(for chapter: ScrollChapter) -> Int {
    archive.targets(for: chapter.id).filter { foundIDs.contains($0.id) }.count
  }

  func seconds(for chapter: ScrollChapter) -> TimeInterval {
    chapter.id == selectedChapterID ? elapsedSeconds : chapterTimes[chapter.id, default: 0]
  }

  func canHint(isPro: Bool) -> Bool {
    currentTarget != nil && (isPro || hintsUsed < 1)
  }

  @discardableResult
  func requestHint(isPro: Bool) -> ScrollTarget? {
    guard canHint(isPro: isPro), let target = currentTarget, let selectedChapterID else {
      return nil
    }
    hintCounts[selectedChapterID, default: 0] += 1
    save()
    return target
  }

  @discardableResult
  func find(_ target: ScrollTarget) -> Bool {
    guard target.id == currentTarget?.id, !foundIDs.contains(target.id) else { return false }
    setSearching(false)
    foundIDs.insert(target.id)
    save()
    return true
  }

  func nextClue() {
    // The current clue is derived from the first unfound target in reading order.
  }

  func setSearching(_ searching: Bool) {
    let shouldSearch = searching && currentTarget != nil
    guard shouldSearch != isSearching else { return }
    if shouldSearch {
      isSearching = true
      searchStartedAt = now()
      ticker = Task { @MainActor [weak self] in
        while !Task.isCancelled {
          do {
            try await Task.sleep(for: .seconds(1))
          } catch {
            break
          }
          guard !Task.isCancelled, self != nil else { break }
          self?.refreshElapsedTime()
        }
      }
    } else {
      refreshElapsedTime()
      if let selectedChapterID { chapterTimes[selectedChapterID] = elapsedSeconds }
      isSearching = false
      searchStartedAt = nil
      ticker?.cancel()
      ticker = nil
      save()
    }
  }

  /// Coordinates are normalized over the full stitched painting, never a single tile.
  static func targetAt(x: Double, y: Double, candidates: [ScrollTarget]) -> ScrollTarget? {
    guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
    return candidates.compactMap { target -> (ScrollTarget, Double)? in
      let dx = (x - target.x) / 0.015
      let dy = (y - target.y) / 0.12
      let distance = dx * dx + dy * dy
      return distance <= 1.000_000_001 ? (target, distance) : nil
    }.min { $0.1 < $1.1 }?.0
  }

  private func refreshElapsedTime() {
    guard let selectedChapterID, let searchStartedAt else { return }
    elapsedSeconds = chapterTimes[selectedChapterID, default: 0] + max(0, now().timeIntervalSince(searchStartedAt))
    save()
  }

  private func save() {
    var times = chapterTimes
    if let selectedChapterID { times[selectedChapterID] = elapsedSeconds }
    let progress = SavedProgress(
      selectedChapterID: selectedChapterID,
      foundIDs: foundIDs,
      hintCounts: hintCounts,
      chapterTimes: times
    )
    if let data = try? JSONEncoder().encode(progress) {
      defaults.set(data, forKey: Self.persistenceKey)
    }
  }

  private struct SavedProgress: Codable {
    var selectedChapterID: String?
    var foundIDs: Set<String>
    var hintCounts: [String: Int]
    var chapterTimes: [String: TimeInterval]
  }
}
