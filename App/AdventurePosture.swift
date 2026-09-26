import Foundation
import Observation

enum AdventurePosture: String, Codable, CaseIterable, Identifiable {
  case folded
  case book
  case open
  case tent
  case laptop

  var id: String { rawValue }

  var chineseName: String {
    switch self {
    case .folded: "合上"
    case .book: "書本"
    case .open: "展開"
    case .tent: "帳篷"
    case .laptop: "書桌"
    }
  }

  var englishName: String {
    switch self {
    case .folded: "Folded"
    case .book: "Book"
    case .open: "Open"
    case .tent: "Tent"
    case .laptop: "Laptop"
    }
  }

  var name: String { chineseName + " · " + englishName }

  // Verified against the SF Symbols catalog; all predate the iOS 26 minimum.
  var symbol: String {
    switch self {
    case .folded: "book.closed"
    case .book: "book"
    case .open: "rectangle"
    case .tent: "house"
    case .laptop: "laptopcomputer"
    }
  }
}

/// Discrete game input. Repeated device samples or choosing the current pose
/// never create another action; motion between poses is a separate UI concern.
@MainActor
@Observable
final class AdventurePostureStore {
  private(set) var current: AdventurePosture = .folded
  private(set) var previous: AdventurePosture = .folded
  private(set) var changeCount = 0

  func set(_ posture: AdventurePosture) {
    guard posture != current else { return }
    previous = current
    current = posture
    changeCount += 1
  }
}
