import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Only completed-quest presentations request a poem. Curated text is available
/// immediately; an optional, entirely on-device generation can replace it once.
@MainActor
@Observable
final class AdventurePoemStore {
  static let shared = AdventurePoemStore()
  private(set) var poems: [String: AdventureQuestPoem]
  @ObservationIgnored private var attempted: Set<String> = []
  @ObservationIgnored private let defaults: UserDefaults
  private static let storageKey = "scrollseeker.adventure.quest-poems.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let saved = defaults.data(forKey: Self.storageKey).flatMap {
      try? JSONDecoder().decode([String: AdventureQuestPoem].self, from: $0)
    } ?? [:]
    poems = saved.filter { _, poem in
      Self.validated(chinese: poem.chinese, english: poem.english, generated: poem.isGenerated) != nil
    }
  }

  func poem(for mission: AdventureMission) -> AdventureQuestPoem {
    poems[mission.id] ?? AdventureQuestPoem(chinese: mission.poemChinese, english: mission.poemEnglish, isGenerated: false)
  }

  func prepare(for mission: AdventureMission) async {
    guard poems[mission.id]?.isGenerated != true else { return }
    if poems[mission.id] == nil {
      poems[mission.id] = poem(for: mission)
      persist()
    }
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      // Explicitly select the local model. Never use Private Cloud Compute or
      // a remote model/provider as a fallback.
      let model = SystemLanguageModel.default
      guard model.isAvailable, !Task.isCancelled,
            attempted.insert(mission.id).inserted else { return }
      do {
        let session = LanguageModelSession(model: model, instructions: """
          Write an original, quiet Chinese landscape couplet about a completed act of kindness in a Song-dynasty story.
          Return two short lines in traditional Chinese, and two matching lines of English translation.
          Each field is one line only: no headings, quotes, numbering, markdown, or line breaks within a field.
          Be contemplative and warm, not cute. Do not invent future events or rewards.
          """
        )
        let response = try await session.respond(
          to: "Completed scene: \(mission.title)\nWhat happened: \(mission.journalNarrative)\nSeal: \(mission.sealName)",
          generating: GeneratedAdventureCouplet.self,
          options: GenerationOptions(temperature: 0.65, maximumResponseTokens: 320)
        )
        let value = response.content
        guard let poem = Self.validated(
          chinese: value.chineseFirst + "\n" + value.chineseSecond,
          english: value.englishFirst + "\n" + value.englishSecond,
          generated: true
        ) else { return }
        poems[mission.id] = poem
        persist()
      } catch {
        // Unsupported hardware/language, model download, refusal, cancellation,
        // and invalid generation all leave the persisted curated couplet intact.
      }
    }
    #endif
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(poems) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  static func validated(chinese: String, english: String, generated: Bool) -> AdventureQuestPoem? {
    func twoLines(_ text: String, limit: Int) -> String? {
      let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let lines = normalized.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
      guard lines.count == 2, lines.allSatisfy({ !$0.isEmpty && $0.count <= limit }) else { return nil }
      return lines.joined(separator: "\n")
    }
    guard let chinese = twoLines(chinese, limit: 80),
          let english = twoLines(english, limit: 180) else { return nil }
    return AdventureQuestPoem(chinese: chinese, english: english, isGenerated: generated)
  }
}

struct AdventureQuestPoem: Codable, Equatable {
  var chinese: String
  var english: String
  var isGenerated: Bool
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedAdventureCouplet {
  @Guide(description: "The first short poetic line in traditional Chinese, with no line breaks.")
  var chineseFirst: String
  @Guide(description: "The second short poetic line in traditional Chinese, with no line breaks.")
  var chineseSecond: String
  @Guide(description: "One English line translating the first Chinese line, with no line breaks.")
  var englishFirst: String
  @Guide(description: "One English line translating the second Chinese line, with no line breaks.")
  var englishSecond: String
}
#endif
