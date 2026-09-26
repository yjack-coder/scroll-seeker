import Foundation

struct AdventureArchive: Codable, Hashable {
  var title: String
  var readingDirection: String
  var hero: AdventureHero
  var home: AdventureHome
  var segments: [AdventureSegment]
  var acts: [AdventureAct]
  var gear: [AdventureGear]
  var world: AdventureWorldArchive?

  static func load() throws -> AdventureArchive {
    guard let url = ScrollArchive.resourceURL(for: "story.json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    guard let worldURL = AdventureWorldArchive.resourceURL() else { throw CocoaError(.fileNoSuchFile) }
    return try load(from: url, worldURL: worldURL)
  }

  static func load(from url: URL, worldURL: URL? = nil) throws -> AdventureArchive {
    let story = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    guard let worldURL else { return story }
    return story.mapped(to: try AdventureWorldArchive.load(from: worldURL))
  }

  func mapped(to world: AdventureWorldArchive) -> AdventureArchive {
    var story = self
    story.world = world
    story.readingDirection = world.readingDirection
    if let place = world.places["home"] { story.home.x = place.x; story.home.y = place.y; story.home.note = place.note }
    story.segments = world.segments.map { AdventureSegment(id: $0.panel, name: $0.name, xRange: $0.xRange, act: 1) }
    if let childIndex = story.acts.firstIndex(where: { $0.id == "act1" }),
      !story.acts[childIndex].missions.contains(where: { $0.id == "m_paperboat" }),
      let before = story.acts[childIndex].missions.firstIndex(where: { $0.id == "m3" }),
      let paper = world.places["paper_boat"] {
      story.acts[childIndex].missions.insert(AdventureMission(id: "m_paperboat", segment: paper.panel,
        x: paper.x, y: paper.y, title: "紙船 A Paper Boat", task: "Help a child fold a paper boat and set it on the stream.",
        reward: AdventureReward(coins: 5), trigger: nil), at: before)
    }
    let named: [String: String] = ["m1": "lost_donkey", "m2": "directions", "m_paperboat": "paper_boat", "m3": "boatmen", "m4": "rainbow_bridge", "m5": "soy_sauce_shop", "m6": "home", "a1": "tea_house", "a2": "city_gate", "a4": "poetry_tower", "a5": "poetry_tower", "b1": "grain_barge", "b2": "city_gate", "b3": "ox_cart", "b4": "tavern", "b5": "city_gate"]
    let roadEncounters: [String: Double] = ["a3": (world.places["city_gate"]!.x + world.places["poetry_tower"]!.x) / 2]
    let points = world.pathPoints
    for actIndex in story.acts.indices {
      for missionIndex in story.acts[actIndex].missions.indices {
        var mission = story.acts[actIndex].missions[missionIndex]
        if let key = named[mission.id], let place = world.places[key] {
          mission.x = place.x; mission.y = place.y; mission.segment = place.panel
        } else if let x = roadEncounters[mission.id] {
          mission.x = x
          mission.y = AdventureWalkPath.interpolate(points: points, atX: x).map { Double($0.y) } ?? 0.5
          mission.segment = world.segment(at: x)?.panel ?? "Panel4"
        }
        if mission.id == "b2" {
          mission.title = "過城門 Pass the Gate"
          mission.task = "Hide from the city gate guards, then slip through while their attention is elsewhere."
        }
        story.acts[actIndex].missions[missionIndex] = mission
      }
    }
    return story
  }

  var allMissions: [AdventureMission] { acts.flatMap(\.missions) }

  func act(for stage: AdventureStage) -> AdventureAct? {
    acts.first { $0.stage == stage }
  }

  func mission(_ id: String) -> AdventureMission? {
    allMissions.first { $0.id == id }
  }

}

enum AdventureStage: String, Codable, CaseIterable, Identifiable {
  case child
  case scholar
  case thief

  var id: String { rawValue }
  var chineseName: String {
    switch self {
    case .child: "孩童"
    case .scholar: "書生"
    case .thief: "神偷"
    }
  }
  var englishName: String {
    switch self {
    case .child: "Child"
    case .scholar: "Scholar"
    case .thief: "Gentleman Thief"
    }
  }
  var name: String { chineseName + " " + englishName }
}

struct AdventureHero: Codable, Hashable {
  var name: String
  var stages: [String]
  var chineseName: String { adventureNames(name).0 }
  var englishName: String { adventureNames(name).1 }
}

struct AdventureHome: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var x: Double
  var y: Double
  var note: String
  var chineseName: String { adventureNames(name).0 }
  var englishName: String { adventureNames(name).1 }
}

