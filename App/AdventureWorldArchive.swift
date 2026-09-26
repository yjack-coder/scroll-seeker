import Foundation

/// The supplied world document remains immutable. Story locations are adapted
/// in memory so historical story data and earned mission IDs remain intact.
struct AdventureWorldArchive: Codable, Hashable {
  var image: String
  var size: [Double]
  var readingDirection: String
  var note: String
  var segments: [AdventureWorldSegment]
  var walkpath: [[Double]]
  var places: [String: AdventureWorldPlace]

  static let version = "painted-world-v2"
  static let mistCenters: [Double] = [0.188, 0.344, 0.5, 0.656, 0.812]
  static let mistHalfWidth = 0.025

  /// Stable across launches, but changes whenever raster geometry or any road
  /// point changes. An old local trace must never be applied to a new painting.
  var geometryVersion: String {
    let geometry = (size + walkpath.flatMap { $0 }).map(String.init(describing:)).joined(separator: ",")
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    for byte in geometry.utf8 { fingerprint = (fingerprint ^ UInt64(byte)) &* 1_099_511_628_211 }
    return "\(Self.version)-\(String(fingerprint, radix: 16))"
  }

  static func resourceURL(in bundle: Bundle = .main) -> URL? {
    for directory in ["World", "Resources/World", "App/Resources/World"] {
      if let url = bundle.url(forResource: "world", withExtension: "json", subdirectory: directory) { return url }
    }
    return bundle.url(forResource: "world", withExtension: "json")
  }

  static func load(from url: URL? = nil) throws -> AdventureWorldArchive {
    guard let source = url ?? resourceURL() else { throw CocoaError(.fileNoSuchFile) }
    let world = try JSONDecoder().decode(Self.self, from: Data(contentsOf: source))
    guard world.size.count == 2, world.size.allSatisfy({ $0.isFinite && $0 > 0 }),
      world.walkpath.count >= 2, world.walkpath.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0.isFinite && (0...1).contains($0) } }),
      zip(world.walkpath, world.walkpath.dropFirst()).allSatisfy({ $0[0] > $1[0] }),
      world.segments.count == 6,
      world.segments.allSatisfy({ $0.xRange.count == 2 && $0.xRange[0] <= $0.xRange[1] && $0.xRange.allSatisfy { $0.isFinite && (0...1).contains($0) } }),
      world.places.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }),
      ["home", "lost_donkey", "directions", "boatmen", "rainbow_bridge", "soy_sauce_shop", "tea_house", "grain_barge", "city_gate", "paper_boat", "poetry_tower", "tavern", "ox_cart"].allSatisfy({ world.places[$0] != nil })
    else { throw CocoaError(.coderReadCorrupt) }
    return world
  }

  var bridgeX: Double { places["rainbow_bridge"]!.x }
  var homeX: Double { places["home"]!.x }
  var pathPoints: [AdventurePathPoint] { walkpath.map { AdventurePathPoint(x: $0[0], y: $0[1]) } }

  func pathStart(for stage: AdventureStage) -> Double {
    switch stage {
    case .child: homeX
    case .scholar: places["tea_house"]!.x
    case .thief: places["grain_barge"]!.x
    }
  }

  /// Overlapping source panels meet inside mist. Midpoints give one unambiguous
  /// segment at every x while preserving the author's original panel ranges.
  func segment(at x: Double) -> AdventureWorldSegment? {
    guard segments.count == Self.mistCenters.count + 1, x.isFinite else { return nil }
    let index = Self.mistCenters.filter { x <= $0 }.count
    return segments[index]
  }

  func mistIntensity(at x: Double) -> Double {
    guard let distance = Self.mistCenters.map({ abs(x - $0) }).min(), distance < Self.mistHalfWidth else { return 0 }
    let t = 1 - distance / Self.mistHalfWidth
    return t * t * (3 - 2 * t)
  }
}

struct AdventureWorldSegment: Codable, Hashable, Identifiable {
  var panel: String
  var name: String
  var xRange: [Double]
  var id: String { panel }
}

struct AdventureWorldPlace: Codable, Hashable {
  var x: Double
  var y: Double
  var panel: String
  var note: String
}
