import Foundation

@main
struct AdventurePoemChecks {
  @MainActor static func main() throws {
    var checks = 0
    func check(_ condition: Bool, _ label: String) {
      precondition(condition, label)
      checks += 1
    }
    func valid(_ chinese: String, _ english: String) -> AdventureQuestPoem? {
      AdventurePoemStore.validated(chinese: chinese, english: english, generated: true)
    }
    check(valid("一葉\n小舟", "One leaf\nA little boat") != nil, "two lines")
    check(valid(" 一葉 \r\n 小舟 \n", " One leaf \n A little boat ")?.chinese == "一葉\n小舟", "trim and CRLF")
    check(valid("一葉", "One\nTwo") == nil, "one line rejected")
    check(valid("一\n二\n三", "One\nTwo") == nil, "third line rejected")
    check(valid("一\n\n二", "One\nTwo") == nil, "blank inner line rejected")
    check(valid("\n ", "One\nTwo") == nil, "empty rejected")
    check(valid(String(repeating: "一", count: 81) + "\n二", "One\nTwo") == nil, "Chinese length")
    check(valid("一\n二", String(repeating: "x", count: 181) + "\nTwo") == nil, "English length")
    let story = try AdventureArchive.load(from: URL(fileURLWithPath: CommandLine.arguments[1]), worldURL: URL(fileURLWithPath: CommandLine.arguments[2]))
    let suiteName = "scrollseeker.poem.checks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = AdventurePoemStore(defaults: defaults)
    for mission in story.allMissions {
      let fallback = store.poem(for: mission)
      check(!fallback.isGenerated && fallback.chinese == mission.poemChinese, "immediate fallback")
      check(valid(fallback.chinese, fallback.english) != nil, "authored two-line poem")
    }
    let first = story.allMissions[0]
    let saved = valid("一葉\n小舟", "One leaf\nA little boat")!
    defaults.set(try JSONEncoder().encode([first.id: saved]), forKey: "scrollseeker.adventure.quest-poems.v1")
    check(AdventurePoemStore(defaults: defaults).poem(for: first) == saved, "generated cache survives reload")
    let invalid = AdventureQuestPoem(chinese: "only one line", english: "One\nTwo", isGenerated: true)
    defaults.set(try JSONEncoder().encode([first.id: invalid]), forKey: "scrollseeker.adventure.quest-poems.v1")
    check(!AdventurePoemStore(defaults: defaults).poem(for: first).isGenerated, "corrupt cache falls back")
    print("\(checks) poem checks passed; no model generation or real player saves used.")
  }
}
