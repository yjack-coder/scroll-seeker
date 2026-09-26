import Foundation

struct JournalEntry: Identifiable, Codable, Sendable {
  var id: UUID = UUID()
  var date: Date
  var words: String
  var title: String
  var parameters: LandscapeParameters
  var poemChinese: [String]
  var poemEnglish: [String]
  var seed: Int
  var isSample: Bool = false

  var dateLabel: String {
    date.formatted(.dateTime.month(.abbreviated).day())
  }

  var accessibilityDescription: String {
    "\(title). \(parameters.season.label), \(parameters.light.label.lowercased()). \(parameters.pose.description). \(poemEnglish.joined(separator: " "))"
  }
}

struct LandscapeParameters: Codable, Equatable, Sendable {
  var burden: Double
  var flow: Double
  var uncertainty: Double
  var pose: FigurePose
  var season: LandscapeSeason
  var light: LandscapeLight
}

enum FigurePose: String, Codable, CaseIterable, Sendable {
  case standing, sitting, crossing, rowing

  var description: String {
    switch self {
    case .standing: "A small figure stands among the mountains"
    case .sitting: "A small figure rests beside the water"
    case .crossing: "A small figure crosses a quiet bridge"
    case .rowing: "A small boat drifts across the water"
    }
  }
}

enum LandscapeSeason: String, Codable, CaseIterable, Identifiable, Sendable {
  case spring, summer, autumn, winter

  var id: String { rawValue }
  var label: String { rawValue.capitalized }
  var chinese: String {
    switch self {
    case .spring: "春"
    case .summer: "夏"
    case .autumn: "秋"
    case .winter: "冬"
    }
  }
  var subtitle: String {
    switch self {
    case .spring: "Spring blossoms"
    case .summer: "Summer rain"
    case .autumn: "Autumn maple"
    case .winter: "Winter snow"
    }
  }
}

enum LandscapeLight: String, Codable, CaseIterable, Sendable {
  case dawn, day, dusk, moon
  var label: String {
    switch self {
    case .dawn: "Dawn"
    case .day: "Daylight"
    case .dusk: "Dusk"
    case .moon: "Moonlight"
    }
  }
}
