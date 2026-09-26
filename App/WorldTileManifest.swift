import Foundation

/// Authoritative source-pixel offsets, never inferred from equal tile widths.
struct WorldTileManifest: Decodable, Sendable {
  var source: String
  var size: [Int]
  var order: String
  var tiles: [Tile]

  struct Tile: Decodable, Identifiable, Sendable {
    var file: String
    var x: Int
    var width: Int
    var id: String { file }
  }

  var isValid: Bool {
    guard size.count == 2, size[0] > 0, size[1] > 0,
          order == "left_to_right", !tiles.isEmpty,
          Set(tiles.map(\.file)).count == tiles.count else { return false }
    var expectedX = 0
    for tile in tiles {
      guard tile.x == expectedX, tile.width > 0,
            tile.width <= size[0] - expectedX,
            tile.file == (tile.file as NSString).lastPathComponent else { return false }
      expectedX += tile.width
    }
    return expectedX == size[0]
  }
}

/// Shared boundary rounding prevents independent width rounding from accumulating
/// into gaps. Overdraw is visual only and never changes the world's coordinates.
struct WorldTileLayout {
  var origin: CGFloat
  var width: CGFloat
  var overdraw: CGFloat

  init(pixelX: Int, pixelWidth: Int, sourceWidth: CGFloat,
       canvasWidth: CGFloat, displayScale: CGFloat) {
    let density = displayScale.isFinite && displayScale > 0 ? displayScale : 1
    let scale = sourceWidth > 0 && canvasWidth.isFinite && canvasWidth > 0
      ? canvasWidth / sourceWidth : 0
    origin = (CGFloat(pixelX) * scale * density).rounded() / density
    let end = (CGFloat(pixelX + pixelWidth) * scale * density).rounded() / density
    width = max(0, end - origin)
    overdraw = CGFloat(pixelX + pixelWidth) < sourceWidth ? 1 / density : 0
  }
}
