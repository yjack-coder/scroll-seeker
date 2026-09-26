import Foundation

struct ScrollArchive: Codable, Hashable {
  var painting: String
  var tiles: [String]
  var chapters: [ScrollChapter]
  var targets: [ScrollTarget]
  var pixelSize: [Double]? = nil

  var aspectRatio: Double {
    guard let pixelSize, pixelSize.count == 2,
      pixelSize.allSatisfy({ $0.isFinite && $0 > 0 }) else {
      return 1
    }
    return pixelSize[0] / pixelSize[1]
  }

  static func loadWorld() throws -> ScrollArchive {
    guard let url = resourceURL(for: "World/world.json") else { throw ArchiveError.missingArchive }
    let world = try JSONDecoder().decode(WorldRaster.self, from: Data(contentsOf: url))
    guard world.size.count == 2, world.size.allSatisfy({ $0.isFinite && $0 > 0 }),
          resourceURL(for: "World/" + world.image) != nil else { throw ArchiveError.missingArchive }
    return ScrollArchive(painting: "A Life Along the River", tiles: ["World/" + world.image],
                         chapters: [], targets: [], pixelSize: world.size)
  }

  private struct WorldRaster: Decodable {
    var image: String
    var size: [Double]
  }

  static func load() throws -> ScrollArchive {
    guard let url = resourceURL(for: "targets.json") else {
      throw ArchiveError.missingArchive
    }
    return try load(from: url)
  }

  static func load(from url: URL) throws -> ScrollArchive {
    try JSONDecoder().decode(ScrollArchive.self, from: Data(contentsOf: url))
  }

  /// Handscrolls begin in the countryside at the right and travel toward the city.
  func targets(for chapterID: String) -> [ScrollTarget] {
    targets.filter { $0.chapter == chapterID }.sorted {
      if $0.x == $1.x { return $0.id < $1.id }
      return $0.x > $1.x
    }
  }

  func resourceURL(for resource: String) -> URL? {
    Self.resourceURL(for: resource)
  }

  /// Supports both folder-preserving bundles and Xcode's flattened resource layout.
  static func resourceURL(for resource: String, bundle: Bundle = .main) -> URL? {
    let path = resource as NSString
    let filename = path.lastPathComponent as NSString
    let relativeDirectory = path.deletingLastPathComponent
    let roots = ["", "World", "Resources/World", "Qingming", "Resources/Qingming", "Resources"]

    for root in roots {
      let directory = [root, relativeDirectory].filter { !$0.isEmpty }.joined(separator: "/")
      if let url = bundle.url(
        forResource: filename.deletingPathExtension,
        withExtension: filename.pathExtension,
        subdirectory: directory.isEmpty ? nil : directory
      ) {
        return url
      }
      if let baseURL = bundle.resourceURL {
        let url = baseURL.appendingPathComponent(root).appendingPathComponent(resource)
        if FileManager.default.fileExists(atPath: url.path) { return url }
      }
    }

    return bundle.url(
      forResource: filename.deletingPathExtension,
      withExtension: filename.pathExtension
    )
  }

  private enum ArchiveError: LocalizedError {
    case missingArchive

    var errorDescription: String? {
      "The painting's archive could not be opened."
    }
  }
}

struct ScrollChapter: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var subtitle: String
  var xRange: [Double]
  var free: Bool

  var chineseName: String {
    title.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? title
  }

  var englishName: String {
    let parts = title.components(separatedBy: "·")
    return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : title
  }
}

struct ScrollTarget: Identifiable, Codable, Hashable {
  var id: String
  var chapter: String
  var clue: String
  var name: String
  var hint: String
  var story: String
  var x: Double
  var y: Double
  var seal: String? = nil

  var chineseName: String {
    String(name.split(maxSplits: 1, whereSeparator: { $0.isWhitespace }).first ?? Substring(name))
  }

  var englishName: String {
    let parts = name.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
    return parts.count > 1 ? String(parts[1]) : name
  }
}