struct AdventureSegment: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var xRange: [Double]
  var act: Int
  var chineseName: String { adventureNames(name).0 }
  var englishName: String { adventureNames(name).1 }
}

struct AdventureAct: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var stage: AdventureStage
  var free: Bool
  var intro: String
  var missions: [AdventureMission]
  var outro: String?
  var ending: String?
  private var storyName: String {
    name.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
  }
  var chineseName: String { adventureNames(storyName).0 }
  var englishName: String { adventureNames(storyName).1 }
}

struct AdventureMission: Identifiable, Codable, Hashable {
  var id: String
  var segment: String
  var x: Double
  var y: Double
  var title: String
  var task: String
  var reward: AdventureReward
  var trigger: AdventureMissionTrigger?
  var chineseName: String { adventureNames(title).0 }
  var englishName: String { adventureNames(title).1 }

  var objective: String {
    switch id {
    case "m1": "Meet the donkey caravan at the countryside end of the road and help the charcoal seller."
    case "m2": "Follow the willow path and ask the travelers for directions to the river."
    case "m_paperboat": "Meet the child at the footbridge, fold a paper boat, and send it down the stream."
    case "m3": "Meet the boatmen at the docks and pull the rope together in time."
    case "m4": "Walk onto Rainbow Bridge and warn the approaching boat at the right moment."
    case "m5": "Meet the sauce seller, agree on a fair price, and keep the full bottle steady."
    case "m6": "Fold the phone and give Mother the soy sauce."
    case "a1": "Visit the willow tea house and complete a scholar’s couplet to borrow their books."
    case "a2": "Reach the city gate and explain why you seek the capital."
    case "a3": "Meet the camel merchant and choose ink worthy of the examination."
    case "a4": "Join the poetry gathering at the tavern and answer the verses."
    case "a5": "At Poetry Tower, seal your examination scroll and await the final results."
    case "b1": "Return to the grain barge and slip past the watchman to help hungry neighbors."
    case "b2": "Reach the city gate and hide from its watchful guards."
    case "b3": "Reach the ox cart and hide among the goods while the guard looks away."
    case "b4": "Meet the corrupt official at the tavern and time your reach for his purse."
    case "b5": "Return to the city gate, evade the guards, and share the silver with the neighbors."
    default: task
    }
  }

  var journalNarrative: String {
    switch id {
    case "m1": "Helped the charcoal seller reunite his donkeys. The caravan set off together again."
    case "m2": "Asked the travelers for directions and followed the willows toward the Bian River."
    case "m_paperboat": "Folded a paper boat with a child at the footbridge and watched it carry a small wish downstream."
    case "m3": "Pulled the rope in time with the boatmen and helped carry their boat clear of the bank."
    case "m4": "Shouted a warning from Rainbow Bridge in time for the boat to pass safely."
    case "m5": "Agreed on a fair price for Mother’s soy sauce and kept the full bottle steady."
    case "m6": "Brought the soy sauce home to Mother. A small errand became the beginning of a larger life."
    case "a1": "Matched a scholar’s verse and earned a borrowed book, a brush, and a new friend."
    case "a2": "Explained the journey to the gatekeeper and entered the capital for the examination."
    case "a3": "Chose rare ink for the clarity of its mark, rather than the splendor of its wrapping."
    case "a4": "Answered the tavern’s verses with fitting lines and won the poetry gathering’s applause."
    case "a5": "Answered the examiner’s final questions and earned the name of Top Scholar."
    case "b1": "Slipped past the watchman and took hoarded grain to fill the neighbors’ empty bowls."
    case "b2": "Hid from the gate guards and slipped quietly through to the capital."
    case "b3": "Hid among the ox cart’s goods and passed quietly into the city."
    case "b4": "Lifted the corrupt official’s purse and set its silver on a kinder course."
    case "b5": "Escaped through the city gate and shared the silver. The neighbors ate well that night."
    default: "Completed \(englishName)."
    }
  }

