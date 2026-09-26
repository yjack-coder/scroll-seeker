import Foundation
import Observation
import CoreGraphics
import ImageIO

/// The six immutable decoded bitmaps live for the entire process. Folding,
/// navigation and SwiftUI disappearance never evict or reload them.
@MainActor
@Observable
final class WorldTileStore {
  static let shared = WorldTileStore()

  private(set) var tiles: [WorldDecodedTile] = []
  // Until the manifest is decoded there is no authored geometry to render.
  private(set) var sourceSize = CGSize(width: 1, height: 1)
  private(set) var isReady = false
  private(set) var errorDescription: String?
  @ObservationIgnored private var preloadTask: Task<Void, Never>?

  private init() {}

  /// Starts at App initialization, while the folded Home screen is being built.
  /// All ImageIO work stays off the main actor, with one atomic publication.
  func preload() {
    guard preloadTask == nil, !isReady else { return }
    let decoding = Task.detached(priority: .userInitiated) {
      try WorldTileDecoder.decode()
    }
    preloadTask = Task { @MainActor [weak self] in
      do {
        let decoded = try await decoding.value
        guard let self else { return }
        self.tiles = decoded.tiles
        self.sourceSize = decoded.size
        self.isReady = true
      } catch {
        self?.errorDescription = "The scroll artwork could not be prepared. \(error.localizedDescription)"
      }
    }
  }

  @discardableResult
  func awaitReady() async -> Bool {
    preload()
    await preloadTask?.value
    return isReady
  }
}

/// CGImage is immutable after construction and shared read-only with the renderer.
struct WorldDecodedTile: Identifiable, @unchecked Sendable {
  let id: String
  let image: CGImage
  let pixelX: Int
  let pixelWidth: Int
}

private struct DecodedWorld: Sendable {
  var tiles: [WorldDecodedTile]
  var size: CGSize
}

private enum WorldTileDecoder {
  static func decode() throws -> DecodedWorld {
    guard let manifestURL = ScrollArchive.resourceURL(for: "World/tiles/tiles.json") else {
      throw TileError.missingResource("tiles.json")
    }
    let manifest = try JSONDecoder().decode(WorldTileManifest.self, from: Data(contentsOf: manifestURL))
    guard manifest.isValid else { throw TileError.invalidManifest }
    let tiles = try manifest.tiles.map { tile -> WorldDecodedTile in
      try autoreleasepool {
        guard let url = ScrollArchive.resourceURL(for: "World/tiles/" + tile.file),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw TileError.missingResource(tile.file) }
        guard image.width == tile.width, image.height == manifest.size[1] else {
          throw TileError.invalidDimensions(tile.file)
        }
        return WorldDecodedTile(id: tile.file, image: image, pixelX: tile.x, pixelWidth: tile.width)
      }
    }
    return DecodedWorld(tiles: tiles, size: CGSize(width: manifest.size[0], height: manifest.size[1]))
  }

  private enum TileError: LocalizedError {
    case missingResource(String)
    case invalidDimensions(String)
    case invalidManifest

    var errorDescription: String? {
      switch self {
      case .missingResource(let name): "Missing artwork: \(name)."
      case .invalidDimensions(let name): "Unexpected artwork dimensions: \(name)."
      case .invalidManifest: "The world tile offsets are not continuous."
      }
    }
  }
}
