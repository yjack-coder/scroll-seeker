import Foundation
import Observation

@MainActor
@Observable
final class JournalStore {
  private(set) var entries: [JournalEntry] = []
  private(set) var isPainting = false
  var errorMessage: String?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let interpreter:
    @Sendable (String, LandscapeSeason?) async -> JournalEntry
  @ObservationIgnored private let storageKey = "liubai.journal.v1"
  @ObservationIgnored private var paintGeneration = 0

  var today: JournalEntry? {
    entries.first { !$0.isSample && Calendar.current.isDateInToday($0.date) }
  }

  var canPaintToday: Bool { today == nil }

  init(
    defaults: UserDefaults = .standard,
    interpreter: @escaping @Sendable (String, LandscapeSeason?) async -> JournalEntry = {
      words, season in
      await EmotionInterpreter.interpret(words, season: season)
    }
  ) {
    self.defaults = defaults
    self.interpreter = interpreter
    if let stored = defaults.string(forKey: storageKey),
      let data = stored.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data)
    {
      entries = decoded.sorted { $0.date > $1.date }
    } else {
      entries = Self.sampleEntries()
      persist()
    }
  }

  /// Daily limits are evaluated by the purchase-aware caller; this store also supports Pro.
  @discardableResult
  func paint(words: String, season: LandscapeSeason? = nil) async -> JournalEntry? {
    guard !isPainting else { return nil }
    let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      errorMessage = "A word, a sentence, a feeling. Begin wherever you are."
      return nil
    }
    guard trimmed.count <= 1200 else {
      errorMessage = "Leave a little empty space. Keep your reflection under 1,200 characters."
      return nil
    }

    errorMessage = nil
    isPainting = true
    paintGeneration += 1
    let generation = paintGeneration
    defer { if generation == paintGeneration { isPainting = false } }
    let entry = await interpreter(trimmed, season)
    guard !Task.isCancelled, generation == paintGeneration else { return nil }
    entries.insert(entry, at: 0)
    persist()
    return entry
  }

  func entriesForScroll(isPro: Bool) -> [JournalEntry] {
    let dayCount = isPro ? 365 : 7
    let today = Calendar.current.startOfDay(for: .now)
    let cutoff =
      Calendar.current.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? .distantPast
    return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
  }

  private func persist() {
    do {
      let data = try JSONEncoder().encode(entries)
      guard let value = String(data: data, encoding: .utf8) else { return }
      defaults.set(value, forKey: storageKey)
    } catch {
      errorMessage = "Your painting is here, but it could not be saved. Please try again."
    }
  }

  private static func sampleEntries() -> [JournalEntry] {
    let reflections: [(String, LandscapeSeason, LandscapeLight, FigurePose)] = [
      (
        "Today, I am learning to leave a little room for the quiet. Not everything needs an answer.",
        .autumn, .day, .rowing
      ),
      (
        "I finally let go of something I had been carrying for too long. The river can have it now.",
        .autumn, .dawn, .rowing
      ),
      (
        "There is so much work, and I feel the weight of being needed. I am tired.", .winter, .dusk,
        .standing
      ),
      (
        "A small kindness reminded me that there is still hope. I feel grateful for a new beginning.",
        .spring, .dawn, .crossing
      ),
      (
        "I miss someone who used to know me so well. Tonight the distance feels quiet.", .autumn,
        .moon, .sitting
      ),
      (
        "I don't know what comes next. I am trying to cross into the unknown with an open heart.",
        .summer, .dawn, .crossing
      ),
      (
        "Nothing happened today, and it was enough. A slow walk, warm tea, a calm afternoon.",
        .summer, .day, .sitting
      ),
      (
        "Some days the sadness is a mountain. Today I stood beneath it and breathed.", .winter,
        .moon, .standing
      ),
      (
        "I forgave myself for not knowing then what I know now. I am letting go.", .spring, .day,
        .rowing
      ),
      (
        "The rain made the whole world quiet. I feel peaceful, resting beside the window.", .summer,
        .dusk, .sitting
      ),
    ]
    return reflections.enumerated().map { offset, sample in
      let date = Calendar.current.date(byAdding: .day, value: -(offset + 1), to: .now) ?? .now
      var entry = EmotionInterpreter.offline(sample.0, season: sample.1, date: date)
      entry.parameters.light = sample.2
      entry.parameters.pose = sample.3
      entry.isSample = true
      return entry
    }
  }
}
