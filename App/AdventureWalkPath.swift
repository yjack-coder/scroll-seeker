import Foundation
import Observation

@MainActor
@Observable
final class AdventureWalkPath {
  private(set) var points: [AdventurePathPoint] = []
  private(set) var lastError: String?
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let sourceURL: URL?
  @ObservationIgnored private let persistenceKey: String

  init(defaults: UserDefaults = .standard, sourceURL: URL? = nil) {
    self.defaults = defaults
    self.sourceURL = sourceURL ?? AdventureWorldArchive.resourceURL()
    let version = (try? AdventureWorldArchive.load(from: self.sourceURL))?.geometryVersion ?? AdventureWorldArchive.version
    self.persistenceKey = "scrollseeker.adventure.world.\(version).walkpath"
    reload()
  }

  var minX: Double { points.last?.x ?? 0.9 }
  var maxX: Double { points.first?.x ?? 0.9 }
  var jsonString: String { Self.jsonString(for: points) }

  static func jsonString(for points: [AdventurePathPoint]) -> String {
    let document = PathDocument(
      note: "Xiao An's feet follow this path, ordered right to left. Coordinates are normalized over the full original handscroll.",
      points: points.map { [$0.x, $0.y] }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(document) else { return "" }
    return String(decoding: data, as: UTF8.self)
  }

  func reload() {
    if let saved = defaults.data(forKey: persistenceKey), let restored = try? Self.decode(saved) {
      points = restored
      lastError = nil
      return
    }
    do {
      guard let sourceURL else { throw PathError.missingResource }
      points = try Self.decode(Data(contentsOf: sourceURL))
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  @discardableResult
  func save(points draft: [AdventurePathPoint]) -> Bool {
    do {
      try Self.validate(draft)
      let document = PathDocument(note: nil, points: draft.map { [$0.x, $0.y] })
      let data = try JSONEncoder().encode(document)
      defaults.set(data, forKey: persistenceKey)
      points = draft
      lastError = nil
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  /// Nonuniform Catmull–Rom in x: shared endpoint tangents make adjacent
  /// segments meet smoothly even when traced point spacing is uneven.
  func point(atX x: Double) -> CGPoint? {
    Self.interpolate(points: points, atX: x)
  }

  nonisolated static func interpolate(points: [AdventurePathPoint], atX x: Double) -> CGPoint? {
    guard points.count >= 2, x.isFinite else { return nil }
    let maxX = points[0].x
    let minX = points[points.count - 1].x
    let position = min(maxX, max(minX, x))
    if position >= maxX { return CGPoint(x: maxX, y: points[0].y) }
    if position <= minX { return CGPoint(x: minX, y: points[points.count - 1].y) }
    guard let rightIndex = points.indices.dropLast().first(where: {
      points[$0].x >= position && position >= points[$0 + 1].x
    }) else { return nil }
    let p0 = points[max(0, rightIndex - 1)]
    let p1 = points[rightIndex]
    let p2 = points[rightIndex + 1]
    let p3 = points[min(points.count - 1, rightIndex + 2)]
    let span = p2.x - p1.x
    let t = (position - p1.x) / span
    let tangent1 = (p2.y - p0.y) / (p2.x - p0.x)
    let tangent2 = (p3.y - p1.y) / (p3.x - p1.x)
    let t2 = t * t
    let t3 = t2 * t
    let y = (2 * t3 - 3 * t2 + 1) * p1.y
      + (t3 - 2 * t2 + t) * span * tangent1
      + (-2 * t3 + 3 * t2) * p2.y
      + (t3 - t2) * span * tangent2
    return CGPoint(x: position, y: min(1, max(0, y)))
  }

  func y(atX x: Double) -> Double {
    point(atX: x).map { Double($0.y) } ?? points.first?.y ?? 0.5
  }

  private static func decode(_ data: Data) throws -> [AdventurePathPoint] {
    if let world = try? JSONDecoder().decode(AdventureWorldArchive.self, from: data) {
      guard world.walkpath.allSatisfy({ $0.count == 2 }) else { throw PathError.invalidCoordinates }
      let points = world.pathPoints
      try validate(points)
      return points
    }
    let document = try JSONDecoder().decode(PathDocument.self, from: data)
    guard document.points.allSatisfy({ $0.count == 2 }) else { throw PathError.invalidCoordinates }
    let points = document.points.map { AdventurePathPoint(x: $0[0], y: $0[1]) }
    try validate(points)
    return points
  }

  private static func validate(_ points: [AdventurePathPoint]) throws {
    guard points.count >= 2 else { throw PathError.tooFewPoints }
    guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
      throw PathError.invalidCoordinates
    }
    guard zip(points, points.dropFirst()).allSatisfy({ $0.x > $1.x }) else { throw PathError.unorderedPoints }
  }

  private struct PathDocument: Codable {
    var note: String?
    var points: [[Double]]
  }

  private enum PathError: LocalizedError {
    case missingResource, tooFewPoints, invalidCoordinates, unorderedPoints
    var errorDescription: String? {
      switch self {
      case .missingResource: "The walking path could not be opened."
      case .tooFewPoints: "Keep at least two points on the walking path."
      case .invalidCoordinates: "Every point needs a finite x and y between zero and one."
      case .unorderedPoints: "Arrange points from right to left, with a different x for each point."
      }
    }
  }
}

struct AdventurePathPoint: Identifiable, Codable, Hashable {
  var id = UUID()
  var x: Double
  var y: Double
}