  var sealName: String {
    switch id {
    case "m1": "善行"
    case "m2": "問路"
    case "m_paperboat": "紙船"
    case "m3": "同舟"
    case "m4": "虹橋"
    case "m5": "醬香"
    case "m6": "歸家"
    case "a1": "借書"
    case "a2": "入京"
    case "a3": "松墨"
    case "a4": "詩友"
    case "a5": "狀元"
    case "b1": "分糧"
    case "b2": "過關"
    case "b3": "藏身"
    case "b4": "義取"
    case "b5": "濟人"
    default: "安"
    }
  }

  var poemChinese: String {
    switch id {
    case "m1": "驢鈴重入柳煙裡，\n一點善心伴路長。"
    case "m2": "問罷前程風過柳，\n人間一語便成橋。"
    case "m_paperboat": "折來一葉載童願，\n小水悠悠向遠方。"
    case "m3": "眾手牽繩河水動，\n同心一寸抵千鈞。"
    case "m4": "橋頭一喚穿雲去，\n舟過虹邊萬事安。"
    case "m5": "小瓶盛得人間味，\n一路輕扶念母心。"
    case "m6": "千山不及柴門近，\n一盞家燈候我歸。"
    case "a1": "借得半窗春日字，\n書中自有故人心。"
    case "a2": "城門初見青雲路，\n袖底猶藏故里風。"
    case "a3": "一點松煙凝夜色，\n落成清字見初心。"
    case "a4": "樓上詩聲和流水，\n天涯相識在同心。"
    case "a5": "卷合不收凌雲志，\n榜開先報故園人。"
    case "b1": "夜船分出千家粟，\n一碗溫香勝萬金。"
    case "b2": "斂影城門燈火外，\n心中一線向人明。"
    case "b3": "車聲載我穿長巷，\n藏得身形不藏仁。"
    case "b4": "取來不義囊中月，\n照向寒窗便是春。"
    case "b5": "散盡銀光星未散，\n萬家燈下有餘溫。"
    default: "一步一程皆入畫，\n半山半水總關情。"
    }
  }

  var poemEnglish: String {
    switch id {
    case "m1": "Donkey bells return to willow mist.\nA little kindness walks a long road."
    case "m2": "A question passes beneath the willows.\nOne kind answer becomes a bridge."
    case "m_paperboat": "One folded leaf carries a child’s wish.\nThe little stream takes it far away."
    case "m3": "Many hands set the riverboat moving.\nA little shared strength lifts a heavy load."
    case "m4": "A warning rises above the bridge.\nThe boat passes; every heart can rest."
    case "m5": "A small bottle holds the taste of home.\nCare for Mother steadies every step."
    case "m6": "No mountain is nearer than our door.\nA lamp at home has waited for me."
    case "a1": "Borrowed words brighten half a window.\nA friend’s kindness lives between the pages."
    case "a2": "The gate opens onto a wider road.\nThe wind of home stays in my sleeve."
    case "a3": "Pine soot gathers the color of night.\nAn honest stroke remembers its beginning."
    case "a4": "Poems mingle with the river below.\nStrangers meet inside a shared line."
    case "a5": "The sealed scroll keeps a rising hope.\nThe first news goes to the one at home."
    case "b1": "The night boat yields grain for many homes.\nA warm bowl is worth more than gold."
    case "b2": "A shadow waits beyond the gate lamps.\nA little light is kept within."
    case "b3": "Cart wheels carry me through the lanes.\nA hidden face still holds a kind heart."
    case "b4": "Ill-gotten silver leaves a heavy purse.\nAt a cold window it becomes spring."
    case "b5": "The silver is gone; the stars remain.\nWarmth lingers beneath a thousand lamps."
    default: "Every step becomes a painted road.\nEvery river keeps a human story."
    }
  }
}

enum AdventureMissionTrigger: String, Codable {
  case fold
}

struct AdventureReward: Codable, Hashable {
  var coins: Int?
  var gear: String?
  var item: String?
  var title: String?
}

struct AdventureGear: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var effect: String
  var free: Bool?
  var cost: Int?
  var pro: Bool?
  var isPro: Bool { pro == true }
  var chineseName: String { adventureNames(name).0 }
  var englishName: String { adventureNames(name).1 }
}

private func adventureNames(_ name: String) -> (String, String) {
  let parts = name.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
  return (String(parts.first ?? Substring(name)), parts.count > 1 ? String(parts[1]) : name)
}
